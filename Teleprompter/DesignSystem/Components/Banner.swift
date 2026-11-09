import SwiftUI

/// Banner de feedback, erro ou aviso com texto acionável (DESIGN.md 4).
public struct Banner: View {
    public enum Style: Sendable {
        case danger
        case warning
        case info

        public var color: Color {
            switch self {
            case .danger: return Colors.danger
            case .warning: return Colors.warning
            case .info: return Colors.info
            }
        }

        public var iconName: String {
            switch self {
            case .danger: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        public var prefix: String {
            switch self {
            case .danger: return "Erro"
            case .warning: return "Aviso"
            case .info: return "Informação"
            }
        }
    }

    public let style: Style
    public let title: String
    public let message: String
    public var actionTitle: String?
    public var action: (() -> Void)?
    public var onDismiss: (() -> Void)?

    public init(
        style: Style,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.style = style
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack(alignment: .top, spacing: Spacing.s3) {
                Image(systemName: style.iconName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(style.color)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.s1) {
                    Text(title)
                        .font(Typography.bodySm)
                        .fontWeight(.bold)
                        .foregroundStyle(style.color)

                    Text(message)
                        .font(Typography.bodySm)
                        .foregroundStyle(Colors.foreground)
                }

                Spacer(minLength: 0)

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Colors.muted)
                            .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fechar \(style.prefix.lowercased())")
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.bodySm)
                        .fontWeight(.semibold)
                        .foregroundStyle(style.color)
                        .frame(minHeight: Spacing.minTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionTitle)
            }
        }
        .padding(Spacing.s3)
        .background(Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(style.color, lineWidth: Borders.standard)
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("Banner - Estados") {
    VStack(spacing: Spacing.s4) {
        Banner(
            style: .danger,
            title: "Sem conexão",
            message: "Respondendo só com as notas de Q&A. Verifique a rede e tente de novo.",
            actionTitle: "Tentar reconectar",
            action: {},
            onDismiss: {}
        )

        Banner(
            style: .warning,
            title: "Óculos desconectados",
            message: "A resposta aparece só no iPhone. Reconecte pelo app Meta AI.",
            onDismiss: {}
        )

        Banner(
            style: .info,
            title: "Índice atualizado",
            message: "12 notas prontas para busca rápida.",
            actionTitle: "Ver notas",
            action: {}
        )
    }
    .padding(Spacing.s4)
    .background(Colors.background)
}

#Preview("Banner - Escuro") {
    VStack(spacing: Spacing.s4) {
        Banner(
            style: .danger,
            title: "Sem conexão",
            message: "Verifique a rede e tente de novo.",
            actionTitle: "Tentar de novo",
            action: {}
        )
    }
    .padding(Spacing.s4)
    .background(Colors.background)
    .preferredColorScheme(.dark)
}
