import Foundation
import XCTest
@testable import Teleprompter

@MainActor
final class EnsaioViewModelTests: XCTestCase {
    func testInitialStateWithoutItemsIsVazio() async {
        let fakeItemSource = FakeEnsaioItemSource(items: [])
        let fakeRunner = FakeEnsaioRunner()
        let viewModel = EnsaioViewModel(
            runner: fakeRunner,
            itemSource: fakeItemSource
        )

        XCTAssertEqual(viewModel.screenState.kind, .vazio)
        await viewModel.loadItems()
        XCTAssertEqual(viewModel.screenState.kind, .vazio)
    }

    func testLoadItemsTransitionsStateToPadraoWhenItemsExist() async {
        let items = [
            EnsaioItem(id: "1", title: "Pergunta 1", referenceText: "Pergunta 1")
        ]
        let fakeItemSource = FakeEnsaioItemSource(items: items)
        let fakeRunner = FakeEnsaioRunner()
        let viewModel = EnsaioViewModel(
            runner: fakeRunner,
            itemSource: fakeItemSource
        )

        await viewModel.loadItems()
        XCTAssertEqual(viewModel.screenState.kind, .padrao)
        XCTAssertEqual(viewModel.items.count, 1)
    }

    func testStartRunTransitionsThroughRodandoToPadrao() async {
        let items = [
            EnsaioItem(id: "1", title: "Pergunta 1", referenceText: "Pergunta 1")
        ]
        let fakeItemSource = FakeEnsaioItemSource(items: items)
        let fakeRunner = FakeEnsaioRunner()
        let viewModel = EnsaioViewModel(
            runner: fakeRunner,
            itemSource: fakeItemSource
        )

        await viewModel.loadItems()
        await viewModel.startRun()

        XCTAssertEqual(viewModel.screenState.kind, .padrao)
        XCTAssertEqual(viewModel.screenState.questions.count, 1)
        XCTAssertEqual(viewModel.screenState.summary?.totalQuestions, 1)
    }

    func testCancelRunInterruptsExecutionGracefully() async throws {
        let items = [
            EnsaioItem(id: "1", title: "P1", referenceText: "P1"),
            EnsaioItem(id: "2", title: "P2", referenceText: "P2")
        ]
        let fakeItemSource = FakeEnsaioItemSource(items: items)
        let fakeRunner = HangingFakeEnsaioRunner()
        let viewModel = EnsaioViewModel(
            runner: fakeRunner,
            itemSource: fakeItemSource
        )

        await viewModel.loadItems()

        let runTask = Task { @MainActor in
            await viewModel.startRun()
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertEqual(viewModel.screenState.kind, .rodando)

        viewModel.cancelRun()
        _ = await runTask.result

        XCTAssertNotEqual(viewModel.screenState.kind, .rodando)
    }

    func testMissingSpeechAssetTransitionsToErroStateWithInstruction() async {
        let items = [
            EnsaioItem(id: "1", title: "P1", referenceText: "P1")
        ]
        let fakeAssetManager = FakeSpeechAssetManager(
            supportedLocales: ["pt-BR"],
            installedLocales: []
        )
        let fakeItemSource = FakeEnsaioItemSource(items: items)
        let fakeRunner = FakeEnsaioRunner(speechReadiness: .assetNotInstalled(Locale(identifier: "pt-BR")))
        let viewModel = EnsaioViewModel(
            runner: fakeRunner,
            itemSource: fakeItemSource,
            speechAssetManager: fakeAssetManager
        )

        await viewModel.loadItems()
        await viewModel.startRun()

        XCTAssertEqual(viewModel.screenState.kind, .erro)
        XCTAssertEqual(viewModel.screenState.error?.actionTitle, "Instalar modelo")
        XCTAssertTrue(viewModel.screenState.error?.message.contains("não está instalado") == true)
    }

    func testInstallSpeechAssetCallsManagerAndRecovers() async {
        let items = [
            EnsaioItem(id: "1", title: "P1", referenceText: "P1")
        ]
        let fakeAssetManager = FakeSpeechAssetManager(
            supportedLocales: ["pt-BR"],
            installedLocales: []
        )
        let fakeItemSource = FakeEnsaioItemSource(items: items)
        let fakeRunner = FakeEnsaioRunner(speechReadiness: .assetNotInstalled(Locale(identifier: "pt-BR")))
        let viewModel = EnsaioViewModel(
            runner: fakeRunner,
            itemSource: fakeItemSource,
            speechAssetManager: fakeAssetManager
        )

        await viewModel.loadItems()
        await viewModel.startRun()
        XCTAssertEqual(viewModel.screenState.kind, .erro)

        fakeRunner.speechReadiness = .ready
        await viewModel.installSpeechAsset()

        XCTAssertEqual(fakeAssetManager.installCallCount, 1)
        XCTAssertEqual(viewModel.screenState.kind, .padrao)
    }

    func testQuestionItemMarksSlowWhenLatencyExceedsThreshold() {
        let normalResult = EnsaioQuestionResult(
            referenceQuestion: "Pergunta Rápida",
            transcribedText: "Pergunta Rápida",
            wer: 0.05,
            answer: "Resposta",
            answerKind: .qaNote,
            latency: LatencyReport(
                retrievalSeconds: 0.1,
                firstTokenSeconds: 0.6,
                totalSeconds: 0.6
            )
        )
        XCTAssertTrue(normalResult.isOk)

        let slowResult = EnsaioQuestionResult(
            referenceQuestion: "Pergunta Lenta",
            transcribedText: "Pergunta Lenta",
            wer: 0.05,
            answer: "Resposta",
            answerKind: .llm,
            latency: LatencyReport(
                retrievalSeconds: 0.1,
                firstTokenSeconds: 2.4,
                totalSeconds: 2.5
            )
        )
        XCTAssertFalse(slowResult.isOk)

        let highWERResult = EnsaioQuestionResult(
            referenceQuestion: "Pergunta com WER alto",
            transcribedText: "Pergunta errada completamente",
            wer: 0.25,
            answer: "Resposta",
            answerKind: .qaNote,
            latency: LatencyReport(
                retrievalSeconds: 0.1,
                firstTokenSeconds: 0.5,
                totalSeconds: 0.5
            )
        )
        XCTAssertFalse(highWERResult.isOk)
    }

    func testDocumentDirectoryItemSourceLoadsItemsAlphabetically() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let wav2 = tempDir.appendingPathComponent("02.wav")
        let txt2 = tempDir.appendingPathComponent("02.txt")
        let wav1 = tempDir.appendingPathComponent("01.wav")
        let txt1 = tempDir.appendingPathComponent("01.txt")

        try Data().write(to: wav2)
        try "Pergunta 2".write(to: txt2, atomically: true, encoding: .utf8)
        try Data().write(to: wav1)
        try "Pergunta 1".write(to: txt1, atomically: true, encoding: .utf8)

        let source = DocumentDirectoryEnsaioItemSource(directoryURL: tempDir)
        let loaded = try await source.loadItems()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, "01")
        XCTAssertEqual(loaded[0].referenceText, "Pergunta 1")
        XCTAssertEqual(loaded[1].id, "02")
        XCTAssertEqual(loaded[1].referenceText, "Pergunta 2")
    }
}

