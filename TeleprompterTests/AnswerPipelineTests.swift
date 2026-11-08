import XCTest
@testable import Teleprompter

final class AnswerPipelineTests: XCTestCase {
    private let src = SourceRef(path: "qa/stack.md")

    private func run(_ result: Retrieval) async throws -> (LensContent?, FakeGenerator) {
        let gen = FakeGenerator(), lens = SimulatedLens()
        let pipeline = AnswerPipeline(
            retriever: FakeRetriever(result: result), generator: gen, formatter: PassthroughFormatter(), lens: lens
        )
        try await pipeline.ask("Por que Swift?")
        return (await lens.shown, gen)
    }

    func testQANoteGoesStraightToLensWithoutLLM() async throws {
        let (shown, gen) = try await run(Retrieval(qaNote: Chunk(text: "Nota", source: src), chunks: []))
        XCTAssertEqual(shown?.body, "Nota")
        XCTAssertEqual(shown?.sources, [src])
        XCTAssertEqual(gen.calls, 0)
    }

    func testChunksGoThroughLLM() async throws {
        let (shown, gen) = try await run(Retrieval(qaNote: nil, chunks: [Chunk(text: "trecho", source: src)]))
        XCTAssertEqual(shown?.body, "resposta gerada")
        XCTAssertEqual(gen.calls, 1)
    }

    func testNothingFoundNeverCallsLLM() async throws {
        let (shown, gen) = try await run(Retrieval(qaNote: nil, chunks: []))
        XCTAssertEqual(shown?.body, AnswerPipeline.notFoundMessage)
        XCTAssertEqual(gen.calls, 0)
    }
}
