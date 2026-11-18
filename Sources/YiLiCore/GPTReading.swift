import Foundation

public struct GPTFacts: Codable, Equatable, Sendable {
    public let date: String
    public let timeZone: String
    public let solarTerm: String
    public let pillars: [String]
    public let dayMaster: String
    public let fiveElements: [String: Double]
    public let dailyPillar: String
    public let trigram: String
    public let direction: String
    public let basis: String

    public static func make(chart: BaziChart, date: Date, termDate: Date, timeZone: TimeZone) -> GPTFacts {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let natal = Interpretation.natal(for: chart)
        let daily = Interpretation.daily(for: chart, day: BaziCalculator.dayPillar(for: date, in: timeZone))
        let elements = Dictionary(uniqueKeysWithValues: natal.elements.map {
            ($0.element.rawValue, ($0.fraction * 10_000).rounded() / 100)
        })
        return GPTFacts(
            date: formatter.string(from: date), timeZone: timeZone.identifier,
            solarTerm: BaziCalculator.solarTerms(around: termDate, in: timeZone)?.current.term.rawValue ?? "未知",
            pillars: chart.pillars.map(\.text), dayMaster: natal.dayMaster.text + natal.dayMaster.element.rawValue,
            fiveElements: elements, dailyPillar: daily.pillar.text, trigram: daily.trigram.name,
            direction: daily.trigram.direction, basis: daily.basis
        )
    }

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
}

public struct GPTReading: Decodable, Equatable, Sendable {
    public let overview: String
    public let reasoning: String
    public let guidance: String
    public let limits: String

    public var copyText: String {
        "整体描述\n\(overview)\n\n命理与易经依据\n\(reasoning)\n\n今日行动\n\(guidance)\n\n解读边界\n\(limits)"
    }
}

public enum GPTError: Error, LocalizedError, Equatable, Sendable {
    case missingKey
    case invalidKey
    case configuration
    case authentication
    case rateLimit
    case server
    case requestRejected
    case incomplete
    case refused
    case invalidResponse
    case network
    case timedOut

    public var errorDescription: String? {
        switch self {
        case .missingKey: "请先设置 OpenAI API Key。"
        case .invalidKey: "API Key 含有无效字符，请重新粘贴。"
        case .configuration: "GPT 配置加载失败，请重新安装完整的应用。"
        case .authentication: "API Key 验证失败或权限不足，请检查后重新设置。"
        case .rateLimit: "API 额度不足或请求过于频繁，请检查账户额度后重试。"
        case .server: "OpenAI 服务暂时不可用，请稍后重试。"
        case .requestRejected: "请求未被接受，请检查 API 账户的模型访问权限。"
        case .incomplete: "本次解读未完整生成，请重试。"
        case .refused: "GPT 未能提供这次解读，请重试。"
        case .invalidResponse: "收到的解读格式不完整，请重试。"
        case .network: "无法连接 OpenAI，请检查网络后重试。"
        case .timedOut: "生成超时，请重试。"
        }
    }
}

public struct GPTClient: Sendable {
    private let session: URLSession
    public static let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    public init(session: URLSession? = nil) {
        self.session = session ?? URLSession(
            configuration: .ephemeral, delegate: GPTSessionDelegate(), delegateQueue: nil
        )
    }

    public func generate(facts: GPTFacts, apiKey: String) async throws -> GPTReading {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 75)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try Self.validatedKey(apiKey))", forHTTPHeaderField: "Authorization")
        request.httpBody = try Self.requestBody(facts: facts)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw GPTError.timedOut
            default: throw GPTError.network
            }
        }
        guard let http = response as? HTTPURLResponse else { throw GPTError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401, 403: throw GPTError.authentication
        case 429: throw GPTError.rateLimit
        case 500...599: throw GPTError.server
        default: throw GPTError.requestRejected
        }
        return try Self.readResponse(data)
    }

    public static func validatedKey(_ value: String) throws -> String {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw GPTError.missingKey }
        guard key.unicodeScalars.allSatisfy({ (33...126).contains($0.value) }) else {
            throw GPTError.invalidKey
        }
        return key
    }

    static func requestBody(facts: GPTFacts) throws -> Data {
        guard var contract = try JSONSerialization.jsonObject(with: contractData()) as? [String: Any],
              contract["model"] is String, contract["instructions"] is String,
              let format = contract.removeValue(forKey: "format") as? [String: Any],
              contract["max_output_tokens"] is Int else { throw GPTError.configuration }
        contract["input"] = String(decoding: try facts.jsonData(), as: UTF8.self)
        contract["text"] = ["format": format]
        contract["store"] = false
        contract["reasoning"] = ["effort": "low"]
        return try JSONSerialization.data(withJSONObject: contract, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    private static func contractData() throws -> Data {
        let name = "fortune-contract"
        let resourceBundle = Bundle.main.resourceURL?.appendingPathComponent("YiLi_YiLiCore.bundle")
        let bundledURL = resourceBundle.flatMap { Bundle(url: $0)?.url(forResource: name, withExtension: "json") }
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") ?? bundledURL
            ?? Bundle.module.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { throw GPTError.configuration }
        return data
    }

    static func readResponse(_ data: Data) throws -> GPTReading {
        guard let response = try? JSONDecoder().decode(ResponseEnvelope.self, from: data) else {
            throw GPTError.invalidResponse
        }
        guard response.status == "completed" else { throw GPTError.incomplete }
        let content = response.output.filter { $0.type == "message" }.flatMap { $0.content ?? [] }
        guard !content.contains(where: { $0.type == "refusal" }) else { throw GPTError.refused }
        let text = content.filter { $0.type == "output_text" }.compactMap(\.text).joined()
        guard let reading = try? JSONDecoder().decode(GPTReading.self, from: Data(text.utf8)),
              [reading.overview, reading.reasoning, reading.guidance, reading.limits].allSatisfy({
                  !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              }) else { throw GPTError.invalidResponse }
        return reading
    }
}

private final class GPTSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private struct ResponseEnvelope: Decodable {
    let status: String
    let output: [Output]

    struct Output: Decodable {
        let type: String
        let content: [Content]?
    }

    struct Content: Decodable {
        let type: String
        let text: String?
    }
}