// MARK: - Test Doubles for ViewModel

private final class FakeEnsaioItemSource: EnsaioItemSource, @unchecked Sendable {
    var items: [EnsaioItem]

    init(items: [EnsaioItem]) {
        self.items = items
    }

    func loadItems() async throws -> [EnsaioItem] {
        items
    }
}

private final class FakeEnsaioRunner: EnsaioRunning, @unchecked Sendable {
    var speechReadiness: SpeechReadiness
    var resultsToReturn: [EnsaioQuestionResult]

    init(
        speechReadiness: SpeechReadiness = .ready,
        results: [EnsaioQuestionResult]? = nil
    ) {
        self.speechReadiness = speechReadiness
        self.resultsToReturn = results ?? [
            EnsaioQuestionResult(
                id: "1",
                referenceQuestion: "Pergunta 1",
                transcribedText: "Pergunta 1",
                wer: 0.05,
                answer: "Resposta 1",
                answerKind: .qaNote,
                latency: LatencyReport(
                    retrievalSeconds: 0.1,
                    firstTokenSeconds: 0.5,
                    totalSeconds: 0.6
                )
            )
        ]
    }

    func checkSpeechReadiness() async -> SpeechReadiness {
        speechReadiness
    }

    func run(
        items: [EnsaioItem],
        onProgress: (@Sendable (EnsaioRunProgress) -> Void)?
    ) async throws -> (summary: EnsaioRunSummary, results: [EnsaioQuestionResult]) {
        for (index, item) in items.enumerated() {
            onProgress?(EnsaioRunProgress(
                currentIndex: index + 1,
                totalCount: items.count,
                currentQuestionTitle: item.title,
                fractionCompleted: Double(index + 1) / Double(items.count)
            ))
        }
        let summary = EnsaioRunSummary(results: resultsToReturn)
        return (summary, resultsToReturn)
    }

    func cancel() {}
}

private final class HangingFakeEnsaioRunner: EnsaioRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false

    func checkSpeechReadiness() async -> SpeechReadiness {
        .ready
    }

    func run(
        items: [EnsaioItem],
        onProgress: (@Sendable (EnsaioRunProgress) -> Void)?
    ) async throws -> (summary: EnsaioRunSummary, results: [EnsaioQuestionResult]) {
        onProgress?(EnsaioRunProgress(
            currentIndex: 1,
            totalCount: items.count,
            currentQuestionTitle: items.first?.title ?? "",
            fractionCompleted: 0.5
        ))

        while !Task.isCancelled {
            let cancelled = lock.withLock { isCancelled }
            if cancelled { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        if Task.isCancelled || lock.withLock({ isCancelled }) {
            throw CancellationError()
        }
        return (EnsaioRunSummary(results: []), [])
    }

    func cancel() {
        lock.withLock { isCancelled = true }
    }
}
