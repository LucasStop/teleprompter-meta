import XCTest
@testable import Teleprompter

final class AnswerPipelineTests: XCTestCase {
    private let src = SourceRef(path: "qa/stack.md")

    private func run(_ result: Retrieval) async throws -> (LensContent?, FakeGenerator) {
        let gen = FakeGenerator(), lens = RecordingLens()
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

    func testPipelineStripsCitationsBeforeSendingToLens() async throws {
        let gen = CustomTextGenerator(text: "• DAT SDK só tem módulos Swift[1]\n• Menor latência de áudio[2]")
        let lens = RecordingLens()
        let pipeline = AnswerPipeline(
            retriever: FakeRetriever(result: Retrieval(qaNote: nil, chunks: [Chunk(text: "trecho", source: src)])),
            generator: gen,
            formatter: PassthroughFormatter(),
            lens: lens
        )

        let result = try await pipeline.ask("Por que Swift?")
        let shown = await lens.shown

        // Lente nunca mostra marcadores [n]
        XCTAssertEqual(shown?.body, "• DAT SDK só tem módulos Swift\n• Menor latência de áudio")
        XCTAssertFalse(shown?.body.contains("[1]") == true)
        XCTAssertFalse(shown?.body.contains("[2]") == true)

        // Resposta do pipeline mantém [n] para renderização com citação no iPhone
        XCTAssertTrue(result.text.contains("[1]"))
        XCTAssertTrue(result.text.contains("[2]"))
    }

    func testPipelineDeduplicatesSourcesPreservingOrder() async throws {
        let src1 = SourceRef(path: "qa/stack.md")
        let src2 = SourceRef(path: "docs/adr.md")
        let retrieval = Retrieval(
            qaNote: nil,
            chunks: [
                Chunk(text: "t1", source: src1),
                Chunk(text: "t2", source: src2),
                Chunk(text: "t3", source: src1)
            ]
        )
        let (shown, _) = try await run(retrieval)
        XCTAssertEqual(shown?.sources, [src1, src2])
    }
}

private final class CustomTextGenerator: AnswerGenerator, @unchecked Sendable {
    let text: String
    init(text: String) { self.text = text }
    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        AsyncStream { continuation in
            continuation.yield(text)
            continuation.finish()
        }
    }
}
