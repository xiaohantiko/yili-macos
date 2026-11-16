import SwiftUI
import YiLiCore

struct BirthEditor: View {
    @Environment(\.dismiss) private var dismiss
    @StateProperty private var draft: BirthDraft
    @StateProperty private var error: String?
    @StateProperty private var selectingZone = false
    @FocusState private var yearFocused: Bool

    let isSample: Bool
    let save: (BirthInput) throws -> Void
    let reset: () throws -> Void

    init(
        birth: BirthInput,
        isSample: Bool,
        save: @escaping (BirthInput) throws -> Void,
        reset: @escaping () throws -> Void
    ) {
        _draft = StateProperty(initialValue: BirthDraft(birth, isSample: isSample))
        self.isSample = isSample
        self.save = save
        self.reset = reset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            VStack(alignment: .leading, spacing: 8) {
                IndexLabel("BIRTH DETAILS")
                Text("出生资料")
                    .font(song(32))
                    .foregroundStyle(Ink.text)
                Text("填写出生地当时的钟表时间。")
                    .font(.system(size: 13))
                    .foregroundStyle(Ink.secondary)
            }

            Rectangle().fill(Ink.line).frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                let years = BaziCalculator.supportedYears
                fieldTitle("公历出生日期", note: "\(years.lowerBound)–\(years.upperBound) 年")
                HStack(spacing: 10) {
                    dateField("年", value: $draft.year, hint: "YYYY")
                        .focused($yearFocused)
                    dateField("月", value: $draft.month, hint: "MM")
                    dateField("日", value: $draft.day, hint: "DD")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle("出生时间", note: "24 小时制")
                HStack(spacing: 10) {
                    dateField("时", value: $draft.hour, hint: "HH")
                    dateField("分", value: $draft.minute, hint: "MM")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldTitle("出生时区")
                Button {
                    selectingZone = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "globe.asia.australia")
                            .foregroundStyle(Ink.gold)
                        Text(TimeZoneCatalog.displayName(draft.timeZoneID))
                            .foregroundStyle(Ink.text)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Ink.quiet)
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                    .modifier(Panel(radius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("出生时区")
                .accessibilityValue(TimeZoneCatalog.displayName(draft.timeZoneID))
                .popover(isPresented: $selectingZone, arrowEdge: .bottom) {
                    TimeZonePicker(selected: draft.timeZoneID) { zone in
                        draft.timeZoneID = zone
                        selectingZone = false
                    }
                }
            }

            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.element(.fire))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                if isSample {
                    Label("仅保存在这台 Mac", systemImage: "lock")
                        .font(.system(size: 11))
                        .foregroundStyle(Ink.quiet)
                } else {
                    Button("清除出生资料") { apply(reset) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Ink.goldLight)
                        .help("清除本机出生资料，返回体验命盘")
                }
                Spacer()
                Button("取消") { dismiss() }
                    .buttonStyle(OutlineButton())
                    .keyboardShortcut(.cancelAction)
                Button("保存并排盘") {
                    apply { try save(draft.birth()) }
                }
                .buttonStyle(GoldButton())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 480)
        .background(Ink.background)
        .defaultFocus($yearFocused, true)
        .onChange(of: draft) { _, _ in error = nil }
    }

    private func fieldTitle(_ title: String, note: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.text)
            if let note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.quiet)
            }
        }
    }

    private func dateField(_ unit: String, value: Binding<String>, hint: String) -> some View {
        HStack(spacing: 5) {
            TextField(hint, text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Ink.text)
                .accessibilityLabel(unit)
            Text(unit)
                .font(.system(size: 12))
                .foregroundStyle(Ink.quiet)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .modifier(Panel(radius: 6))
    }

    private func apply(_ action: () throws -> Void) {
        do {
            try action()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct BirthDraft: Equatable {
    var year: String
    var month: String
    var day: String
    var hour: String
    var minute: String
    var timeZoneID: String

    init(_ birth: BirthInput, isSample: Bool) {
        year = isSample ? "" : String(birth.year)
        month = isSample ? "" : String(format: "%02d", birth.month)
        day = isSample ? "" : String(format: "%02d", birth.day)
        hour = isSample ? "" : String(format: "%02d", birth.hour)
        minute = isSample ? "" : String(format: "%02d", birth.minute)
        timeZoneID = isSample ? TimeZone.autoupdatingCurrent.identifier : birth.timeZoneID
    }

    func birth() throws -> BirthInput {
        guard let year = number(year), let month = number(month), let day = number(day) else {
            throw BaziError.invalidDate
        }
        guard let hour = number(hour), let minute = number(minute) else {
            throw BaziError.invalidTime
        }
        return BirthInput(year: year, month: month, day: day, hour: hour, minute: minute, timeZoneID: timeZoneID)
    }

    private func number(_ text: String) -> Int? {
        let normalized = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        return Int(normalized.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

enum TimeZoneCatalog {
    static let common: [(id: String, name: String)] = [
        ("Asia/Shanghai", "中国大陆（上海）"),
        ("Asia/Hong_Kong", "中国香港"),
        ("Asia/Macau", "中国澳门"),
        ("Asia/Taipei", "中国台北"),
        ("Asia/Singapore", "新加坡"),
        ("Asia/Tokyo", "东京"),
        ("Asia/Seoul", "首尔"),
        ("Australia/Sydney", "悉尼"),
        ("Europe/London", "伦敦"),
        ("America/New_York", "纽约"),
        ("America/Los_Angeles", "洛杉矶"),
        ("UTC", "协调世界时（UTC）")
    ]

    static let all: [String] = {
        let preferred = common.map(\.id)
        return preferred + TimeZone.knownTimeZoneIdentifiers.filter { !preferred.contains($0) }.sorted()
    }()

    static func displayName(_ id: String) -> String {
        common.first { $0.id == id }?.name ?? id.replacingOccurrences(of: "_", with: " ")
    }
}

private struct TimeZonePicker: View {
    let selected: String
    let choose: (String) -> Void
    @StateProperty private var query = ""

    private var matches: [String] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if term.isEmpty { return TimeZoneCatalog.all }
        return TimeZoneCatalog.all.filter {
            $0.localizedStandardContains(term) || TimeZoneCatalog.displayName($0).localizedStandardContains(term)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("搜索城市或时区", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 8)
            if matches.isEmpty {
                Text("没有匹配的时区")
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.secondary)
                    .padding(8)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(matches, id: \.self) { zone in
                            Button {
                                choose(zone)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(TimeZoneCatalog.displayName(zone))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(Ink.text)
                                        Text(zone)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundStyle(Ink.quiet)
                                    }
                                    Spacer()
                                    if selected == zone {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Ink.goldLight)
                                    }
                                }
                                .padding(7)
                                .background(
                                    selected == zone ? Ink.gold.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: 5)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(width: 315, height: 294)
    }
}
