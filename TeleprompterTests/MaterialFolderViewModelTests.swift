import Foundation
import XCTest
@testable import Teleprompter

@MainActor
final class MaterialFolderViewModelTests: XCTestCase {
    private struct TestContext {
        let fakeIndex: FakeMaterialIndex
        let fakeFileSource: FakeFileSource
        let fakeScanner: FakeFolderScanner
        let viewModel: MaterialViewModel
    }

    private func makeContext() -> TestContext {
        let fakeIndex = FakeMaterialIndex()
        let fakeFileSource = FakeFileSource()
        let fakeScanner = FakeFolderScanner()
        let viewModel = MaterialViewModel(
            indexable: fakeIndex,
            fileSource: fakeFileSource,
            scanner: fakeScanner
        )
        return TestContext(
            fakeIndex: fakeIndex,
            fakeFileSource: fakeFileSource,
            fakeScanner: fakeScanner,
            viewModel: viewModel
        )
    }

    func testSelectFolderTransitionsToPastaConfirmar() async {
        let ctx = makeContext()
        let folderURL = URL(fileURLWithPath: "/workspace/teleprompter-meta")
        let file1 = ScannedFile(
            relativePath: "qa/p1.md",
            url: folderURL.appendingPathComponent("qa/p1.md"),
            kind: .qa,
            size: 200
        )
        let file2 = ScannedFile(
            relativePath: "docs/PRD.md",
            url: folderURL.appendingPathComponent("docs/PRD.md"),
            kind: .document,
            size: 500
        )
        let file3 = ScannedFile(
            relativePath: "src/App.swift",
            url: folderURL.appendingPathComponent("src/App.swift"),
            kind: .code,
            size: 1000
        )
        let ignored = [
            IgnoredFile(relativePath: ".git/index", reason: .ignoredDirectory),
            IgnoredFile(relativePath: "assets/logo.png", reason: .binary)
        ]

        ctx.fakeScanner.resultToReturn = FolderScanResult(
            folderName: "teleprompter-meta",
            folderURL: folderURL,
            validFiles: [file1, file2, file3],
            ignoredFiles: ignored
        )

        await ctx.viewModel.selectFolder(url: folderURL)

        XCTAssertEqual(ctx.viewModel.screenState.kind, .pastaConfirmar)
        let confirmation = try? XCTUnwrap(ctx.viewModel.screenState.folderConfirmation)
        XCTAssertEqual(confirmation?.folderName, "teleprompter-meta")
        XCTAssertEqual(confirmation?.validFilesCount, 3)
        XCTAssertEqual(confirmation?.qaCount, 1)
        XCTAssertEqual(confirmation?.documentCount, 1)
        XCTAssertEqual(confirmation?.codeCount, 1)
        XCTAssertEqual(confirmation?.ignoredGroups.count, 2)
    }

    func testConfirmFolderImportProgressAndConcluido() async throws {
        let ctx = makeContext()
        let folderURL = URL(fileURLWithPath: "/workspace/teleprompter-meta")
        let file1URL = folderURL.appendingPathComponent("qa/p1.md")
        let file2URL = folderURL.appendingPathComponent("docs/PRD.md")

        let file1 = ScannedFile(relativePath: "qa/p1.md", url: file1URL, kind: .qa, size: 200)
        let file2 = ScannedFile(relativePath: "docs/PRD.md", url: file2URL, kind: .document, size: 500)

        ctx.fakeFileSource.files[file1URL] = MaterialFileContent(name: "p1.md", text: "Pergunta: P1?\nResposta: R1.")
        ctx.fakeFileSource.files[file2URL] = MaterialFileContent(name: "PRD.md", text: "PRD Teleprompter Meta")

        let ignored = [IgnoredFile(relativePath: ".git/HEAD", reason: .ignoredDirectory)]

        ctx.fakeScanner.resultToReturn = FolderScanResult(
            folderName: "teleprompter-meta",
            folderURL: folderURL,
            validFiles: [file1, file2],
            ignoredFiles: ignored
        )

        await ctx.viewModel.selectFolder(url: folderURL)
        XCTAssertEqual(ctx.viewModel.screenState.kind, .pastaConfirmar)

        await ctx.viewModel.confirmFolderImport()

        XCTAssertEqual(ctx.viewModel.screenState.kind, .pastaConcluido)
        XCTAssertEqual(ctx.viewModel.screenState.badge?.status, .ok)
        XCTAssertEqual(ctx.viewModel.screenState.badge?.title, "2 arquivos indexados, 2 trechos")
        XCTAssertEqual(ctx.viewModel.sources.count, 2)
        XCTAssertEqual(ctx.viewModel.screenState.folderResultBanner?.ignoredCount, 1)
        XCTAssertEqual(ctx.fakeIndex.indexed.count, 2)
    }

