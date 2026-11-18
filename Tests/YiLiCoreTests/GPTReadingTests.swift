import Foundation
import Testing
@testable import YiLiCore

@Suite(.serialized)
struct GPTReadingTests {
    private func facts() throws -> GPTFacts {
        let chart = try BaziCalculator.chart(for: BirthInput(
            year: 2000, month: 1, day: 7, hour: 12, minute: 0, timeZoneID: "Asia/Shanghai"
        ))
        let date = try #require(ISO8601DateFormatter().date(from: "2024-02-04T16:30:00Z"))
        return GPTFacts.make(chart: chart, date: date, termDate: date, timeZone: TimeZone(identifier: "Asia/Shanghai")!)
    }

    @Test func sentFactsUseLocalCalculationsAndExcludeOriginalBirthInput() throws {
        let facts = try facts()
        #expect(facts.date == "2024-02-05")
        #expect(facts.timeZone == "Asia/Shanghai")
        #expect(facts.solarTerm == "立春")
        #expect(facts.pillars == ["己卯", "丁丑", "甲子", "庚午"])
        #expect(facts.dayMaster == "甲木")
        #expect(facts.fiveElements == ["木": 25, "火": 21.25, "土": 23.75, "金": 13.75, "水": 16.25])
        #expect(facts.dailyPillar == "己亥")
        #expect(facts.trigram == "坎")
        #expect(facts.direction == "正北")
        #expect(facts.basis.contains("甲木克流日天干己土"))
        let encoded = String(decoding: try facts.jsonData(), as: UTF8.self)
        #expect(!encoded.contains("2000"))
        #expect(!encoded.contains("minute"))
        #expect(!encoded.contains("timeZoneID"))
    }

    @Test func requestUsesSharedContractAndFixedOpenAIEndpoint() async throws {
        let facts = try facts()
        MockGPTProtocol.handler = { request in
            #expect(request.url == GPTClient.endpoint)
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer unit-test-key")
            let data = try requestData(request)
            let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(json["model"] as? String == "gpt-5.4-mini")
            #expect(json["store"] as? Bool == false)
            #expect(json["max_output_tokens"] as? Int == 1800)
            #expect((json["reasoning"] as? [String: String])?["effort"] == "low")
            #expect(json["input"] as? String == String(decoding: try facts.jsonData(), as: UTF8.self))
            let text = try #require(json["text"] as? [String: Any])
            let format = try #require(text["format"] as? [String: Any])
            #expect(format["type"] as? String == "json_schema")
            #expect(format["strict"] as? Bool == true)
            #expect(!data.contains(Data("unit-test-key".utf8)))
            return (200, try envelope())
        }
        let session = mockSession()
        defer { session.invalidateAndCancel() }
        let reading = try await GPTClient(session: session).generate(facts: facts, apiKey: " unit-test-key\n")
        #expect(reading.overview == "整体描述内容")
        #expect(reading.reasoning == "命理依据内容")
        #expect(reading.guidance == "今日行动内容")
        #expect(reading.limits == "解读边界内容")
    }

    @Test func transportErrorsUseSafeActionableMessages() async throws {
        let facts = try facts()
        for (status, expected) in [(401, GPTError.authentication), (403, .authentication), (429, .rateLimit), (503, .server), (400, .requestRejected)] {
            MockGPTProtocol.handler = { _ in (status, Data("private server response".utf8)) }
            let session = mockSession()
            defer { session.invalidateAndCancel() }
            await #expect(throws: expected) {
                try await GPTClient(session: session).generate(facts: facts, apiKey: "unit-test-key")
            }
        }
        MockGPTProtocol.handler = { _ in throw URLError(.timedOut) }
        let session = mockSession()
        defer { session.invalidateAndCancel() }
        await #expect(throws: GPTError.timedOut) {
            try await GPTClient(session: session).generate(facts: facts, apiKey: "unit-test-key")
        }
        MockGPTProtocol.handler = { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) {
            try await GPTClient(session: session).generate(facts: facts, apiKey: "unit-test-key")
        }
    }

    @Test func refusesIncompleteEmptyAndMalformedContent() throws {
        #expect(throws: GPTError.incomplete) {
            try GPTClient.readResponse(envelope(status: "incomplete"))
        }
        #expect(throws: GPTError.refused) {
            try GPTClient.readResponse(envelope(type: "refusal"))
        }
        #expect(throws: GPTError.invalidResponse) {
            try GPTClient.readResponse(envelope(text: "{\"overview\":\"incomplete\"}"))
        }
        #expect(throws: GPTError.invalidResponse) {
            try GPTClient.readResponse(envelope(text: "{\"overview\":\" \",\"reasoning\":\"x\",\"guidance\":\"x\",\"limits\":\"x\"}"))
        }
        #expect(throws: GPTError.invalidResponse) {
            try GPTClient.readResponse(Data("invalid json".utf8))
        }
    }

    @Test func keyValidationRejectsControlCharactersBeforeNetworkUse() throws {
        #expect(throws: GPTError.missingKey) { try GPTClient.validatedKey(" \n") }
        #expect(throws: GPTError.invalidKey) { try GPTClient.validatedKey("unit-test-key\nInjected-Header") }
        #expect(try GPTClient.validatedKey(" unit-test-key ") == "unit-test-key")
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockGPTProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private func requestData(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    let stream = try #require(request.httpBodyStream)
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        result.append(buffer, count: count)
    }
    return result
}

private func envelope(status: String = "completed", type: String = "output_text", text: String? = nil) throws -> Data {
    let reading = ["overview": "整体描述内容", "reasoning": "命理依据内容", "guidance": "今日行动内容", "limits": "解读边界内容"]
    let output = try text ?? String(decoding: JSONSerialization.data(withJSONObject: reading), as: UTF8.self)
    return try JSONSerialization.data(withJSONObject: [
        "status": status, "output": [["type": "message", "content": [["type": type, "text": output]]]],
    ])
}

private final class MockGPTProtocol: URLProtocol, @unchecked Sendable {
    // The suite is serialized, and each handler is set before its session is started.
    static var handler: ((URLRequest) throws -> (Int, Data))!

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (status, data) = try Self.handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}
}
