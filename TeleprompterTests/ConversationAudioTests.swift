import XCTest
@testable import Teleprompter

// MARK: - Test Doubles

private final class TestClock: Clock, @unchecked Sendable {
    private let lock = NSLock()
    private var currentInstant: ContinuousClock.Instant

    init(start: ContinuousClock.Instant = .now) {
        self.currentInstant = start
    }

    func now() -> ContinuousClock.Instant {
        lock.lock()
        defer { lock.unlock() }
        return currentInstant
    }

    func advance(by duration: Duration) {
        lock.lock()
        defer { lock.unlock() }
        currentInstant += duration
    }

    func advance(seconds: Double) {
        advance(by: .nanoseconds(Int64(seconds * 1_000_000_000)))
    }
}

private final class FakeSpeechTranscriber: SpeechTranscriber, @unchecked Sendable {
    var onTranscribe: (@Sendable (AsyncStream<AudioBuffer>) -> AsyncStream<Transcript>)?

    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        if let onTranscribe = onTranscribe {
            return onTranscribe(audio)
        }
        return AsyncStream { $0.finish() }
    }
}

private struct TimedFakeRetriever: Retriever {
    var result: Retrieval
    var delay: Duration
    var clock: TestClock

    func retrieve(_ question: String) async throws -> Retrieval {
        clock.advance(by: delay)
        return result
    }
}

private struct FailingRetriever: Retriever {
    enum TestError: Error, LocalizedError {
        case simulatedFailure
        var errorDescription: String? { "Falha simulada no banco de dados." }
    }

    func retrieve(_ question: String) async throws -> Retrieval {
        throw TestError.simulatedFailure
    }
}

private final class TimedFakeGenerator: AnswerGenerator, @unchecked Sendable {
    private(set) var calls = 0
    var firstTokenDelay: Duration = .zero
    var totalDelay: Duration = .zero
    var clock: TestClock?

    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        calls += 1
        let clock = clock
        let firstDelay = firstTokenDelay
        let totalDelay = totalDelay

        var hasYieldedFirst = false
        var hasYieldedSecond = false

        return AsyncStream(unfolding: {
            if !hasYieldedFirst {
                hasYieldedFirst = true
                clock?.advance(by: firstDelay)
                return "resposta "
            } else if !hasYieldedSecond {
                hasYieldedSecond = true
                clock?.advance(by: totalDelay)
                return "gerada"
            } else {
                return nil
            }
        })
    }
}

// MARK: - ConversationAudioTests

@MainActor
final class ConversationAudioTests: XCTestCase {
    private let sampleSource = SourceRef(path: "docs/PRD.md")

    private func sendTranscript(
        _ text: String,
        to continuation: AsyncStream<Transcript>.Continuation,
        viewModel: ConversationViewModel
    ) async {
        continuation.yield(Transcript(text: text, isFinal: false))
        while viewModel.currentTranscript != text {
            await Task.yield()
        }
    }

    func testAudioWithSyntheticPartialTranscriptsAndSilenceEmitsQuestionOnce() async throws {
        let clock = TestClock()
        let lens = SimulatedLens()
        let qaChunk = Chunk(text: "Arquitetura monolito com SwiftUI", source: sampleSource)
        let retriever = FakeRetriever(result: Retrieval(qaNote: qaChunk, chunks: []))
        let generator = FakeGenerator()
        let transcriber = FakeSpeechTranscriber()

        let (transcriptStream, transcriptContinuation) = AsyncStream<Transcript>.makeStream()
        transcriber.onTranscribe = { _ in transcriptStream }

        let viewModel = ConversationViewModel(
            retriever: retriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            detector: PauseQuestionDetector(silenceThreshold: 1.2),
            clock: clock
        )

        let (audioStream, audioContinuation) = AsyncStream<AudioBuffer>.makeStream()
        let listenTask = Task { await viewModel.listen(audioStream) }

        await sendTranscript("Qual é a", to: transcriptContinuation, viewModel: viewModel)
        clock.advance(seconds: 0.3)
        await sendTranscript("Qual é a arquitetura?", to: transcriptContinuation, viewModel: viewModel)

        clock.advance(seconds: 1.3)
        transcriptContinuation.yield(Transcript(text: "Qual é a arquitetura?", isFinal: false))
        while viewModel.messages.isEmpty {
            await Task.yield()
        }

        transcriptContinuation.finish()
        audioContinuation.finish()
        _ = await listenTask.result

        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(viewModel.messages[0].question, "Qual é a arquitetura?")
        XCTAssertEqual(viewModel.messages[0].answer, "Arquitetura monolito com SwiftUI")
        XCTAssertEqual(lens.content?.question, "Qual é a arquitetura?")
        XCTAssertNotNil(viewModel.lastLatencyReport?.sttFinal)
        XCTAssertEqual(generator.calls, 0)
    }

