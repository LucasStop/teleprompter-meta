import SwiftUI
import XCTest
@testable import Teleprompter

@MainActor
final class ChatViewTests: XCTestCase {
    private func makeViewModel() -> (ConversationViewModel, SimulatedLens) {
        let lens = SimulatedLens()
        let retriever = FakeRetriever(result: Retrieval(qaNote: nil, chunks: []))
        let generator = FakeGenerator()
        let transcriber = DummyTranscriber()
        let viewModel = ConversationViewModel(
            retriever: retriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber
        )
        return (viewModel, lens)
    }

    func testChatViewRendersAllEightStatesWithoutCrashing() {
        let (viewModel, lens) = makeViewModel()

        // 1. Vazio
        let viewVazio = ChatView(viewModel: viewModel, lens: lens)
        XCTAssertNotNil(viewVazio.body)

        // 2. Digitando
        var viewDigitando = ChatView(viewModel: viewModel, lens: lens)
        viewDigitando.initialComposerText = "Digitando pergunta..."
        XCTAssertNotNil(viewDigitando.body)

        // 3. Escuta
        viewModel.startListening()
        let viewEscuta = ChatView(viewModel: viewModel, lens: lens)
        XCTAssertNotNil(viewEscuta.body)

        // 4. Pensando
        viewModel.stopListening()
        viewModel.state = .pensando
        viewModel.pendingQuestion = "Por que Swift?"
        let viewPensando = ChatView(viewModel: viewModel, lens: lens)
        XCTAssertNotNil(viewPensando.body)

        // 5. Conversa
        viewModel.state = .respondido
        viewModel.messages = [
            ChatMessage(
                question: "Por que Swift?",
                answer: "DAT SDK só tem módulos Swift",
                sources: [SourceRef(path: "qa/stack.md")],
                latency: LatencyReport(retrievalSeconds: 0.1, totalSeconds: 0.6)
            )
        ]
        let viewConversa = ChatView(viewModel: viewModel, lens: lens)
        XCTAssertNotNil(viewConversa.body)

        // 6. Sem material
        viewModel.state = .semMaterial
        viewModel.messages = [
            ChatMessage(
                question: "Qual o orçamento?",
                answer: AnswerPipeline.notFoundMessage,
                sources: [],
                latency: LatencyReport(retrievalSeconds: 0.1, totalSeconds: 0.2)
            )
        ]
        let viewSemMaterial = ChatView(viewModel: viewModel, lens: lens)
        XCTAssertNotNil(viewSemMaterial.body)

        // 7. Erro
        viewModel.state = .erro
        viewModel.errorMessage = "Falha de conexão"
        let viewErro = ChatView(viewModel: viewModel, lens: lens)
        XCTAssertNotNil(viewErro.body)

        // 8. Desconectado
        viewModel.state = .vazio
        viewModel.isGlassesConnected = false
        let viewDesconectado = ChatView(viewModel: viewModel, lens: lens)
        XCTAssertNotNil(viewDesconectado.body)
    }

    func testSimulatedLensModalRendersWithContent() {
        let content = LensContent(
            question: "Por que Swift?",
            body: "• DAT SDK só tem Swift",
            sources: [SourceRef(path: "qa/stack.md")]
        )
        let modal = SimulatedLensModalView(content: content)
        XCTAssertNotNil(modal.body)
    }

    func testSimulatedLensModalRendersWhenEmpty() {
        let modal = SimulatedLensModalView(content: nil)
        XCTAssertNotNil(modal.body)
    }
}

// MARK: - DummyTranscriber

private final class DummyTranscriber: SpeechTranscriber, @unchecked Sendable {
    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        AsyncStream { $0.finish() }
    }
}
