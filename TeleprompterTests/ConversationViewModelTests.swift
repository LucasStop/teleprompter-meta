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
}

private final class DummySpeechTranscriber: SpeechTranscriber, @unchecked Sendable {
    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        AsyncStream { $0.finish() }
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

private final class FailingGenerator: AnswerGenerator, @unchecked Sendable {
    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        AsyncStream { $0.finish() }
    }
}

// MARK: - ConversationViewModelTests

@MainActor
final class ConversationViewModelTests: XCTestCase {
    private let sampleSource = SourceRef(path: "docs/PRD.md")

    func testTextQuestionWithQANoteGoesDirectlyToLensWithoutLLM() async throws {
        let clock = TestClock()
        let lens = SimulatedLens()
        let qaChunk = Chunk(text: "DAT SDK só tem módulos Swift", source: sampleSource)
        let retriever = FakeRetriever(result: Retrieval(qaNote: qaChunk, chunks: []))
        let generator = FakeGenerator()
        let transcriber = DummySpeechTranscriber()

        let viewModel = ConversationViewModel(
            retriever: retriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            detector: PauseQuestionDetector(silenceThreshold: 1.2),
            clock: clock,
            format: .bullets
        )

        XCTAssertEqual(viewModel.state, .vazio)
        XCTAssertTrue(viewModel.messages.isEmpty)

        await viewModel.ask("Por que Swift nativo?")

        XCTAssertEqual(viewModel.state, .respondido)
        XCTAssertEqual(viewModel.messages.count, 1)

        let msg = viewModel.messages[0]
        XCTAssertEqual(msg.question, "Por que Swift nativo?")
        XCTAssertEqual(msg.pergunta, "Por que Swift nativo?")
        XCTAssertEqual(msg.answer, "DAT SDK só tem módulos Swift")
        XCTAssertEqual(msg.resposta, "DAT SDK só tem módulos Swift")
        XCTAssertEqual(msg.sources, [sampleSource])
        XCTAssertEqual(msg.fontes, [sampleSource])
        XCTAssertEqual(generator.calls, 0)

        XCTAssertNotNil(lens.content)
        XCTAssertEqual(lens.content?.question, "Por que Swift nativo?")
        XCTAssertTrue(lens.content?.body.contains("DAT SDK só tem módulos") == true)
        XCTAssertEqual(lens.content?.sources, [sampleSource])

        XCTAssertNotNil(viewModel.lastLatencyReport)
        XCTAssertNil(viewModel.lastLatencyReport?.firstToken)
        XCTAssertNil(viewModel.lastLatencyReport?.sttFinal)
        XCTAssertEqual(viewModel.messages[0].latency, viewModel.lastLatencyReport)
    }

    func testTextQuestionWithChunksCallsLLM() async throws {
        let clock = TestClock()
        let lens = SimulatedLens()
        let chunk = Chunk(text: "Contexto recuperado", source: sampleSource)
        let retriever = FakeRetriever(result: Retrieval(qaNote: nil, chunks: [chunk]))
        let generator = FakeGenerator()
        let transcriber = DummySpeechTranscriber()

        let viewModel = ConversationViewModel(
            retriever: retriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            clock: clock
        )

        await viewModel.ask("Como funciona a busca?")

        XCTAssertEqual(viewModel.state, .respondido)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(generator.calls, 1)
        XCTAssertEqual(viewModel.messages[0].answer, "resposta gerada")
        XCTAssertEqual(viewModel.messages[0].sources, [sampleSource])
        XCTAssertNotNil(lens.content)
        XCTAssertEqual(lens.content?.question, "Como funciona a busca?")
        XCTAssertNotNil(viewModel.lastLatencyReport?.retrieval)
    }

    func testNothingFoundDoesNotCallLLMAndSetsStateSemMaterial() async throws {
        let clock = TestClock()
        let lens = SimulatedLens()
        let retriever = FakeRetriever(result: Retrieval(qaNote: nil, chunks: []))
        let generator = FakeGenerator()
        let transcriber = DummySpeechTranscriber()

        let viewModel = ConversationViewModel(
            retriever: retriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            clock: clock
        )

        await viewModel.ask("Qual é o orçamento?")

        XCTAssertEqual(viewModel.state, .semMaterial)
        XCTAssertEqual(viewModel.messages.count, 1)
        XCTAssertEqual(generator.calls, 0)
        XCTAssertEqual(viewModel.messages[0].answer, AnswerPipeline.notFoundMessage)
        XCTAssertEqual(viewModel.messages[0].sources, [])
        XCTAssertTrue(lens.content?.body.contains("Não encontrei isso") == true)
        XCTAssertNil(viewModel.lastLatencyReport?.firstToken)
    }

    func testRetrieverErrorSetsStateErro() async throws {
        let clock = TestClock()
        let lens = SimulatedLens()
        let failingRetriever = FailingRetriever()
        let generator = FakeGenerator()
        let transcriber = DummySpeechTranscriber()

        let viewModel = ConversationViewModel(
            retriever: failingRetriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            clock: clock
        )

        await viewModel.ask("Pergunta que falha")

        XCTAssertEqual(viewModel.state, .erro)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Falha simulada") == true)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testGeneratorErrorSetsStateErro() async throws {
        let clock = TestClock()
        let lens = SimulatedLens()
        let chunk = Chunk(text: "Trecho", source: sampleSource)
        let retriever = FakeRetriever(result: Retrieval(qaNote: nil, chunks: [chunk]))
        let failingGen = FailingGenerator()
        let transcriber = DummySpeechTranscriber()

        let viewModel = ConversationViewModel(
            retriever: retriever,
            generator: failingGen,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            clock: clock
        )

        await viewModel.ask("Pergunta que causa erro no LLM")

        XCTAssertEqual(viewModel.state, .erro)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.messages.isEmpty)
    }

    func testInspectionExposesNoSpeechTextInLatencyReport() {
        let report = LatencyReport(
            sttFinal: .seconds(1.2),
            retrieval: .milliseconds(50),
            firstToken: .milliseconds(120),
            total: .seconds(1.5)
        )

        let mirror = Mirror(reflecting: report)
        for child in mirror.children {
            XCTAssertFalse(child.value is String, "LatencyReport não deve conter strings ou texto de fala")
        }
    }
}