    func testTwoConsecutiveQuestionsFromAudioAreProcessedIndependently() async throws {
        let clock = TestClock()
        let lens = SimulatedLens()
        let qaChunk1 = Chunk(text: "Resposta 1", source: sampleSource)
        let qaChunk2 = Chunk(text: "Resposta 2", source: sampleSource)

        let (transcriptStream, transcriptContinuation) = AsyncStream<Transcript>.makeStream()
        let transcriber = FakeSpeechTranscriber()
        transcriber.onTranscribe = { _ in transcriptStream }

        struct MultiRetriever: Retriever {
            let chunk1: Chunk
            let chunk2: Chunk
            func retrieve(_ question: String) async throws -> Retrieval {
                question.contains("Primeira") ? Retrieval(qaNote: chunk1, chunks: []) : Retrieval(qaNote: chunk2, chunks: [])
            }
        }

        let viewModel = ConversationViewModel(
            retriever: MultiRetriever(chunk1: qaChunk1, chunk2: qaChunk2),
            generator: FakeGenerator(),
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            detector: PauseQuestionDetector(silenceThreshold: 1.2),
            clock: clock
        )

        let (audioStream, audioContinuation) = AsyncStream<AudioBuffer>.makeStream()
        let listenTask = Task { await viewModel.listen(audioStream) }

        await sendTranscript("Primeira pergunta?", to: transcriptContinuation, viewModel: viewModel)
        clock.advance(seconds: 1.3)
        transcriptContinuation.yield(Transcript(text: "Primeira pergunta?", isFinal: false))
        while viewModel.messages.count < 1 { await Task.yield() }

        clock.advance(seconds: 0.5)
        await sendTranscript("Segunda pergunta?", to: transcriptContinuation, viewModel: viewModel)
        clock.advance(seconds: 1.4)
        transcriptContinuation.yield(Transcript(text: "Segunda pergunta?", isFinal: false))
        while viewModel.messages.count < 2 { await Task.yield() }

        transcriptContinuation.finish()
        audioContinuation.finish()
        _ = await listenTask.result

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[0].question, "Primeira pergunta?")
        XCTAssertEqual(viewModel.messages[0].answer, "Resposta 1")
        XCTAssertEqual(viewModel.messages[1].question, "Segunda pergunta?")
        XCTAssertEqual(viewModel.messages[1].answer, "Resposta 2")
        XCTAssertEqual(lens.content?.question, "Segunda pergunta?")
    }

    func testLatencyReportByStepFilledWithTestClockValues() async throws {
        let clock = TestClock()
        let lens = SimulatedLens()
        let chunk = Chunk(text: "Trecho importante", source: sampleSource)
        let timedRetriever = TimedFakeRetriever(result: Retrieval(qaNote: nil, chunks: [chunk]), delay: .milliseconds(75), clock: clock)
        let timedGenerator = TimedFakeGenerator()
        timedGenerator.clock = clock
        timedGenerator.firstTokenDelay = .milliseconds(140)
        timedGenerator.totalDelay = .milliseconds(60)

        let transcriber = FakeSpeechTranscriber()
        let (transcriptStream, transcriptContinuation) = AsyncStream<Transcript>.makeStream()
        transcriber.onTranscribe = { _ in transcriptStream }

        let viewModel = ConversationViewModel(
            retriever: timedRetriever,
            generator: timedGenerator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            detector: PauseQuestionDetector(silenceThreshold: 1.2),
            clock: clock
        )

        let (audioStream, audioContinuation) = AsyncStream<AudioBuffer>.makeStream()
        let listenTask = Task { await viewModel.listen(audioStream) }

        await sendTranscript("Pergunta com latencia medida?", to: transcriptContinuation, viewModel: viewModel)
        clock.advance(seconds: 1.5)
        transcriptContinuation.yield(Transcript(text: "Pergunta com latencia medida?", isFinal: false))
        while viewModel.lastLatencyReport == nil { await Task.yield() }

        transcriptContinuation.finish()
        audioContinuation.finish()
        _ = await listenTask.result

        let report = try XCTUnwrap(viewModel.lastLatencyReport)
        XCTAssertEqual(report.sttFinal, Duration.seconds(1.5))
        XCTAssertEqual(report.retrieval, Duration.milliseconds(75))
        XCTAssertEqual(report.firstToken, Duration.milliseconds(140))
        XCTAssertEqual(report.total, Duration.milliseconds(275))
        XCTAssertEqual(report.retrievalSeconds, 0.075, accuracy: 0.001)
        XCTAssertEqual(report.totalSeconds, 0.275, accuracy: 0.001)
        XCTAssertEqual(report.sttFinalSeconds ?? 0, 1.5, accuracy: 0.001)
        XCTAssertEqual(viewModel.messages.last?.latency, report)
    }

    func testAudioRetrieverErrorSetsStateErroWithoutCrashingListening() async throws {
        let clock = TestClock()
        let lens = SimulatedLens()
        let failingRetriever = FailingRetriever()
        let generator = FakeGenerator()
        let transcriber = FakeSpeechTranscriber()

        let (transcriptStream, transcriptContinuation) = AsyncStream<Transcript>.makeStream()
        transcriber.onTranscribe = { _ in transcriptStream }

        let viewModel = ConversationViewModel(
            retriever: failingRetriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            detector: PauseQuestionDetector(silenceThreshold: 1.2),
            clock: clock
        )

        let (audioStream, audioContinuation) = AsyncStream<AudioBuffer>.makeStream()
        let listenTask = Task { await viewModel.listen(audioStream) }

        await sendTranscript("Pergunta com erro?", to: transcriptContinuation, viewModel: viewModel)
        clock.advance(seconds: 1.3)
        transcriptContinuation.yield(Transcript(text: "Pergunta com erro?", isFinal: false))
        while viewModel.state != .erro { await Task.yield() }

        transcriptContinuation.finish()
        audioContinuation.finish()
        _ = await listenTask.result

        XCTAssertEqual(viewModel.state, .erro)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Falha simulada") == true)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }
}
