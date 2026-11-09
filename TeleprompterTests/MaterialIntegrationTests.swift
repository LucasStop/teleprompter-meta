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

    func testFolderImportIndexesMultipleFilesAndLocalRetrieverFindsChunks() async throws {
        let ctx = try makeContext()
        defer { ctx.cleanup() }

        let folderURL = ctx.tempDirectory.appendingPathComponent("ProjetoMaterial", isDirectory: true)
        let qaDir = folderURL.appendingPathComponent("qa", isDirectory: true)
        let docsDir = folderURL.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: qaDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)

        let file1URL = qaDir.appendingPathComponent("apresentacao.md")
        let file2URL = docsDir.appendingPathComponent("arquitetura.md")
        let file3URL = folderURL.appendingPathComponent("README.md")

        let qaText = """
        Pergunta: Qual é o formato da lente do Ray-Ban?
        Resposta: A lente tem resolução de 600 por 600 pixels e suporta até 5 linhas de texto.
        """
        let docText = """
        # Arquitetura do Teleprompter
        O sistema utiliza busca em SQLite FTS5 com ranking BM25 e chunking inteligente de parágrafos.
        """
        let readmeText = """
        # Teleprompter Meta
        Aplicativo iOS pessoal para suporte ao apresentador durante a banca de mestrado.
        """

        try qaText.write(to: file1URL, atomically: true, encoding: .utf8)
        try docText.write(to: file2URL, atomically: true, encoding: .utf8)
        try readmeText.write(to: file3URL, atomically: true, encoding: .utf8)

        let folderScanner = DefaultFolderScanner()
        let realFileSource = DefaultMaterialFileSource()
        let viewModel = MaterialViewModel(
            indexable: ctx.retriever,
            fileSource: realFileSource,
            scanner: folderScanner
        )

        await viewModel.selectFolder(url: folderURL)
        XCTAssertEqual(viewModel.screenState.kind, .pastaConfirmar)
        XCTAssertEqual(viewModel.screenState.folderConfirmation?.validFilesCount, 3)

        await viewModel.confirmFolderImport()
        XCTAssertEqual(viewModel.screenState.kind, .pastaConcluido)

        let qaResult = try await ctx.retriever.retrieve("formato da lente Ray-Ban")
        XCTAssertNotNil(qaResult.qaNote)
        XCTAssertTrue(qaResult.qaNote?.text.contains("600 por 600 pixels") ?? false)

        let docResult = try await ctx.retriever.retrieve("ranking BM25 SQLite FTS5")
        XCTAssertFalse(docResult.chunks.isEmpty)
        XCTAssertEqual(docResult.chunks.first?.source.path, "docs/arquitetura.md")
        XCTAssertTrue(docResult.chunks.first?.text.contains("ranking BM25") ?? false)

        let readmeResult = try await ctx.retriever.retrieve("banca de mestrado apresentador")
        XCTAssertFalse(readmeResult.chunks.isEmpty)
        XCTAssertEqual(readmeResult.chunks.first?.source.path, "README.md")
    }
}
