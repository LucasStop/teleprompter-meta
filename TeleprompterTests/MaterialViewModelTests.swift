import Foundation
import XCTest
@testable import Teleprompter

@MainActor
final class MaterialViewModelTests: XCTestCase {
    private struct TestContext {
        let fakeIndex: FakeMaterialIndex
        let fakeFileSource: FakeFileSource
        let viewModel: MaterialViewModel
    }

    private func makeContext() -> TestContext {
        let fakeIndex = FakeMaterialIndex()
        let fakeFileSource = FakeFileSource()
        let viewModel = MaterialViewModel(
            indexable: fakeIndex,
            fileSource: fakeFileSource
        )
        return TestContext(
            fakeIndex: fakeIndex,
            fakeFileSource: fakeFileSource,
            viewModel: viewModel
        )
    }

    func testInitialStateIsVazio() {
        let ctx = makeContext()
        XCTAssertEqual(ctx.viewModel.screenState.kind, .vazio)
        XCTAssertTrue(ctx.viewModel.sources.isEmpty)
        XCTAssertNil(ctx.viewModel.screenState.badge)
        XCTAssertNil(ctx.viewModel.screenState.banner)
    }

    func testImportValidFileTransitionsToPadrao() async {
        let ctx = makeContext()
        let fileURL = URL(fileURLWithPath: "/tmp/README.md")
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(
            name: "README.md",
            text: "# Teleprompter Meta\nApp para respostas rápidas na lente do Ray-Ban."
        )

        await ctx.viewModel.importFile(from: fileURL)

        XCTAssertEqual(ctx.viewModel.screenState.kind, .padrao)
        XCTAssertEqual(ctx.viewModel.sources.count, 1)
        XCTAssertEqual(ctx.viewModel.sources.first?.name, "README.md")
        XCTAssertEqual(ctx.viewModel.sources.first?.chunkCount, 1)
        XCTAssertEqual(ctx.viewModel.sources.first?.displayCount, "1 trecho")
        XCTAssertNotNil(ctx.viewModel.screenState.badge)
        XCTAssertEqual(ctx.viewModel.screenState.badge?.status, .ok)
        XCTAssertEqual(ctx.fakeIndex.indexed.count, 1)
    }

    func testReimportingSameSourceReplacesOldChunksWithoutDuplicating() async {
        let ctx = makeContext()
        let fileURL = URL(fileURLWithPath: "/tmp/README.md")
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(
            name: "README.md",
            text: "# Versão 1\nPrimeiro conteúdo importado."
        )

        await ctx.viewModel.importFile(from: fileURL)
        XCTAssertEqual(ctx.viewModel.sources.count, 1)
        XCTAssertEqual(ctx.fakeIndex.indexed.count, 1)
        XCTAssertEqual(ctx.fakeIndex.indexed.first?.text, "# Versão 1\nPrimeiro conteúdo importado.")

        // Reimporta com conteúdo atualizado
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(
            name: "README.md",
            text: "# Versão 2\nNovo conteúdo atualizado após correções."
        )

        await ctx.viewModel.importFile(from: fileURL)

        XCTAssertEqual(ctx.viewModel.sources.count, 1, "Não deve duplicar a entrada na lista de fontes")
        XCTAssertEqual(ctx.fakeIndex.indexed.count, 1, "Não deve duplicar os trechos no índice")
        XCTAssertEqual(ctx.fakeIndex.indexed.first?.text, "# Versão 2\nNovo conteúdo atualizado após correções.")
        XCTAssertTrue(ctx.fakeIndex.removedPaths.contains("README.md"))
    }

