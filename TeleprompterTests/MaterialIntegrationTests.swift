import Foundation
import XCTest
@testable import Teleprompter

@MainActor
final class MaterialIntegrationTests: XCTestCase {
    private struct TestContext {
        let tempDirectory: URL
        let databaseURL: URL
        let retriever: LocalRetriever
        let fakeFileSource: FakeFileSource
        let viewModel: MaterialViewModel

        func cleanup() {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    private func makeContext() throws -> TestContext {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MaterialIntegrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbURL = tempDir.appendingPathComponent("test_material.sqlite3")

        let retriever = try LocalRetriever(databaseURL: dbURL)
        let fakeFileSource = FakeFileSource()
        let viewModel = MaterialViewModel(
            indexable: retriever,
            fileSource: fakeFileSource
        )
        return TestContext(
            tempDirectory: tempDir,
            databaseURL: dbURL,
            retriever: retriever,
            fakeFileSource: fakeFileSource,
            viewModel: viewModel
        )
    }

    func testImportMarkdownFileBecomesSearchableInRetriever() async throws {
        let ctx = try makeContext()
        defer { ctx.cleanup() }

        let fileURL = ctx.tempDirectory.appendingPathComponent("README.md")
        let content = """
        # Visão Geral da Arquitetura
        O Teleprompter Meta é construído em Swift nativo para garantir latência mínima de áudio. \
        O sistema opera em modo RAG estritamente fechado para a defesa de mestrado.
        """
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(name: "README.md", text: content)

        await ctx.viewModel.importFile(from: fileURL)
        XCTAssertEqual(ctx.viewModel.screenState.kind, .padrao)

        let result = try await ctx.retriever.retrieve("Como funciona o RAG no Teleprompter?")
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.chunks.first?.source.path, "README.md")
        XCTAssertTrue(result.chunks.first?.text.contains("RAG estritamente fechado") ?? false)
    }

    func testImportQANoteReturnsDirectAnswerWithoutLLM() async throws {
        let ctx = try makeContext()
        defer { ctx.cleanup() }

        let fileURL = ctx.tempDirectory.appendingPathComponent("qa_apresentacao.md")
        let content = """
        P: Qual é o objetivo principal do Teleprompter?
        R: Auxiliar o apresentador com respostas curtas e precisas na lente do Ray-Ban Display.
        """
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(name: "qa_apresentacao.md", text: content)

        await ctx.viewModel.importFile(from: fileURL)

        let result = try await ctx.retriever.retrieve("Qual é o objetivo principal do Teleprompter?")
        XCTAssertNotNil(result.qaNote)
        XCTAssertEqual(
            result.qaNote?.text,
            "Auxiliar o apresentador com respostas curtas e precisas na lente do Ray-Ban Display."
        )
        XCTAssertEqual(result.qaNote?.source.path, "qa_apresentacao.md")
        XCTAssertTrue(result.chunks.isEmpty)
    }

    func testImportCodeFileBecomesSearchable() async throws {
        let ctx = try makeContext()
        defer { ctx.cleanup() }

        let fileURL = ctx.tempDirectory.appendingPathComponent("AnswerPipeline.swift")
        let content = """
        import Foundation

        final class AnswerPipeline {
            func processQuestion(_ question: String) async throws -> String {
                let retrieval = try await retriever.retrieve(question)
                return retrieval.qaNote?.text ?? "Sem resposta"
            }
        }
        """
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(name: "AnswerPipeline.swift", text: content)

        await ctx.viewModel.importFile(from: fileURL)

        let result = try await ctx.retriever.retrieve("processQuestion retrieval retriever")
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.chunks.first?.source.path, "AnswerPipeline.swift")
    }

    func testReimportingReplacesOldContentWithoutDuplication() async throws {
        let ctx = try makeContext()
        defer { ctx.cleanup() }

        let fileURL = ctx.tempDirectory.appendingPathComponent("notas.md")
        let v1Content = "Versão antiga da metodologia com algoritmo alfa experimental."
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(name: "notas.md", text: v1Content)

        await ctx.viewModel.importFile(from: fileURL)

        var result = try await ctx.retriever.retrieve("algoritmo alfa")
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.chunks.first?.text.contains("algoritmo alfa experimental") ?? false)

        // Reimporta versão 2 substituindo o conteúdo
        let v2Content = "Versão nova da metodologia com algoritmo beta definitivo e otimizado."
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(name: "notas.md", text: v2Content)

        await ctx.viewModel.importFile(from: fileURL)

        result = try await ctx.retriever.retrieve("algoritmo")
        XCTAssertEqual(result.chunks.count, 1, "Deve haver apenas um trecho indexado para esta fonte")
        XCTAssertTrue(result.chunks.first?.text.contains("algoritmo beta definitivo") ?? false)

        let oldResult = try await ctx.retriever.retrieve("alfa experimental")
        XCTAssertTrue(oldResult.isEmpty, "Conteúdo antigo não deve mais existir no índice")
    }

    func testRemoveSourceClearsIndexedChunksFromSearch() async throws {
        let ctx = try makeContext()
        defer { ctx.cleanup() }

        let fileURL = ctx.tempDirectory.appendingPathComponent("descartavel.md")
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(
            name: "descartavel.md",
            text: "Informações temporárias sobre o ensaio preliminar da apresentação."
        )

        await ctx.viewModel.importFile(from: fileURL)

        var result = try await ctx.retriever.retrieve("ensaio preliminar")
        XCTAssertFalse(result.isEmpty)

        let source = try XCTUnwrap(ctx.viewModel.sources.first)
        await ctx.viewModel.removeSource(source)

        result = try await ctx.retriever.retrieve("ensaio preliminar")
        XCTAssertTrue(result.isEmpty, "Trecho removido não deve mais ser encontrado na busca")
    }
}
