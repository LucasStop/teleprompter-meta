import XCTest
@testable import Teleprompter

@MainActor
final class ChatScreenStateTests: XCTestCase {
    private let sampleSource = SourceRef(path: "qa/stack.md")
    private let docSource = SourceRef(path: "README.md")

    private struct TestContext {
        let viewModel: ConversationViewModel
        let lens: SimulatedLens
        let generator: FakeGenerator
    }

    private func makeContext(
        retrieval: Retrieval = Retrieval(qaNote: nil, chunks: []),
        generator: FakeGenerator = FakeGenerator()
    ) -> TestContext {
        let lens = SimulatedLens()
        let retriever = FakeRetriever(result: retrieval)
        let transcriber = DummyTranscriber()
        let viewModel = ConversationViewModel(
            retriever: retriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber
        )
        return TestContext(viewModel: viewModel, lens: lens, generator: generator)
    }

    func testChatScreenStateVazio() {
        let context = makeContext()
        let state = ChatScreenState(from: context.viewModel, composerText: "")

        XCTAssertEqual(state.kind, .vazio)
        XCTAssertEqual(state.badge.title, "Pronto")
        XCTAssertEqual(state.badge.status, .pronto)
        XCTAssertNil(state.banner)
        XCTAssertTrue(state.showEmptyPlaceholder)
        XCTAssertFalse(state.isListening)
        XCTAssertEqual(state.composerPlaceholder, "Pergunte sobre o seu material")
        XCTAssertEqual(state.suggestionChips, [
            "Qual o problema que o app resolve?",
            "Como funciona a busca?"
        ])
    }

    func testChatScreenStateDigitando() {
        let context = makeContext()
        let state = ChatScreenState(from: context.viewModel, composerText: "Como funciona a busca")

        XCTAssertEqual(state.kind, .digitando)
        XCTAssertEqual(state.badge.title, "Pronto")
        XCTAssertEqual(state.badge.status, .pronto)
        XCTAssertNil(state.banner)
        XCTAssertTrue(state.showEmptyPlaceholder)
        XCTAssertFalse(state.isListening)
    }

    func testChatScreenStateEscutaSemMensagens() {
        let context = makeContext()
        context.viewModel.startListening()
        let state = ChatScreenState(from: context.viewModel, composerText: "")

        XCTAssertEqual(state.kind, .escuta)
        XCTAssertEqual(state.badge.title, "Ouvindo a banca")
        XCTAssertEqual(state.badge.status, .ativo)
        XCTAssertTrue(state.isListening)
        XCTAssertEqual(state.composerPlaceholder, "Ouvindo...")
        XCTAssertFalse(state.showEmptyPlaceholder)
        XCTAssertEqual(state.messages.count, 1)
        XCTAssertEqual(state.messages[0].role, .answer)
        XCTAssertTrue(state.messages[0].text.contains("Escuta contínua ligada"))
    }

    func testChatScreenStateEscutaComTranscricaoParcial() {
        let context = makeContext()
        context.viewModel.startListening()
        context.viewModel.currentTranscript = "Por que Swift nativo e não..."
        let state = ChatScreenState(from: context.viewModel)

        XCTAssertEqual(state.kind, .escuta)
        let lastMessage = try? XCTUnwrap(state.messages.last)
        XCTAssertEqual(lastMessage?.role, .partial)
        XCTAssertEqual(lastMessage?.text, "Por que Swift nativo e não...")
        XCTAssertEqual(lastMessage?.caption, "Pergunta parcial")
        XCTAssertTrue(lastMessage?.isPartial == true)
    }

    func testChatScreenStatePensando() {
        let context = makeContext()
        context.viewModel.state = .pensando
        context.viewModel.pendingQuestion = "Por que Swift nativo e não Flutter?"
        let state = ChatScreenState(from: context.viewModel)

        XCTAssertEqual(state.kind, .pensando)
        XCTAssertEqual(state.badge.title, "Buscando no material")
        XCTAssertEqual(state.badge.status, .ativo)
        XCTAssertEqual(state.messages.count, 2)
        XCTAssertEqual(state.messages[0].role, .question)
        XCTAssertEqual(state.messages[0].text, "Por que Swift nativo e não Flutter?")
        XCTAssertEqual(state.messages[1].role, .answer)
        XCTAssertTrue(state.messages[1].text.contains("Buscando no material"))
    }

