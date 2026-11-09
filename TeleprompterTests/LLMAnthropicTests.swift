import Foundation
import XCTest
@testable import Teleprompter

final class LLMAnthropicTests: XCTestCase {
    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let model = "claude-3-5-haiku-20241022"
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

    func testAnthropicDeltasInOrderAndStreamFinishesIgnoringPing() async throws {
        let events = [
            #"event: message_start"#,
            #"data: {"type":"message_start","message":{"id":"m1","type":"message","role":"assistant","content":[],"model":"claude"}}"#,
            #"event: content_block_start"#,
            #"data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#,
            #"event: content_block_delta"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"O "}}"#,
            #"event: ping"#,
            #"data: {"type":"ping"}"#,
            #"event: content_block_delta"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Swift "}}"#,
            #"event: content_block_delta"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"é "}}"#,
            #"event: content_block_delta"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"rápido."}}"#,
            #"event: content_block_stop"#,
            #"data: {"type":"content_block_stop","index":0}"#,
            #"event: message_stop"#,
            #"data: {"type":"message_stop"}"#
        ]
        FakeLLMURLProtocol.config = .init(sseEvents: events)

        let secretStore = InMemorySecretStore(initial: ["llm_api_key": "test-anthropic-key-123"])
        let generator = StreamingAnswerGenerator(
            baseURL: baseURL,
            model: model,
            secretStore: secretStore,
            format: .anthropic,
            session: makeSession()
        )

        var received: [String] = []
        for await piece in generator.generate(question: "O que é Swift?", context: chunks) {
            received.append(piece)
        }

        XCTAssertEqual(received, ["O ", "Swift ", "é ", "rápido."])
        XCTAssertEqual(received.joined(), "O Swift é rápido.")
    }

    func testAnthropicHTTP401ErrorDoesNotLeakKey() async throws {
        FakeLLMURLProtocol.config = .init(statusCode: 401, headers: ["Content-Type": "application/json"])
        let tracker = LLMErrorTracker()
        let secretKey = "anthropic-secret-unauthorized-key-xyz"
        let store = InMemorySecretStore(initial: ["llm_api_key": secretKey])
        let gen = StreamingAnswerGenerator(
            baseURL: baseURL,
            model: model,
            secretStore: store,
            format: .anthropic,
            session: makeSession(),
            onError: { tracker.record($0) }
        )

        var pieces: [String] = []
        for await piece in gen.generate(question: "Q", context: chunks) { pieces.append(piece) }

        XCTAssertTrue(pieces.isEmpty)
        XCTAssertEqual(tracker.lastError, .httpStatus(401))
        if let err = tracker.lastError {
            XCTAssertFalse(err.localizedDescription.contains(secretKey))
            XCTAssertFalse(String(describing: err).contains(secretKey))
        }
    }

    func testAnthropicRequestBodyAndHeadersWithoutKeyLeak() async throws {
        let key = "sk-ant-api03-super-secret-anthropic-key-value"
        let events = [
            #"event: content_block_delta"#,
            #"data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Ok"}}"#,
            #"event: message_stop"#,
            #"data: {"type":"message_stop"}"#
        ]
        FakeLLMURLProtocol.config = .init(sseEvents: events)

        let store = InMemorySecretStore(initial: ["llm_api_key": key])
        let gen = StreamingAnswerGenerator(
            baseURL: baseURL,
            model: model,
            secretStore: store,
            format: .anthropic,
            session: makeSession()
        )

        let question = "Qual a versão mínima do iOS?"
        for await _ in gen.generate(question: question, context: chunks) {}

        XCTAssertEqual(FakeLLMURLProtocol.recordedRequests.count, 1)
        guard let request = FakeLLMURLProtocol.recordedRequests.first,
              let bodyData = FakeLLMURLProtocol.recordedBodies.first,
              let body = String(data: bodyData, encoding: .utf8) else {
            XCTFail("Requisição não gravada")
            return
        }

        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), key)
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(request.url?.path, "/v1/messages")

        XCTAssertTrue(body.contains("max_tokens"))
        XCTAssertTrue(body.contains("claude-3-5-haiku-20241022"))
        XCTAssertTrue(body.contains("system"))
        XCTAssertTrue(body.contains("messages"))
        XCTAssertTrue(body.contains("stream"))
        XCTAssertTrue(body.contains("Swift 6 traz concorrência completa."))
        XCTAssertTrue(body.contains(question))
        XCTAssertFalse(body.contains(key))
        XCTAssertFalse(request.url?.absoluteString.contains(key) ?? false)
    }

    func testAnthropicInvalidJSONYieldsInvalidResponseError() async throws {
        FakeLLMURLProtocol.config = .init(sseEvents: [#"data: {corrupted-anthropic-json}"#])
        let tracker = LLMErrorTracker()
        let store = InMemorySecretStore(initial: ["llm_api_key": "key"])
        let gen = StreamingAnswerGenerator(
            baseURL: baseURL,
            model: model,
            secretStore: store,
            format: .anthropic,
            session: makeSession(),
            onError: { tracker.record($0) }
        )

        var pieces: [String] = []
        for await piece in gen.generate(question: "Q", context: chunks) { pieces.append(piece) }

        XCTAssertTrue(pieces.isEmpty)
        XCTAssertEqual(tracker.lastError, .invalidResponse)
    }
}
