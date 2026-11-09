import SwiftUI

/// Botão de ação primária (DESIGN.md 4).
public struct PrimaryButton: View {
    public let title: String
    public var icon: String?
    public var isLoading: Bool
    public var isEnabled: Bool
    public let action: () -> Void

    public init(
        title: String,
        icon: String? = nil,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(
            action: {
                if isEnabled && !isLoading {
                    action()
                }
            },
            label: {
                HStack(spacing: Spacing.s2) {
                    if isLoading {
                        ProgressView()
                            .tint(Colors.primaryForeground)
                            .accessibilityLabel("Carregando")
                    } else {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 17, weight: .semibold))
                        }
                        Text(title)
                            .font(Typography.bodySm)
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                .padding(.horizontal, Spacing.s4)
            }
        )
        .buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled && !isLoading))
        .disabled(!isEnabled || isLoading)
        .accessibilityLabel(isLoading ? "\(title), carregando" : title)
        .accessibilityAddTraits(.isButton)
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Colors.primaryForeground)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Colors.disabled
        }
        return isPressed ? Colors.primaryHover : Colors.primary
    }
}

#Preview("PrimaryButton - Estados") {
    VStack(spacing: Spacing.s4) {
        PrimaryButton(title: "Padrão", action: {})
        PrimaryButton(title: "Com ícone", icon: "arrow.right", action: {})
        PrimaryButton(title: "Carregando", isLoading: true, action: {})
        PrimaryButton(title: "Desabilitado", isEnabled: false, action: {})
    }
    .padding(Spacing.s4)
    .background(Colors.background)
}

#Preview("PrimaryButton - Escuro") {
    VStack(spacing: Spacing.s4) {
        PrimaryButton(title: "Padrão", action: {})
        PrimaryButton(title: "Carregando", isLoading: true, action: {})
        PrimaryButton(title: "Desabilitado", isEnabled: false, action: {})
    }
    .padding(Spacing.s4)
    .background(Colors.background)
    .preferredColorScheme(.dark)
}