    func testChatScreenStateConversaComFontesELatencia() async {
        let qaChunk = Chunk(
            text: "• DAT SDK só tem módulos Swift\n• Menor latência de áudio",
            source: sampleSource
        )
        let context = makeContext(retrieval: Retrieval(qaNote: qaChunk, chunks: []))

        await context.viewModel.ask("Por que Swift nativo e não Flutter?")
        let state = ChatScreenState(from: context.viewModel)

        XCTAssertEqual(state.kind, .conversa)
        XCTAssertEqual(state.badge.title, "Resposta enviada à lente")
        XCTAssertEqual(state.badge.status, .ok)
        XCTAssertEqual(state.messages.count, 2)

        let questionItem = state.messages[0]
        XCTAssertEqual(questionItem.role, .question)
        XCTAssertEqual(questionItem.text, "Por que Swift nativo e não Flutter?")

        let answerItem = state.messages[1]
        XCTAssertEqual(answerItem.role, .answer)
        XCTAssertEqual(answerItem.sources, ["qa/stack.md"])
        XCTAssertNotNil(answerItem.caption)
        XCTAssertTrue(answerItem.caption?.contains("nota de Q&A") == true)
        XCTAssertTrue(answerItem.caption?.contains("s") == true)
        XCTAssertFalse(answerItem.bullets.isEmpty)
    }

    func testChatScreenStateSemMaterialNaoChamaLLMEExibeMensagemFixa() async {
        let context = makeContext(retrieval: Retrieval(qaNote: nil, chunks: []))

        await context.viewModel.ask("Qual o orçamento do projeto?")
        let state = ChatScreenState(from: context.viewModel)

        XCTAssertEqual(state.kind, .semMaterial)
        XCTAssertEqual(state.badge.title, "Sem resposta no material")
        XCTAssertEqual(state.badge.status, .pronto)
        XCTAssertEqual(context.generator.calls, 0, "LLM não deve ser chamado quando nada é encontrado")

        let answerItem = try? XCTUnwrap(state.messages.last)
        XCTAssertEqual(answerItem?.role, .answer)
        XCTAssertEqual(answerItem?.text, AnswerPipeline.notFoundMessage)
        XCTAssertEqual(answerItem?.caption, "Nada acima do limiar de similaridade")
        XCTAssertTrue(answerItem?.sources.isEmpty == true)
    }

    func testChatScreenStateErro() {
        let context = makeContext()
        context.viewModel.state = .erro
        context.viewModel.errorMessage = "Falha de rede. Verifique a conexão e tente de novo."
        let state = ChatScreenState(from: context.viewModel)

        XCTAssertEqual(state.kind, .erro)
        XCTAssertEqual(state.badge.title, "Sem conexão")
        XCTAssertEqual(state.badge.status, .erro)
        XCTAssertNotNil(state.banner)
        XCTAssertEqual(state.banner?.title, "Sem conexão")
        XCTAssertEqual(state.banner?.style, .danger)
        XCTAssertTrue(state.banner?.message.contains("Falha de rede") == true)
    }

    func testChatScreenStateDesconectado() {
        let context = makeContext()
        context.viewModel.isGlassesConnected = false
        let state = ChatScreenState(from: context.viewModel)

        XCTAssertEqual(state.kind, .desconectado)
        XCTAssertEqual(state.badge.title, "Óculos desconectados")
        XCTAssertEqual(state.badge.status, .erro)
        XCTAssertNotNil(state.banner)
        XCTAssertEqual(state.banner?.title, "Óculos desconectados")
        XCTAssertEqual(state.banner?.message, "A resposta aparece só no iPhone. Reconecte pelo app Meta AI.")
        XCTAssertEqual(state.banner?.style, .warning)
    }

    func testEnviarTextoVazioNaoEnvia() async {
        let qaChunk = Chunk(text: "Conteúdo", source: sampleSource)
        let context = makeContext(retrieval: Retrieval(qaNote: qaChunk, chunks: []))

        await context.viewModel.ask("")
        await context.viewModel.ask("   \t  \n  ")
        XCTAssertTrue(context.viewModel.messages.isEmpty)
        XCTAssertEqual(context.generator.calls, 0)
        XCTAssertEqual(context.viewModel.state, .vazio)
    }

    func testAlternarEscutaMudaEstadoComoNoPrototipo() {
        let context = makeContext()
        XCTAssertFalse(context.viewModel.isListening)
        XCTAssertEqual(context.viewModel.state, .vazio)

        context.viewModel.toggleListening()
        XCTAssertTrue(context.viewModel.isListening)
        XCTAssertEqual(context.viewModel.state, .ouvindo)

        context.viewModel.toggleListening()
        XCTAssertFalse(context.viewModel.isListening)
        XCTAssertEqual(context.viewModel.state, .vazio)
    }

    func testLenteSimuladaAtualizadaAposPergunta() async {
        let qaChunk = Chunk(text: "DAT SDK só tem Swift", source: sampleSource)
        let context = makeContext(retrieval: Retrieval(qaNote: qaChunk, chunks: []))

        await context.viewModel.ask("Por que Swift?")
        XCTAssertNotNil(context.lens.content)
        XCTAssertEqual(context.lens.content?.question, "Por que Swift?")
        XCTAssertEqual(context.viewModel.lastLensContent?.question, "Por que Swift?")
    }
}

// MARK: - DummyTranscriber

private final class DummyTranscriber: SpeechTranscriber, @unchecked Sendable {
    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        AsyncStream { $0.finish() }
    }
}
