import SwiftUI

// MARK: - Previews para os 8 Estados (Claro e Escuro)

#Preview("T02 - 1. Vazio (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .vazio),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 1. Vazio (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .vazio),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 2. Digitando (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .vazio),
        lens: SimulatedLens(),
        initialComposerText: "Como funciona a busca no material?"
    )
}

#Preview("T02 - 2. Digitando (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .vazio),
        lens: SimulatedLens(),
        initialComposerText: "Como funciona a busca no material?"
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 3. Escuta (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .escuta),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 3. Escuta (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .escuta),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 4. Pensando (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .pensando),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 4. Pensando (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .pensando),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 5a. Conversa (Fontes Fechadas, com Citação) (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .conversa, fontesAbertas: false, comCitacao: true),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 5a. Conversa (Fontes Fechadas, com Citação) (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .conversa, fontesAbertas: false, comCitacao: true),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 5b. Fontes Abertas (com Citação) (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .conversa, fontesAbertas: true, comCitacao: true),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 5b. Fontes Abertas (com Citação) (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .conversa, fontesAbertas: true, comCitacao: true),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 5c. Conversa Sem Citação (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .conversa, fontesAbertas: false, comCitacao: false),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 5c. Conversa Sem Citação (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .conversa, fontesAbertas: false, comCitacao: false),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 6. Sem Material (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .semMaterial),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 6. Sem Material (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .semMaterial),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 7. Erro (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .erro),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 7. Erro (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .erro),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 8. Desconectado (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .desconectado),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 8. Desconectado (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .desconectado),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

#Preview("T02 - 9. Vazio Sem Material (Claro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .vazio, hasMaterial: false),
        lens: SimulatedLens()
    )
}

#Preview("T02 - 9. Vazio Sem Material (Escuro)") {
    ChatView(
        viewModel: ChatPreviewHelper.make(kind: .vazio, hasMaterial: false),
        lens: SimulatedLens()
    )
    .preferredColorScheme(.dark)
}

// MARK: - ChatPreviewHelper

@MainActor
enum ChatPreviewHelper {
    static func make(
        kind: ChatScreenState.Kind,
        hasMaterial: Bool = true,
        fontesAbertas: Bool = false,
        comCitacao: Bool = true
    ) -> ConversationViewModel {
        let lens = SimulatedLens()
        let retriever = PreviewRetriever()
        let generator = PreviewGenerator()
        let viewModel = ConversationViewModel(
            retriever: retriever,
            generator: generator,
            formatter: LensFormatter(),
            lens: lens,
            transcriber: PreviewTranscriber()
        )
        viewModel.hasMaterialProvider = { hasMaterial }
        configure(
            viewModel: viewModel,
            lens: lens,
            for: kind,
            fontesAbertas: fontesAbertas,
            comCitacao: comCitacao
        )
        return viewModel
    }

    private static func configure(
        viewModel: ConversationViewModel,
        lens: SimulatedLens,
        for kind: ChatScreenState.Kind,
        fontesAbertas: Bool = false,
        comCitacao: Bool = true
    ) {
        switch kind {
        case .vazio, .digitando:
            break
        case .escuta:
            viewModel.startListening()
            viewModel.currentTranscript = "Por que Swift nativo e não Flutter..."
        case .pensando:
            viewModel.state = .pensando
            viewModel.pendingQuestion = "Por que Swift nativo e não Flutter?"
        case .conversa:
            configureConversa(
                viewModel: viewModel,
                lens: lens,
                fontesAbertas: fontesAbertas,
                comCitacao: comCitacao
            )
        case .semMaterial:
            configureSemMaterial(viewModel: viewModel)
        case .erro:
            viewModel.state = .erro
            viewModel.errorMessage = "Falha de rede. Verifique a rede e tente de novo."
        case .desconectado:
            viewModel.isGlassesConnected = false
        }
    }

    private static func configureConversa(
        viewModel: ConversationViewModel,
        lens: SimulatedLens,
        fontesAbertas: Bool = false,
        comCitacao: Bool = true
    ) {
        viewModel.state = .respondido

        let ans1 = comCitacao
            ? "• Resposta rápida na banca[1]\n• Sem olhar anotações[1]"
            : "• Resposta rápida na banca\n• Sem olhar anotações"

        let ans2 = comCitacao
            ? "• DAT SDK só tem módulos Swift[1]\n• Menor latência de áudio[1]\n• Acesso direto ao **SpeechAnalyzer**[2]"
            : "• DAT SDK só tem módulos Swift\n• Menor latência de áudio\n• Acesso direto ao **SpeechAnalyzer**"

        viewModel.messages = [
            ChatMessage(
                question: "Qual o problema que o app resolve?",
                answer: ans1,
                sources: [SourceRef(path: "README.md")],
                latency: LatencyReport(retrievalSeconds: 0.1, totalSeconds: 1.4),
                isSourcesExpanded: false
            ),
            ChatMessage(
                question: "Por que Swift nativo e não Flutter?",
                answer: ans2,
                sources: [
                    SourceRef(path: "qa/stack.md"),
                    SourceRef(path: "docs/adr/0001-swift-nativo-com-dat-sdk.md")
                ],
                latency: LatencyReport(retrievalSeconds: 0.05, totalSeconds: 0.6),
                isSourcesExpanded: fontesAbertas
            )
        ]
        lens.show(
            LensContent(
                question: "Por que Swift nativo?",
                body: "• DAT SDK só tem Swift\n• Menor latência",
                sources: [SourceRef(path: "qa/stack.md")]
            )
        )
    }

    private static func configureSemMaterial(viewModel: ConversationViewModel) {
        viewModel.state = .semMaterial
        viewModel.messages = [
            ChatMessage(
                question: "Qual o orçamento do projeto?",
                answer: AnswerPipeline.notFoundMessage,
                sources: [],
                latency: LatencyReport(retrievalSeconds: 0.02, totalSeconds: 0.1)
            )
        ]
    }
}

private struct PreviewRetriever: Retriever {
    func retrieve(_ question: String) async throws -> Retrieval {
        Retrieval(qaNote: nil, chunks: [])
    }
}

private final class PreviewGenerator: AnswerGenerator, @unchecked Sendable {
    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        AsyncStream { $0.finish() }
    }
}

private final class PreviewTranscriber: SpeechTranscriber, @unchecked Sendable {
    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        AsyncStream { $0.finish() }
    }
}
