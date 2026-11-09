import SwiftUI

/// Campo de entrada com botão contextual de microfone ou envio (DESIGN.md 4).
public struct ComposerField: View {
    @Binding public var text: String
    public var placeholder: String
    public var isListening: Bool
    public var onSend: (() -> Void)?
    public var onMicTapped: (() -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String = "Pergunte sobre o seu material",
        isListening: Bool = false,
        onSend: (() -> Void)? = nil,
        onMicTapped: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isListening = isListening
        self.onSend = onSend
        self.onMicTapped = onMicTapped
    }

    private var isTyping: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.s2) {
            TextField(
                isListening ? "Ouvindo a banca..." : placeholder,
                text: $text,
                axis: .vertical
            )
            .font(Typography.body)
            .foregroundStyle(Colors.foreground)
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, 10)
            .frame(minHeight: Spacing.minTouchTarget)
            .background(Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Colors.border, lineWidth: Borders.standard)
            )
            .accessibilityLabel("Campo de pergunta")
            .accessibilityHint(placeholder)

            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isListening {
            Button(
                action: { onMicTapped?() },
                label: {
                    Image(systemName: "square.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                        .background(Colors.danger)
                        .clipShape(Circle())
                }
            )
            .buttonStyle(.plain)
            .accessibilityLabel("Parar escuta contínua")
        } else if isTyping {
            Button(
                action: { onSend?() },
                label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Colors.primaryForeground)
                        .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                        .background(Colors.primary)
                        .clipShape(Circle())
                }
            )
            .buttonStyle(.plain)
            .accessibilityLabel("Enviar pergunta")
        } else {
            Button(
                action: { onMicTapped?() },
                label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Colors.foreground)
                        .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                        .background(Colors.background)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Colors.border, lineWidth: Borders.standard)
                        )
                }
            )
            .buttonStyle(.plain)
            .accessibilityLabel("Falar pergunta")
        }
    }
}

#Preview("ComposerField - Vazio") {
    VStack {
        ComposerField(
            text: .constant(""),
            isListening: false
        )
    }
    .padding(Spacing.s4)
    .background(Colors.surface)
}

#Preview("ComposerField - Digitando") {
    VStack {
        ComposerField(
            text: .constant("Como funciona a busca no material?"),
            isListening: false
        )
    }
    .padding(Spacing.s4)
    .background(Colors.surface)
}

#Preview("ComposerField - Ouvindo") {
    VStack {
        ComposerField(
            text: .constant(""),
            isListening: true
        )
    }
    .padding(Spacing.s4)
    .background(Colors.surface)
    .preferredColorScheme(.dark)
}