    func testRemoveSourceUpdatesListAndReturnsToVazioWhenEmpty() async throws {
        let ctx = makeContext()
        let fileURL = URL(fileURLWithPath: "/tmp/documento.md")
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(
            name: "documento.md",
            text: "Conteúdo temporário."
        )
        await ctx.viewModel.importFile(from: fileURL)
        XCTAssertEqual(ctx.viewModel.screenState.kind, .padrao)

        let source = try XCTUnwrap(ctx.viewModel.sources.first)
        await ctx.viewModel.removeSource(source)

        XCTAssertEqual(ctx.viewModel.screenState.kind, .vazio)
        XCTAssertTrue(ctx.viewModel.sources.isEmpty)
        XCTAssertTrue(ctx.fakeIndex.indexed.isEmpty)
    }

    func testClearIndexRemovesAllSourcesAndRevertsToVazio() async {
        let ctx = makeContext()
        let file1 = URL(fileURLWithPath: "/tmp/doc1.md")
        let file2 = URL(fileURLWithPath: "/tmp/doc2.md")
        ctx.fakeFileSource.files[file1] = MaterialFileContent(name: "doc1.md", text: "Texto 1")
        ctx.fakeFileSource.files[file2] = MaterialFileContent(name: "doc2.md", text: "Texto 2")

        await ctx.viewModel.importFile(from: file1)
        await ctx.viewModel.importFile(from: file2)
        XCTAssertEqual(ctx.viewModel.sources.count, 2)
        XCTAssertEqual(ctx.fakeIndex.indexed.count, 2)

        await ctx.viewModel.clearIndex()

        XCTAssertEqual(ctx.viewModel.screenState.kind, .vazio)
        XCTAssertTrue(ctx.viewModel.sources.isEmpty)
        XCTAssertTrue(ctx.fakeIndex.indexed.isEmpty)
    }

    func testEmptyFileSetsErrorStateWithActionableBanner() async {
        let ctx = makeContext()
        let emptyURL = URL(fileURLWithPath: "/tmp/vazio.txt")
        ctx.fakeFileSource.files[emptyURL] = MaterialFileContent(name: "vazio.txt", text: "   \n")

        await ctx.viewModel.importFile(from: emptyURL)

        XCTAssertEqual(ctx.viewModel.screenState.kind, .erro)
        XCTAssertNotNil(ctx.viewModel.screenState.banner)
        XCTAssertEqual(ctx.viewModel.screenState.banner?.style, .danger)
        XCTAssertTrue(ctx.viewModel.screenState.banner?.title.contains("vazio.txt") ?? false)
        XCTAssertEqual(ctx.viewModel.screenState.banner?.actionTitle, "Tentar de novo")
    }

    func testUnreadableFileSetsErrorState() async {
        let ctx = makeContext()
        let unreadableURL = URL(fileURLWithPath: "/tmp/invalido.bin")
        ctx.fakeFileSource.simulatedError = MaterialImporterError.unreadableFile(
            "invalido.bin",
            reason: "Arquivo sem permissão de leitura."
        )

        await ctx.viewModel.importFile(from: unreadableURL)

        XCTAssertEqual(ctx.viewModel.screenState.kind, .erro)
        XCTAssertNotNil(ctx.viewModel.screenState.banner)
        XCTAssertTrue(ctx.viewModel.screenState.banner?.message.contains("sem permissão de leitura") ?? false)
    }

    func testRetryAfterFixingFileRestoresSuccess() async {
        let ctx = makeContext()
        let fileURL = URL(fileURLWithPath: "/tmp/recuperavel.md")
        ctx.fakeFileSource.simulatedError = MaterialImporterError.unreadableFile(
            "recuperavel.md",
            reason: "Erro de permissão."
        )

        await ctx.viewModel.importFile(from: fileURL)
        XCTAssertEqual(ctx.viewModel.screenState.kind, .erro)

        ctx.fakeFileSource.simulatedError = nil
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(name: "recuperavel.md", text: "Conteúdo corrigido.")

        await ctx.viewModel.retryLast()

        XCTAssertEqual(ctx.viewModel.screenState.kind, .padrao)
        XCTAssertNil(ctx.viewModel.screenState.banner)
        XCTAssertEqual(ctx.viewModel.sources.count, 1)
    }
}
