import SwiftUI

/// Bolha de mensagem do chat (DESIGN.md 4).
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

    public init(
        role: Role,
        text: String,
        bullets: [String] = [],
        sources: [String] = [],
        caption: String? = nil
    ) {
        self.role = role
        self.text = text
        self.bullets = bullets
        self.sources = sources
        self.caption = caption
    }

    public var body: some View {
        HStack {
            if role == .question || role == .partial {
                Spacer(minLength: Spacing.s7)
            }

            VStack(alignment: role == .answer ? .leading : .trailing, spacing: Spacing.s2) {
                bubbleContent
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s3)
                    .background(bubbleBackground)
                    .clipShape(bubbleShape)
                    .overlay(bubbleBorder)

                if let caption {
                    Text(caption)
                        .font(Typography.caption)
                        .foregroundStyle(Colors.muted)
                        .padding(.horizontal, Spacing.s2)
                }
            }

            if role == .answer {
                Spacer(minLength: Spacing.s7)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            if role == .partial {
                HStack(spacing: Spacing.s1) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text("Ouvindo pergunta...")
                        .font(Typography.caption)
                }
                .foregroundStyle(Colors.primaryForeground.opacity(0.85))
            }

            Text(text)
                .font(Typography.body)
                .foregroundStyle(role == .answer ? Colors.foreground : Colors.primaryForeground)

            if !bullets.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: Spacing.s2) {
                            Text("•")
                                .font(Typography.body)
                                .foregroundStyle(Colors.muted)
                            Text(bullet)
                                .font(Typography.body)
                                .foregroundStyle(Colors.foreground)
                        }
                    }
                }
                .padding(.top, Spacing.s1)
            }

            if !sources.isEmpty {
                HStack(spacing: Spacing.s1) {
                    ForEach(sources, id: \.self) { source in
                        SourceChip(title: source)
                    }
                }
                .padding(.top, Spacing.s1)
            }
        }
    }

    private var bubbleBackground: Color {
        switch role {
        case .question:
            return Colors.primary
        case .partial:
            return Colors.primary.opacity(0.85)
        case .answer:
            return Colors.surface
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        switch role {
        case .question, .partial:
            return UnevenRoundedRectangle(
                topLeadingRadius: CornerRadius.lg,
                bottomLeadingRadius: CornerRadius.lg,
                bottomTrailingRadius: CornerRadius.sm,
                topTrailingRadius: CornerRadius.lg
            )
        case .answer:
            return UnevenRoundedRectangle(
                topLeadingRadius: CornerRadius.lg,
                bottomLeadingRadius: CornerRadius.sm,
                bottomTrailingRadius: CornerRadius.lg,
                topTrailingRadius: CornerRadius.lg
            )
        }
    }

    @ViewBuilder
    private var bubbleBorder: some View {
        if role == .answer {
            bubbleShape
                .stroke(Colors.border, lineWidth: Borders.standard)
        }
    }

    private var accessibilityDescription: String {
        let prefix: String
        switch role {
        case .question: prefix = "Pergunta"
        case .partial: prefix = "Pergunta parcial"
        case .answer: prefix = "Resposta"
        }
        var desc = "\(prefix): \(text)"
        if !bullets.isEmpty {
            desc += ". Pontos: " + bullets.joined(separator: ", ")
        }
        if !sources.isEmpty {
            desc += ". Fontes: " + sources.joined(separator: ", ")
        }
        if let caption {
            desc += ". \(caption)"
        }
        return desc
    }
}

#Preview("MessageBubble - Estados") {
    VStack(spacing: Spacing.s4) {
        MessageBubble(role: .question, text: "Por que Swift nativo e não Flutter?")
        MessageBubble(role: .partial, text: "Como funciona a busca no...")
        MessageBubble(
            role: .answer,
            text: "Resposta rápida com base no material:",
            bullets: [
                "DAT SDK só tem módulos Swift",
                "Menor latência de áudio",
                "Acesso direto ao SpeechAnalyzer"
            ],
            sources: ["qa/stack.md", "docs/ADR-0001.md"],
            caption: "nota de Q&A · 0,6 s"
        )
    }
    .padding(Spacing.s4)
    .background(Colors.background)
}

#Preview("MessageBubble - Escuro") {
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
    .preferredColorScheme(.dark)
}
