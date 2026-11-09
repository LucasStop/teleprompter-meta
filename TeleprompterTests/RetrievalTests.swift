import Foundation
import XCTest
@testable import Teleprompter

final class RetrievalTests: XCTestCase {
    private var tempDirectory: URL!
    private var databaseURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("RetrieverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        databaseURL = tempDirectory.appendingPathComponent("index.sqlite3")
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    private func makeCorpus() -> [IndexedChunk] {
        [
            IndexedChunk(
                kind: .qa,
                text: "O objetivo do Teleprompter é auxiliar o apresentador na defesa com respostas na lente.",
                source: "qa/apresentacao.md",
                question: "Qual é o objetivo do projeto?"
            ),
            IndexedChunk(
                kind: .document,
                text: "O Teleprompter Meta é um aplicativo iOS em Swift para escuta contínua e RAG fechado.",
                source: "README.md"
            ),
            IndexedChunk(
                kind: .code,
                text: "func ask(_ question: String) async throws { let found = try await retriever.retrieve(question) }",
                source: "Teleprompter/Domain/AnswerPipeline.swift"
            ),
            IndexedChunk(
                kind: .document,
                text: "A arquitetura adota pipeline linear com protocolos isolados e fakes para testes.",
                source: "docs/ARCHITECTURE.md"
            )
        ]
    }

    func testQANoteMatchesAndReturnsPreparedAnswerWithoutLLM() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)
        try retriever.index(makeCorpus())

        let result = try await retriever.retrieve("Qual é o objetivo do projeto?")

        XCTAssertNotNil(result.qaNote)
        XCTAssertEqual(
            result.qaNote?.text,
            "O objetivo do Teleprompter é auxiliar o apresentador na defesa com respostas na lente."
        )
        XCTAssertEqual(result.qaNote?.source.path, "qa/apresentacao.md")
        XCTAssertTrue(result.chunks.isEmpty)