    func testSelectFolderErrorTransitionsToPastaErro() async {
        let ctx = makeContext()
        let folderURL = URL(fileURLWithPath: "/workspace/sem_permissao")
        ctx.fakeScanner.simulatedError = FolderScannerError.unreadableFolder(
            name: "sem_permissao",
            reason: "Sem permissão de leitura."
        )

        await ctx.viewModel.selectFolder(url: folderURL)

        XCTAssertEqual(ctx.viewModel.screenState.kind, .pastaErro)
        XCTAssertNotNil(ctx.viewModel.screenState.banner)
        XCTAssertEqual(ctx.viewModel.screenState.banner?.style, .danger)
        XCTAssertTrue(ctx.viewModel.screenState.banner?.title.contains("sem_permissao") ?? false)
        XCTAssertEqual(ctx.viewModel.screenState.banner?.actionTitle, "Escolher a pasta de novo")
    }

    func testFolderReimportReplacesOldChunksWithoutDuplicating() async {
        let ctx = makeContext()
        let folderURL = URL(fileURLWithPath: "/workspace/repo")
        let fileURL = folderURL.appendingPathComponent("docs/PRD.md")
        let file = ScannedFile(relativePath: "docs/PRD.md", url: fileURL, kind: .document, size: 500)

        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(name: "PRD.md", text: "Versão 1 do PRD")
        ctx.fakeScanner.resultToReturn = FolderScanResult(
            folderName: "repo",
            folderURL: folderURL,
            validFiles: [file],
            ignoredFiles: []
        )

        await ctx.viewModel.selectFolder(url: folderURL)
        await ctx.viewModel.confirmFolderImport()
        XCTAssertEqual(ctx.fakeIndex.indexed.count, 1)
        XCTAssertEqual(ctx.fakeIndex.indexed.first?.text, "Versão 1 do PRD")

        // Reimporta com nova versão
        ctx.fakeFileSource.files[fileURL] = MaterialFileContent(name: "PRD.md", text: "Versão 2 do PRD")
        await ctx.viewModel.selectFolder(url: folderURL)
        await ctx.viewModel.confirmFolderImport()

        XCTAssertEqual(ctx.fakeIndex.indexed.count, 1, "Não deve duplicar os trechos ao reimportar pasta")
        XCTAssertEqual(ctx.fakeIndex.indexed.first?.text, "Versão 2 do PRD")
        XCTAssertTrue(ctx.fakeIndex.removedPaths.contains("docs/PRD.md"))
    }

    func testIndividualFileFailureDoesNotAbortOthers() async {
        let ctx = makeContext()
        let folderURL = URL(fileURLWithPath: "/workspace/repo")
        let goodURL = folderURL.appendingPathComponent("docs/bom.md")
        let badURL = folderURL.appendingPathComponent("docs/corrompido.md")

        let goodFile = ScannedFile(relativePath: "docs/bom.md", url: goodURL, kind: .document, size: 500)
        let badFile = ScannedFile(relativePath: "docs/corrompido.md", url: badURL, kind: .document, size: 500)

        ctx.fakeFileSource.files[goodURL] = MaterialFileContent(name: "bom.md", text: "Conteúdo bom")
        // badURL não existe no fakeFileSource, disparando erro de leitura

        ctx.fakeScanner.resultToReturn = FolderScanResult(
            folderName: "repo",
            folderURL: folderURL,
            validFiles: [goodFile, badFile],
            ignoredFiles: []
        )

        await ctx.viewModel.selectFolder(url: folderURL)
        await ctx.viewModel.confirmFolderImport()

        XCTAssertEqual(ctx.viewModel.screenState.kind, .pastaConcluido)
        XCTAssertEqual(ctx.fakeIndex.indexed.count, 1)
        XCTAssertEqual(ctx.fakeIndex.indexed.first?.text, "Conteúdo bom")
        XCTAssertEqual(ctx.viewModel.screenState.folderResultBanner?.ignoredCount, 1)
    }

    func testChooseAnotherFolderResetsState() async {
        let ctx = makeContext()
        let folderURL = URL(fileURLWithPath: "/workspace/repo")
        ctx.fakeScanner.simulatedError = FolderScannerError.unreadableFolder(name: "repo", reason: "Sem permissão.")

        await ctx.viewModel.selectFolder(url: folderURL)
        XCTAssertEqual(ctx.viewModel.screenState.kind, .pastaErro)

        ctx.viewModel.chooseAnotherFolder()
        XCTAssertNil(ctx.viewModel.activeFolderState)
        XCTAssertTrue(ctx.viewModel.isPickingFolder)
    }
}
