import SwiftUI

/// Mensagem do chat (DESIGN.md 4 e protótipo T02).
public struct MessageBubble: View {
    public enum Role: Equatable, Sendable {
        case question
        case answer
        case partial
    }

    public let role: Role
    public let text: String
    public var bullets: [String]
    public var sources: [String]
    public var caption: String?
    public var isSentToLens: Bool
    public var isSourcesExpanded: Bool
    public var maxBubbleWidth: CGFloat?

    public init(
        role: Role,
        text: String,
        bullets: [String] = [],
        sources: [String] = [],
        caption: String? = nil,
        isSentToLens: Bool = true,
        isSourcesExpanded: Bool = false,
        maxBubbleWidth: CGFloat? = nil
    ) {
        self.role = role
        self.text = text
        self.bullets = bullets
        self.sources = sources
        self.caption = caption
        self.isSentToLens = isSentToLens
        self.isSourcesExpanded = isSourcesExpanded
        self.maxBubbleWidth = maxBubbleWidth
    }

    public var body: some View {
        if role == .answer {
            answerView
        } else {
            questionView
        }
    }

    // MARK: - Pergunta (bolha neutra user-bubble, alinhada à direita, até 80%)

    private var questionView: some View {
        HStack {
            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: Spacing.s2) {
                questionBubbleContent
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, 10)
                    .background(Colors.userBubble)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                if let caption {
                    Text(caption)
                        .font(Typography.caption)
                        .foregroundStyle(Colors.muted)
                        .padding(.horizontal, Spacing.s2)
                }
            }
            .frame(maxWidth: maxBubbleWidth ?? (UIScreen.main.bounds.width * 0.8), alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var questionBubbleContent: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            if role == .partial {
                HStack(spacing: Spacing.s1) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text("Ouvindo pergunta...")
                        .font(Typography.caption)
                }
                .foregroundStyle(Colors.muted)
            }

            if !text.isEmpty {
                Text(Self.markdown(text))
                    .font(Typography.body)
                    .foregroundStyle(Colors.foreground)
                    .opacity(role == .partial ? 0.7 : 1.0)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Resposta (sem bolha, sem borda, largura cheia, alinhada à esquerda)

    private var answerView: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            // O cartão de fontes fica fora do elemento combinado para o VoiceOver alcançar o botão.
            answerContent
                .padding(.horizontal, 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityDescription)

            if !sources.isEmpty {
                SourcesCard(sources: sources, initiallyExpanded: isSourcesExpanded)
                    .padding(.top, Spacing.s1)
            }

            if let caption {
                footerView(caption: caption)
                    .padding(.horizontal, 2)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var answerContent: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            if !text.isEmpty {
                Text(Self.markdown(text, sourceCount: sources.count))
                    .font(Typography.body)
                    .foregroundStyle(Colors.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: Spacing.s2) {
                            Text("•")
                                .font(Typography.body)
                                .foregroundStyle(Colors.muted)
                            Text(Self.markdown(bullet, sourceCount: sources.count))
                                .font(Typography.body)
                                .foregroundStyle(Colors.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, Spacing.s1)
            }
        }
    }

    @ViewBuilder
    private func footerView(caption: String) -> some View {
        let isNotFound = text == AnswerPipeline.notFoundMessage
        let cleanCaption = caption.hasPrefix("Na lente · ")
            ? String(caption.dropFirst("Na lente · ".count))
            : caption

        if isSentToLens && !isNotFound {
            HStack(spacing: Spacing.s2) {
                Circle()
                    .fill(Colors.success)
                    .frame(width: 7, height: 7)
                Text("Na lente · \(cleanCaption)")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
            }
        } else {
            Text(cleanCaption)
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)
        }
    }

    /// Renderiza negrito/itálico/código do markdown inline e substitui marcadores [n] por citação sobrescrita.
    nonisolated public static func markdown(_ string: String, sourceCount: Int = 0) -> AttributedString {
        CitationParser.parse(string, sourceCount: sourceCount)
    }

    private var accessibilityDescription: String {
        let prefix: String
        switch role {
        case .question: prefix = "Pergunta"
        case .partial: prefix = "Pergunta parcial"
        case .answer: prefix = "Resposta"
        }
        var desc = "\(prefix): \(CitationParser.stripCitations(text))"
        if !bullets.isEmpty {
            desc += ". Pontos: " + bullets.map(CitationParser.stripCitations).joined(separator: ", ")
        }
        if !sources.isEmpty {
            desc += ". Fontes: " + sources.joined(separator: ", ")
        }
        if let caption {
            if role == .answer && isSentToLens && text != AnswerPipeline.notFoundMessage {
                desc += ". Na lente · \(caption)"
            } else {
                desc += ". \(caption)"
            }
        }
        return desc
    }
}

#Preview("MessageBubble - Conversa com Citação (Fontes Fechadas)") {
    VStack(spacing: Spacing.s4) {
        MessageBubble(role: .question, text: "Por que Swift nativo e não Flutter?")
        MessageBubble(
            role: .answer,
            text: "Resposta com base no seu material:",
            bullets: [
                "DAT SDK só tem módulos Swift[1]",
                "Menor latência de áudio[1]",
                "Acesso direto ao **SpeechAnalyzer**[2]"
            ],
            sources: ["qa/stack.md", "docs/adr/0001-swift-nativo-com-dat-sdk.md"],
            caption: "nota de Q&A · 0,6 s"
        )
    }
    .padding(Spacing.s4)
    .background(Colors.background)
}

#Preview("MessageBubble - Fontes Abertas") {
    VStack(spacing: Spacing.s4) {
        MessageBubble(role: .question, text: "Por que Swift nativo e não Flutter?")
        MessageBubble(
            role: .answer,
            text: "Resposta com base no seu material:",
            bullets: [
                "DAT SDK só tem módulos Swift[1]",
                "Menor latência de áudio[1]",
                "Acesso direto ao **SpeechAnalyzer**[2]"
            ],
            sources: ["qa/stack.md", "docs/adr/0001-swift-nativo-com-dat-sdk.md"],
            caption: "nota de Q&A · 0,6 s",
            isSourcesExpanded: true
        )
    }
    .padding(Spacing.s4)
    .background(Colors.background)
    .preferredColorScheme(.dark)
}

#Preview("MessageBubble - Sem Citação") {
    VStack(spacing: Spacing.s4) {
        MessageBubble(role: .question, text: "Qual o problema que o app resolve?")
        MessageBubble(
            role: .answer,
            text: "Mostra respostas curtas na lente e no iPhone.",
            sources: ["README.md"],
            caption: "1,2 s"
        )
    }
    .padding(Spacing.s4)
    .background(Colors.background)
}

#Preview("MessageBubble - Desconectado") {
    VStack(spacing: Spacing.s4) {
        MessageBubble(role: .question, text: "Por que Swift?")
        MessageBubble(
            role: .answer,
            text: "Resposta sem envio à lente.",
            sources: ["README.md"],
            caption: "1,2 s",
            isSentToLens: false
        )
    }
    .padding(Spacing.s4)
    .background(Colors.background)
}