        let gen = FakeGenerator(), lens = SimulatedLens()
        let pipeline = AnswerPipeline(
            retriever: retriever,
            generator: gen,
            formatter: PassthroughFormatter(),
            lens: lens
        )
        try await pipeline.ask("Qual é o objetivo do projeto?")
        let shown = await lens.shown
        XCTAssertEqual(shown?.body, result.qaNote?.text)
        XCTAssertEqual(shown?.sources, [SourceRef(path: "qa/apresentacao.md")])
        XCTAssertEqual(gen.calls, 0)
    }

    func testMatchesOnlyReadmeChunkWhenNoQANote() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)
        try retriever.index(makeCorpus())

        let result = try await retriever.retrieve("O que é o Teleprompter em Swift?")

        XCTAssertNil(result.qaNote)
        XCTAssertFalse(result.chunks.isEmpty)
        XCTAssertEqual(result.chunks.first?.source.path, "README.md")
        XCTAssertTrue(result.chunks.first?.text.contains("aplicativo iOS em Swift") ?? false)
    }

    func testMatchesCodeChunk() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)
        try retriever.index(makeCorpus())

        let result = try await retriever.retrieve("Como funciona a chamada do retriever.retrieve?")

        XCTAssertNil(result.qaNote)
        XCTAssertFalse(result.chunks.isEmpty)
        XCTAssertEqual(result.chunks.first?.source.path, "Teleprompter/Domain/AnswerPipeline.swift")
        XCTAssertTrue(result.chunks.first?.text.contains("retriever.retrieve") ?? false)
    }

    func testNoMatchReturnsEmptyResult() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)
        try retriever.index(makeCorpus())

        let result = try await retriever.retrieve("Receita de bolo de cenoura com chocolate")

        XCTAssertNil(result.qaNote)
        XCTAssertTrue(result.chunks.isEmpty)
        XCTAssertTrue(result.isEmpty)

        let gen = FakeGenerator(), lens = SimulatedLens()
        let pipeline = AnswerPipeline(
            retriever: retriever,
            generator: gen,
            formatter: PassthroughFormatter(),
            lens: lens
        )
        try await pipeline.ask("Receita de bolo de cenoura com chocolate")
        let shown = await lens.shown
        XCTAssertEqual(shown?.body, AnswerPipeline.notFoundMessage)
        XCTAssertEqual(gen.calls, 0)
    }

    func testAccentAndCaseInsensitiveMatching() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)
        try retriever.index(makeCorpus())

        let result = try await retriever.retrieve("QUAL E O OBJETIVO DO PROJETO?")

        XCTAssertNotNil(result.qaNote)
        XCTAssertEqual(result.qaNote?.source.path, "qa/apresentacao.md")
    }

    func testSpecialCharactersDoNotBreakQuery() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)
        try retriever.index(makeCorpus())

        let query = "retriever: como usar \"aspas\" e (parênteses) + asterisco*?"
        let result = try await retriever.retrieve(query)

        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.chunks.first?.source.path, "Teleprompter/Domain/AnswerPipeline.swift")
    }

    func testReindexAndRemoveSource() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)
        let corpus = makeCorpus()
        try retriever.index(corpus)

        var result = try await retriever.retrieve("A arquitetura adota pipeline linear?")
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.chunks.first?.source.path, "docs/ARCHITECTURE.md")

        try retriever.removeSource("docs/ARCHITECTURE.md")

        result = try await retriever.retrieve("A arquitetura adota pipeline linear?")
        XCTAssertTrue(result.isEmpty)

        let updatedItem = IndexedChunk(
            kind: .document,
            text: "A nova arquitetura adota pipeline linear moderno.",
            source: "docs/ARCHITECTURE.md"
        )
        try retriever.index([updatedItem])

        result = try await retriever.retrieve("A arquitetura adota pipeline linear?")
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.chunks.first?.text, "A nova arquitetura adota pipeline linear moderno.")
    }

    func testSourcesAlwaysPopulated() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)
        try retriever.index(makeCorpus())

        let qaResult = try await retriever.retrieve("Qual é o objetivo do projeto?")
        XCTAssertEqual(qaResult.qaNote?.source.path, "qa/apresentacao.md")

        let docResult = try await retriever.retrieve("escuta contínua e RAG fechado")
        for chunk in docResult.chunks {
            XCTAssertFalse(chunk.source.path.isEmpty)
        }
    }

    func testThresholdFiltering() async throws {
        let highThresholdRetriever = try LocalRetriever(
            databaseURL: databaseURL,
            qaThreshold: 0.99,
            chunkThreshold: 0.99
        )
        try highThresholdRetriever.index(makeCorpus())

        let result = try await highThresholdRetriever.retrieve("O que é o Teleprompter em Swift?")
        XCTAssertTrue(result.isEmpty)

        let defaultRetriever = try LocalRetriever(
            databaseURL: databaseURL,
            qaThreshold: 0.40,
            chunkThreshold: 0.25
        )
        let normalResult = try await defaultRetriever.retrieve("O que é o Teleprompter em Swift?")
        XCTAssertFalse(normalResult.isEmpty)
    }

    func testEmptyAndPunctuationOnlyQueries() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)
        try retriever.index(makeCorpus())

        let emptyResult = try await retriever.retrieve("")
        XCTAssertTrue(emptyResult.isEmpty)

        let whitespaceResult = try await retriever.retrieve("   \n\t  ")
        XCTAssertTrue(whitespaceResult.isEmpty)

        let punctuationResult = try await retriever.retrieve("??? :! ,.- \"\" ()")
        XCTAssertTrue(punctuationResult.isEmpty)
    }

    func testHybridSearchWithFakeEmbedder() async throws {
        let embedder = FakeEmbedder(dimension: 16)
        let retriever = try LocalRetriever(
            databaseURL: databaseURL,
            embedder: embedder
        )
        try retriever.index(makeCorpus())

        let result = try await retriever.retrieve("Qual é o objetivo do projeto?")
        XCTAssertNotNil(result.qaNote)
        XCTAssertEqual(result.qaNote?.source.path, "qa/apresentacao.md")
    }

    func testSerialConcurrencyWrites() async throws {
        let retriever = try LocalRetriever(databaseURL: databaseURL)

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<10 {
                group.addTask {
                    let chunk = IndexedChunk(
                        kind: .document,
                        text: "Texto concorrente \(index) com conteúdo indexado.",
                        source: "concorrente_\(index).md"
                    )
                    try? retriever.index([chunk])
                }
            }
        }

        let result = try await retriever.retrieve("Texto concorrente")
        XCTAssertFalse(result.isEmpty)
    }
}
