import Foundation
import XCTest
@testable import Teleprompter

final class FakeLLMURLProtocol: URLProtocol, @unchecked Sendable {
    struct ResponseConfig: Sendable {
        var statusCode: Int = 200
        var headers: [String: String] = ["Content-Type": "text/event-stream"]
        var sseEvents: [String] = []
        var rawData: Data?
        var holdOpenUntilCancelled: Bool = false
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _config = ResponseConfig()
    nonisolated(unsafe) private static var _recordedRequests: [URLRequest] = []
    nonisolated(unsafe) private static var _recordedBodies: [Data] = []
    nonisolated(unsafe) private static var _didStopLoading = false

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _config = ResponseConfig()
        _recordedRequests = []
        _recordedBodies = []
        _didStopLoading = false
    }

    static var config: ResponseConfig {
        get { lock.lock(); defer { lock.unlock() }; return _config }
        set { lock.lock(); defer { lock.unlock() }; _config = newValue }
    }

    static var recordedRequests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }; return _recordedRequests
    }

    static var recordedBodies: [Data] {
        lock.lock(); defer { lock.unlock() }; return _recordedBodies
    }

    static var didStopLoading: Bool {
        lock.lock(); defer { lock.unlock() }; return _didStopLoading
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let bodyData = extractBody()
        Self.lock.lock()
        Self._recordedRequests.append(request)
        if let body = bodyData { Self._recordedBodies.append(body) }
        let config = Self._config
        Self.lock.unlock()

        guard let url = request.url else { return }
        let response = HTTPURLResponse(url: url, statusCode: config.statusCode, httpVersion: "HTTP/1.1", headerFields: config.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        if let rawData = config.rawData {
            client?.urlProtocol(self, didLoad: rawData)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        if !config.sseEvents.isEmpty {
            let bodyString = config.sseEvents.joined(separator: "\n\n") + "\n\n"
            if let data = bodyString.data(using: .utf8) { client?.urlProtocol(self, didLoad: data) }
        }

        if !config.holdOpenUntilCancelled {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    private func extractBody() -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        var buffer = [UInt8](repeating: 0, count: 4096), collected = Data()
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read > 0 { collected.append(buffer, count: read) } else { break }
        }
        stream.close()
        return collected
    }

    override func stopLoading() {
        Self.lock.lock()
        Self._didStopLoading = true
        Self.lock.unlock()
    }
}

final class LLMStreamingAnswerGeneratorTests: XCTestCase {
    private let baseURL = URL(string: "https://api.fake-llm.com/v1")!
    private let model = "fast-model"
    private let chunks = [
        Chunk(text: "Swift 6 traz concorrência completa.", source: SourceRef(path: "docs/swift.md")),
        Chunk(text: "App requer iOS 17.2.", source: SourceRef(path: "README.md"))
    ]

    override func setUp() {
        super.setUp()
        FakeLLMURLProtocol.reset()
    }

    override func tearDown() {
        FakeLLMURLProtocol.reset()
        super.tearDown()
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeLLMURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testDeltasInOrderAndStreamFinishes() async throws {
        let events = [
            #"data: {"choices":[{"delta":{"content":"O "}}]}"#,
            #"data: {"choices":[{"delta":{"content":"Swift "}}]}"#,
            #"data: {"choices":[{"delta":{"content":"é "}}]}"#,
            #"data: {"choices":[{"delta":{"content":"rápido."}}]}"#,
            "data: [DONE]"
        ]
        FakeLLMURLProtocol.config = .init(sseEvents: events)

        let secretStore = InMemorySecretStore(initial: ["llm_api_key": "test-key-123"])
        let generator = StreamingAnswerGenerator(baseURL: baseURL, model: model, secretStore: secretStore, session: makeSession())

        var received: [String] = []
        for await piece in generator.generate(question: "O que é Swift?", context: chunks) {
            received.append(piece)
        }

        XCTAssertEqual(received, ["O ", "Swift ", "é ", "rápido."])
        XCTAssertEqual(received.joined(), "O Swift é rápido.")
    }

    func testCancellationCancelsRequest() async throws {
        FakeLLMURLProtocol.config = .init(
            sseEvents: [#"data: {"choices":[{"delta":{"content":"início"}}]}"#],
            holdOpenUntilCancelled: true
        )

        let secretStore = InMemorySecretStore(initial: ["llm_api_key": "test-key-123"])
        let generator = StreamingAnswerGenerator(baseURL: baseURL, model: model, secretStore: secretStore, session: makeSession())
        let testChunks = chunks

        let consumerTask = Task {
            var items: [String] = []
            for await piece in generator.generate(question: "Pergunta", context: testChunks) {
                items.append(piece)
                if !items.isEmpty { break }
            }
            return items
        }

        let first = await consumerTask.value
        XCTAssertEqual(first, ["início"])

        for _ in 0..<50 {
            if FakeLLMURLProtocol.didStopLoading { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(FakeLLMURLProtocol.didStopLoading)
    }

    func testHTTP401Error() async throws {
        FakeLLMURLProtocol.config = .init(statusCode: 401, headers: ["Content-Type": "application/json"])
        let tracker = LLMErrorTracker()
        let store = InMemorySecretStore(initial: ["llm_api_key": "invalid"])
        let gen = StreamingAnswerGenerator(
            baseURL: baseURL, model: model, secretStore: store, session: makeSession(), onError: { tracker.record($0) }
        )

        var pieces: [String] = []
        for await piece in gen.generate(question: "Q", context: chunks) { pieces.append(piece) }

        XCTAssertTrue(pieces.isEmpty)
        XCTAssertEqual(tracker.lastError, .httpStatus(401))
    }

    func testHTTP500Error() async throws {
        FakeLLMURLProtocol.config = .init(statusCode: 500, headers: ["Content-Type": "application/json"])
        let tracker = LLMErrorTracker()
        let store = InMemorySecretStore(initial: ["llm_api_key": "key"])
        let gen = StreamingAnswerGenerator(
            baseURL: baseURL, model: model, secretStore: store, session: makeSession(), onError: { tracker.record($0) }
        )

        var pieces: [String] = []
        for await piece in gen.generate(question: "Q", context: chunks) { pieces.append(piece) }

        XCTAssertTrue(pieces.isEmpty)
        XCTAssertEqual(tracker.lastError, .httpStatus(500))
    }

    func testInvalidJSONYieldsInvalidResponseError() async throws {
        FakeLLMURLProtocol.config = .init(sseEvents: ["data: {invalid-json}"])
        let tracker = LLMErrorTracker()
        let store = InMemorySecretStore(initial: ["llm_api_key": "key"])
        let gen = StreamingAnswerGenerator(
            baseURL: baseURL, model: model, secretStore: store, session: makeSession(), onError: { tracker.record($0) }
        )

        var pieces: [String] = []
        for await piece in gen.generate(question: "Q", context: chunks) { pieces.append(piece) }

        XCTAssertTrue(pieces.isEmpty)
        XCTAssertEqual(tracker.lastError, .invalidResponse)
    }

    func testMissingAPIKeyYieldsMissingKeyErrorAndNoNetworkRequest() async throws {
        let tracker = LLMErrorTracker()
        let store = InMemorySecretStore(initial: [:])
        let gen = StreamingAnswerGenerator(
            baseURL: baseURL, model: model, secretStore: store, session: makeSession(), onError: { tracker.record($0) }
        )

        var pieces: [String] = []
        for await piece in gen.generate(question: "Q", context: chunks) { pieces.append(piece) }

        XCTAssertTrue(pieces.isEmpty)
        XCTAssertEqual(tracker.lastError, .missingAPIKey)
        XCTAssertTrue(FakeLLMURLProtocol.recordedRequests.isEmpty)
    }

    func testNoChunksNeverCallsNetworkAndReturnsEmptyStream() async throws {
        let tracker = LLMErrorTracker()
        let store = InMemorySecretStore(initial: ["llm_api_key": "key"])
        let gen = StreamingAnswerGenerator(
            baseURL: baseURL, model: model, secretStore: store, session: makeSession(), onError: { tracker.record($0) }
        )

        var pieces: [String] = []
        for await piece in gen.generate(question: "Q", context: []) { pieces.append(piece) }

        XCTAssertTrue(pieces.isEmpty)
        XCTAssertNil(tracker.lastError)
        XCTAssertTrue(FakeLLMURLProtocol.recordedRequests.isEmpty)
    }

    func testRequestBodyContainsChunksAndQuestionWithoutKey() async throws {
        let key = "super-secret-key-12345"
        FakeLLMURLProtocol.config = .init(sseEvents: [#"data: {"choices":[{"delta":{"content":"Ok"}}]}"#, "data: [DONE]"])

        let store = InMemorySecretStore(initial: ["llm_api_key": key])
        let gen = StreamingAnswerGenerator(baseURL: baseURL, model: model, secretStore: store, session: makeSession())

        let question = "Qual a versão mínima do iOS?"
        for await _ in gen.generate(question: question, context: chunks) {}

        XCTAssertEqual(FakeLLMURLProtocol.recordedRequests.count, 1)
        guard let request = FakeLLMURLProtocol.recordedRequests.first,
              let bodyData = FakeLLMURLProtocol.recordedBodies.first,
              let body = String(data: bodyData, encoding: .utf8) else {
            XCTFail("Requisição não gravada")
            return
        }

        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(key)")
        XCTAssertTrue(body.contains("Swift 6 traz concorrência completa."))
        XCTAssertTrue(body.contains("docs/swift.md"))
        XCTAssertTrue(body.contains("App requer iOS 17.2."))
        XCTAssertTrue(body.contains("README.md"))
        XCTAssertTrue(body.contains(question))
        XCTAssertFalse(body.contains(key))
        XCTAssertFalse(request.url?.absoluteString.contains(key) ?? false)
    }

    func testMakeRequestNumbersContextByUniqueSourcePath() throws {
        let key = "test-api-key"
        let store = InMemorySecretStore(initial: ["llm_api_key": key])
        let gen = StreamingAnswerGenerator(baseURL: baseURL, model: model, secretStore: store)

        let testChunks = [
            Chunk(text: "DAT SDK só tem módulos Swift.", source: SourceRef(path: "qa/stack.md")),
            Chunk(text: "Swift 6 traz concorrência.", source: SourceRef(path: "docs/adr/0001-swift.md")),
            Chunk(text: "Menor latência de áudio.", source: SourceRef(path: "qa/stack.md"))
        ]

        let request = try gen.makeRequest(question: "Por que Swift?", context: testChunks, apiKey: key)
        guard let bodyData = request.httpBody,
              let body = String(data: bodyData, encoding: .utf8) else {
            XCTFail("Requisição não gerou body")
            return
        }

        // Trechos do mesmo arquivo (qa/stack.md) devem estar sob o mesmo número [1]
        XCTAssertTrue(body.contains("[1] Fonte: qa/stack.md\\nDAT SDK só tem módulos Swift."))
        XCTAssertTrue(body.contains("[1] Fonte: qa/stack.md\\nMenor latência de áudio."))

        // Novo arquivo recebe número [2]
        XCTAssertTrue(body.contains("[2] Fonte: docs/adr/0001-swift.md\\nSwift 6 traz concorrência."))

        // Ordem dos números coincide com ordem das fontes únicas
        let range1 = body.range(of: "[1] Fonte: qa/stack.md")!
        let range2 = body.range(of: "[2] Fonte: docs/adr/0001-swift.md")!
        XCTAssertTrue(range1.lowerBound < range2.lowerBound)
    }

    func testErrorsDoNotLeakKeyOrQuestion() {
        let key = "super-secret-api-key-xyz"
        let question = "Pergunta confidencial"
        let errors: [LLMError] = [
            .missingAPIKey,
            .network("Falha de conexão com o host"),
            .httpStatus(401),
            .invalidResponse
        ]

        for error in errors {
            for text in [String(describing: error), error.localizedDescription, error.errorDescription ?? ""] {
                XCTAssertFalse(text.contains(key))
                XCTAssertFalse(text.contains(question))
            }
        }
    }
}

final class LLMErrorTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var _lastError: LLMError?

    var lastError: LLMError? {
        lock.lock()
        defer { lock.unlock() }
        return _lastError
    }

    func record(_ error: LLMError) {
        lock.lock()
        defer { lock.unlock() }
        _lastError = error
    }
}

final class DefaultSystemPromptTests: XCTestCase {
    func testPromptAllowsPartialAnswersButKeepsClosedRAGRefusal() {
        let prompt = StreamingAnswerGenerator.defaultSystemPrompt
        XCTAssertTrue(prompt.contains("mesmo que parcialmente"))
        XCTAssertTrue(prompt.contains("nunca use conhecimento externo"))
        XCTAssertTrue(prompt.contains(AnswerPipeline.notFoundMessage))
        XCTAssertTrue(prompt.contains("[n]"))
        XCTAssertTrue(prompt.localizedCaseInsensitiveContains("ao fim de cada tópico"))
        XCTAssertTrue(prompt.contains("números do contexto"))
        XCTAssertEqual(FoundationModelsAnswerGenerator.defaultSystemPrompt, prompt)
    }
}
