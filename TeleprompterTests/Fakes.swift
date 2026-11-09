@testable import Teleprompter

struct FakeRetriever: Retriever {
    var result: Retrieval
    func retrieve(_ question: String) async throws -> Retrieval { result }
}

final class FakeGenerator: AnswerGenerator, @unchecked Sendable {
    private(set) var calls = 0
    var pieces = ["resposta ", "gerada"]
    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        calls += 1
        let pieces = pieces
        return AsyncStream { stream in pieces.forEach { stream.yield($0) }; stream.finish() }
    }
}

struct PassthroughFormatter: ResponseFormatter {
    func format(_ text: String, as format: AnswerFormat) -> String { text }
}

actor SimulatedLens: Lens {
    private(set) var shown: LensContent?
    func show(_ content: LensContent) { shown = content }
    func clear() { shown = nil }
}
