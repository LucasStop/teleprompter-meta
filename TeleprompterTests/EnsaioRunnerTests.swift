import Foundation
import XCTest
@testable import Teleprompter

final class EnsaioRunnerTests: XCTestCase {
    func testRunnerWithEmptyItemsReturnsEmptyReport() async throws {
        let fakeTranscriber = FakeSpeechTranscriber(hypotheses: [])
        let fakeRetriever = FakeRetriever(result: Retrieval(qaNote: nil, chunks: []))
        let fakeGenerator = FakeGenerator()
        let runner = EnsaioRunner(
            transcriber: fakeTranscriber,
            retriever: fakeRetriever,
            generator: fakeGenerator,
            formatter: PassthroughFormatter(),
            lens: RecordingLens(),
            audioSourceFactory: { _ in FakeAudioSource() }
        )

        let (summary, results) = try await runner.run(items: [])

        XCTAssertEqual(summary.totalQuestions, 0)
        XCTAssertEqual(summary.averageWER, 0.0)
        XCTAssertEqual(summary.averageLatencySeconds, 0.0)
        XCTAssertEqual(summary.p95LatencySeconds, 0.0)
        XCTAssertEqual(summary.medianLatencySeconds, 0.0)
        XCTAssertTrue(results.isEmpty)
    }

    func testRunnerExecutesQuestionsAndCalculatesWERAndStepLatencies() async throws {
        let runner = makeConfiguredRunner()
        let items = [
            EnsaioItem(id: "1", title: "Por que Swift nativo?", referenceText: "Por que Swift nativo?"),
            EnsaioItem(id: "2", title: "Como a busca funciona?", referenceText: "Como funciona a busca?")
        ]

        let progressBox = ProgressBox()
        let (summary, results) = try await runner.run(items: items) { progress in
            progressBox.append(progress)
        }

        XCTAssertEqual(progressBox.count, 2)
        XCTAssertEqual(results.count, 2)
        assertQANoteResult(results[0])
        assertLLMResult(results[1])

        XCTAssertEqual(summary.totalQuestions, 2)
        XCTAssertGreaterThanOrEqual(summary.averageWER, 0.0)
        XCTAssertGreaterThanOrEqual(summary.averageLatencySeconds, 0.0)
    }

    func testRunnerCancellationHaltsExecutionWithoutHanging() async throws {
        let fakeTranscriber = BlockingFakeSpeechTranscriber()
        let runner = EnsaioRunner(
            transcriber: fakeTranscriber,
            retriever: FakeRetriever(result: Retrieval(qaNote: nil, chunks: [])),
            generator: FakeGenerator(),
            formatter: PassthroughFormatter(),
            lens: RecordingLens(),
            audioSourceFactory: { _ in FakeAudioSource() }
        )

        let items = [
            EnsaioItem(id: "1", title: "Q1", referenceText: "Q1"),
            EnsaioItem(id: "2", title: "Q2", referenceText: "Q2"),
            EnsaioItem(id: "3", title: "Q3", referenceText: "Q3")
        ]

        let task = Task {
            try await runner.run(items: items)
        }

        try await Task.sleep(nanoseconds: 20_000_000)
        runner.cancel()
        task.cancel()

        do {
            let (summary, results) = try await task.value
            XCTAssertLessThan(results.count, 3)
            XCTAssertLessThanOrEqual(summary.totalQuestions, 2)
        } catch is CancellationError {
            // Expected cancellation
        }
    }

    func testRunnerReportsSpeechAssetNotInstalled() async {
        let fakeAssetManager = FakeSpeechAssetManager(
            supportedLocales: ["pt-BR"],
            installedLocales: []
        )
        let runner = EnsaioRunner(
            transcriber: FakeSpeechTranscriber(hypotheses: []),
            retriever: FakeRetriever(result: Retrieval(qaNote: nil, chunks: [])),
            generator: FakeGenerator(),
            formatter: PassthroughFormatter(),
            lens: RecordingLens(),
            speechAssetManager: fakeAssetManager,
            audioSourceFactory: { _ in FakeAudioSource() }
        )

        let readiness = await runner.checkSpeechReadiness()
        XCTAssertEqual(readiness, .assetNotInstalled(Locale(identifier: "pt-BR")))
    }

    func testRunnerCalculatesP95AndMedianLatencyDeterministically() {
        let latencies = [0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0]
        let results = latencies.enumerated().map { idx, sec in
            EnsaioQuestionResult(
                id: "\(idx)",
                referenceQuestion: "Pergunta \(idx)",
                transcribedText: "Pergunta \(idx)",
                wer: 0.1,
                answer: "Resposta",
                answerKind: .qaNote,
                latency: LatencyReport(
                    sttFinalSeconds: 0.1,
                    retrievalSeconds: 0.05,
                    firstTokenSeconds: nil,
                    totalSeconds: sec
                )
            )
        }

        let summary = EnsaioRunSummary(results: results)
        XCTAssertEqual(summary.totalQuestions, 10)
        XCTAssertEqual(summary.averageWER, 0.1, accuracy: 0.001)
        XCTAssertEqual(summary.averageLatencySeconds, 1.1, accuracy: 0.01)
        XCTAssertEqual(summary.medianLatencySeconds, 1.1, accuracy: 0.01)
        XCTAssertEqual(summary.p95LatencySeconds, 2.0, accuracy: 0.01)
    }

