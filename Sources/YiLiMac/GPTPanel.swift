import AppKit
import SwiftUI
import YiLiCore

@MainActor @Observable
final class GPTSession {
    private var apiKey = ""
    private var request: Task<Void, Never>?
    private var requestID: UUID?
    private(set) var keySource: String?
    private(set) var activeFacts: GPTFacts?
    private(set) var result: (facts: GPTFacts, reading: GPTReading)?
    private(set) var failure: (facts: GPTFacts, message: String)?

    var hasKey: Bool { !apiKey.isEmpty }

    init() {
        if let value = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           let key = try? GPTClient.validatedKey(value) {
            apiKey = key
            keySource = "从 OPENAI_API_KEY 读取，仅本次运行有效"
        }
    }

    func setKey(_ value: String) throws {
        let key = try GPTClient.validatedKey(value)
        invalidate()
        apiKey = key
        keySource = "API Key 已设置，仅本次运行有效"
    }

    func clearKey() {
        invalidate()
        apiKey = ""
        keySource = nil
    }

    func generate(_ facts: GPTFacts) {
        invalidate()
        let id = UUID()
        requestID = id
        activeFacts = facts
        let key = apiKey
        request = Task {
            do {
                let reading = try await GPTClient().generate(facts: facts, apiKey: key)
                guard !Task.isCancelled, requestID == id else { return }
                result = (facts, reading)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, requestID == id else { return }
                failure = (facts, error.localizedDescription)
            }
            guard requestID == id else { return }
            activeFacts = nil
            request = nil
        }
    }

    func invalidate() {
        requestID = nil
        request?.cancel()
        request = nil
        activeFacts = nil
        result = nil
        failure = nil
    }
}

struct GPTPanel: View {
    let facts: GPTFacts
    let session: GPTSession
    @StateProperty private var configuring = false
    @StateProperty private var showingFacts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GPT 命理解读")
                        .font(song(24))
                        .foregroundStyle(Ink.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("结合本命四柱、五行与当天卦象，生成所选日期的中文解读。")
                        .font(.system(size: 12))
                        .foregroundStyle(Ink.secondary)
                }
                Spacer(minLength: 8)
                Button("API 设置") { configuring = true }
                    .buttonStyle(OutlineButton())
                if session.activeFacts == facts {
                    Button("取消生成") { session.invalidate() }
                        .buttonStyle(OutlineButton())
                } else {
                    Button(session.result?.facts == facts ? "重新生成" : "生成解读") {
                        if session.hasKey { session.generate(facts) } else { configuring = true }
                    }
                    .buttonStyle(GoldButton())
                }
            }

            Text("点击生成后，会将所选日期与时区、节气、四柱、日主、五行占比、流日、卦象方位和本地推导发送至 OpenAI。API 按账户用量计费。")
                .font(.system(size: 11))
                .foregroundStyle(Ink.quiet)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text("GPT 生成内容可能有误，传统象意解读供文化体验与日常反思。")
                .font(.system(size: 11))
                .foregroundStyle(Ink.goldLight)

            DisclosureGroup("查看本次发送的数据", isExpanded: $showingFacts) {
                Text(String(decoding: (try? facts.jsonData()) ?? Data(), as: UTF8.self))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Ink.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 7)
            }
            .font(.system(size: 11))
            .foregroundStyle(Ink.secondary)

            if session.activeFacts == facts {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text("正在生成 \(facts.date) 的解读…")
                        .font(.system(size: 12))
                        .foregroundStyle(Ink.secondary)
                }
                .padding(.top, 5)
            }
            if let failure = session.failure, failure.facts == facts {
                Label(failure.message, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.element(.fire))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let result = session.result, result.facts == facts {
                Rectangle().fill(Ink.line).frame(height: 1)
                generatedSection("整体描述", text: result.reading.overview)
                generatedSection("命理与易经依据", text: result.reading.reasoning)
                generatedSection("今日行动", text: result.reading.guidance)
                generatedSection("解读边界", text: result.reading.limits)
                HStack {
                    Text("GPT 生成 · \(facts.date) · \(facts.timeZone)")
                        .font(.system(size: 10))
                        .foregroundStyle(Ink.quiet)
                    Spacer()
                    Button("复制解读") {
                        let text = "GPT 文化解读 · \(facts.date) · \(facts.timeZone)\n\n"
                            + result.reading.copyText
                            + "\n\nGPT 生成内容可能有误，传统象意解读供文化体验与日常反思。"
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .buttonStyle(OutlineButton())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(Panel(radius: 12))
        .sheet(isPresented: $configuring) { GPTKeySettings(session: session) }
        .onChange(of: facts) { _, _ in session.invalidate() }
        .onDisappear { session.invalidate() }
    }

    private func generatedSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Ink.goldLight)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Ink.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }
}

private struct GPTKeySettings: View {
    let session: GPTSession
    @Environment(\.dismiss) private var dismiss
    @StateProperty private var draft = ""
    @StateProperty private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("OpenAI API 设置")
                .font(song(28))
                .foregroundStyle(Ink.text)
            Text("填写你自己的 OpenAI API Key。关闭应用后需重新填写，也可通过启动环境 OPENAI_API_KEY 提供。")
                .font(.system(size: 13))
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField(session.hasKey ? "粘贴新的 API Key 以替换" : "OpenAI API Key", text: $draft)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("OpenAI API Key")
            if let source = session.keySource {
                Label(source, systemImage: "lock")
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.quiet)
            }
            Text("生成解读会通过 HTTPS 连接 api.openai.com。请使用具有模型访问权限和可用额度的 API 账户。")
                .font(.system(size: 11))
                .foregroundStyle(Ink.quiet)
                .fixedSize(horizontal: false, vertical: true)
            if let error {
                Text(error).font(.system(size: 12)).foregroundStyle(Ink.element(.fire))
            }
            HStack(spacing: 10) {
                if session.hasKey {
                    Button("清除 API Key") {
                        session.clearKey()
                        draft = ""
                        dismiss()
                    }
                    .buttonStyle(OutlineButton())
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(OutlineButton())
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    do {
                        try session.setKey(draft)
                        draft = ""
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
                .buttonStyle(GoldButton())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 500)
        .background(Ink.background)
        .onChange(of: draft) { _, _ in error = nil }
    }
}
