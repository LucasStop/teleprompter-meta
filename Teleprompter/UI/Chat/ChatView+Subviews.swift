import SwiftUI

// MARK: - Subviews do ChatView

struct ChatEmptyPlaceholderView: View {
    let screenState: ChatScreenState
    var onAskQuestion: (String) -> Void

    var body: some View {
        VStack(spacing: Spacing.s3) {
            Text(screenState.emptyPlaceholderTitle)
                .font(Typography.h2)
                .foregroundStyle(Colors.foreground)
                .multilineTextAlignment(.center)

            Text(screenState.emptyPlaceholderSubtitle)
                .font(Typography.bodySm)
                .foregroundStyle(Colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s4)

            if !screenState.suggestionChips.isEmpty {
                VStack(spacing: Spacing.s2) {
                    ForEach(screenState.suggestionChips, id: \.self) { chip in
                        Button(
                            action: { onAskQuestion(chip) },
                            label: {
                                Text(chip)
                                    .font(Typography.bodySm)
                                    .foregroundStyle(Colors.foreground)
                                    .padding(.horizontal, Spacing.s3)
                                    .padding(.vertical, Spacing.s2)
                                    .frame(minHeight: Spacing.minTouchTarget)
                                    .background(Colors.surface)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Colors.border, lineWidth: Borders.standard)
                                    )
                            }
                        )
                        .buttonStyle(.plain)
                        .accessibilityLabel("Sugestão de pergunta: \(chip)")
                    }
                }
                .padding(.top, Spacing.s2)
            }
        }
        .padding(.horizontal, Spacing.s4)
        .frame(maxWidth: .infinity)
    }
}

struct ChatComposerSectionView: View {
    @Binding var text: String
    var isListening: Bool
    var placeholder: String
    var onToggleListening: () -> Void
    var onSend: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s2) {
            HStack {
                Toggle(isOn: Binding(
                    get: { isListening },
                    set: { _ in onToggleListening() }
                )) {
                    Text("Escuta contínua")
                        .font(Typography.bodySm)
                        .foregroundStyle(Colors.foreground)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(SwitchToggleStyle(tint: Colors.primary))
                .accessibilityLabel("Escuta contínua")
                .accessibilityHint(isListening ? "Desativar escuta contínua" : "Ativar escuta contínua")
                .frame(minHeight: Spacing.minTouchTarget)

                Spacer()

                Text("Só material importado")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, Spacing.s4)

            ComposerField(
                text: $text,
                placeholder: placeholder,
                isListening: isListening,
                onSend: onSend,
                onMicTapped: onToggleListening
            )
            .accessibilityIdentifier("chat-composer-field")
            .padding(.horizontal, Spacing.s4)
            .padding(.bottom, Spacing.s3)
        }
        .background(Colors.surface)
        .overlay(
            Rectangle()
                .frame(height: Borders.standard)
                .foregroundStyle(Colors.border),
            alignment: .top
        )
    }
}