    func testRunnerHandlesNotFoundFallback() async throws {
        let fakeTranscriber = FakeSpeechTranscriber(hypotheses: ["Pergunta desconhecida"])
        let fakeRetriever = FakeRetriever(result: Retrieval(qaNote: nil, chunks: []))
        let fakeGenerator = FakeGenerator()

        let runner = EnsaioRunner(
            transcriber: fakeTranscriber,
            retriever: fakeRetriever,
            generator: fakeGenerator,
            formatter: PassthroughFormatter(),
            lens: RecordingLens(),
            audioSourceFactory: { _ in FakeAudioSource() }
        )

        let items = [
            EnsaioItem(id: "1", title: "Pergunta desconhecida", referenceText: "Pergunta desconhecida")
        ]

        let (_, results) = try await runner.run(items: items)
        XCTAssertEqual(results.count, 1)
        let first = results[0]
        XCTAssertEqual(first.answerKind, .notFound)
        XCTAssertEqual(first.answer, "Não encontrei isso no seu material.")
        XCTAssertEqual(fakeGenerator.calls, 0)
    }

    // MARK: - Test Helpers

    private func makeConfiguredRunner() -> EnsaioRunner {
        let fakeTranscriber = FakeSpeechTranscriber(hypotheses: [
            "por que swift nativo",
            "como a busca funciona"
        ])
        let qaChunk = Chunk(text: "DAT SDK nativo", source: SourceRef(path: "qa.md"))
        let fakeRetriever = ConfigurableFakeRetriever { question in
            if question.contains("swift") {
                return Retrieval(qaNote: qaChunk, chunks: [])
            } else {
                let docChunk = Chunk(text: "Busca híbrida BM25", source: SourceRef(path: "doc.md"))
                return Retrieval(qaNote: nil, chunks: [docChunk])
            }
        }
        let fakeGenerator = FakeGenerator()
        fakeGenerator.pieces = ["Resposta ", "sobre busca"]

        return EnsaioRunner(
            transcriber: fakeTranscriber,
            retriever: fakeRetriever,
            generator: fakeGenerator,
            formatter: PassthroughFormatter(),
            lens: RecordingLens(),
            audioSourceFactory: { _ in FakeAudioSource() }
        )
    }

    private func assertQANoteResult(_ item: EnsaioQuestionResult) {
        XCTAssertEqual(item.referenceQuestion, "Por que Swift nativo?")
        XCTAssertEqual(item.transcribedText, "por que swift nativo")
        XCTAssertEqual(item.wer, 0.0, accuracy: 0.001)
        XCTAssertEqual(item.answerKind, .qaNote)
        XCTAssertEqual(item.answer, "DAT SDK nativo")
        XCTAssertNotNil(item.latency.sttFinal)
        XCTAssertGreaterThanOrEqual(item.latency.retrievalSeconds, 0.0)
    }

    private func assertLLMResult(_ item: EnsaioQuestionResult) {
        XCTAssertEqual(item.referenceQuestion, "Como funciona a busca?")
        XCTAssertEqual(item.transcribedText, "como a busca funciona")
        XCTAssertGreaterThan(item.wer, 0.0)
        XCTAssertEqual(item.answerKind, .llm)
        XCTAssertEqual(item.answer, "Resposta sobre busca")
        XCTAssertNotNil(item.latency.firstToken)
    }
}

// MARK: - Test Doubles for Runner

private struct FakeAudioSource: AudioSource {
    func start() -> AsyncStream<AudioBuffer> {
        AsyncStream { continuation in
            continuation.yield(AudioBuffer(samples: [0.1, 0.2], sampleRate: 16000))
            continuation.finish()
        }
    }

    func stop() {}
}

private final class FakeSpeechTranscriber: SpeechTranscriber, @unchecked Sendable {
    private let lock = NSLock()
    private var hypotheses: [String]

    init(hypotheses: [String]) {
        self.hypotheses = hypotheses
    }

    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        let text = lock.withLock { () -> String in
            guard !hypotheses.isEmpty else { return "" }
            return hypotheses.removeFirst()
        }

        return AsyncStream { continuation in
            continuation.yield(Transcript(text: text, isFinal: true))
            continuation.finish()
        }
    }
}

private final class BlockingFakeSpeechTranscriber: SpeechTranscriber, @unchecked Sendable {
    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        AsyncStream { continuation in
            let task = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                continuation.yield(Transcript(text: "texto", isFinal: true))
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private struct ConfigurableFakeRetriever: Retriever {
    let handler: @Sendable (String) -> Retrieval

    func retrieve(_ question: String) async throws -> Retrieval {
        handler(question)
    }
}

private final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var updates: [EnsaioRunProgress] = []

    func append(_ update: EnsaioRunProgress) {
        lock.withLock { updates.append(update) }
    }

    var count: Int {
        lock.withLock { updates.count }
    }

    subscript(index: Int) -> EnsaioRunProgress {
        lock.withLock { updates[index] }
    }
}
