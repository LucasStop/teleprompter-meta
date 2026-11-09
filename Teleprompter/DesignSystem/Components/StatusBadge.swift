import SwiftUI

/// Selo de estado da sessão (DESIGN.md 4).
public struct StatusBadge: View {
    public enum Status: String, CaseIterable, Sendable {
        case pronto
        case ativo
        // swiftlint:disable:next identifier_name
        case ok
        case erro

        public var defaultTitle: String {
            switch self {
            case .pronto: return "Pronto"
            case .ativo: return "Ouvindo a banca"
            case .ok: return "Resposta enviada à lente"
            case .erro: return "Sem conexão"
            }
        }

        public var color: Color {
            switch self {
            case .pronto: return Colors.muted
            case .ativo: return Colors.primary
            case .ok: return Colors.success
            case .erro: return Colors.danger
            }
        }

        public var iconName: String {
            switch self {
            case .pronto: return "circle"
            case .ativo: return "waveform"
            case .ok: return "checkmark.circle.fill"
            case .erro: return "exclamationmark.circle.fill"
            }
        }

        public var accessibilityPrefix: String {
            switch self {
            case .pronto: return "Estado pronto"
            case .ativo: return "Estado ativo"
            case .ok: return "Estado concluído com sucesso"
            case .erro: return "Estado com erro"
            }
        }
    }

    public let status: Status
    public var title: String?

    public init(status: Status, title: String? = nil) {
        self.status = status
        self.title = title
    }

    public var body: some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: status.iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(status.color)

            Text(displayTitle)
                .font(Typography.bodySm)
                .foregroundStyle(Colors.foreground)
        }
        .padding(.horizontal, Spacing.s3)
        .padding(.vertical, Spacing.s1)
        .background(Colors.surface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Colors.border, lineWidth: Borders.standard)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.accessibilityPrefix): \(displayTitle)")
    }

    private var displayTitle: String {
        title ?? status.defaultTitle
    }
}

#Preview("StatusBadge - Estados") {
    VStack(spacing: Spacing.s3) {
        StatusBadge(status: .pronto)
        StatusBadge(status: .ativo, title: "Ouvindo a banca")
        StatusBadge(status: .ativo, title: "Buscando no material")
        StatusBadge(status: .ok)
        StatusBadge(status: .erro, title: "Sem conexão")
        StatusBadge(status: .erro, title: "Óculos desconectados")
    }
    .padding(Spacing.s4)
    .background(Colors.background)
}

#Preview("StatusBadge - Escuro") {
    VStack(spacing: Spacing.s3) {
        StatusBadge(status: .pronto)
        StatusBadge(status: .ativo)
        StatusBadge(status: .ok)
        StatusBadge(status: .erro)
    }
    .padding(Spacing.s4)
    .background(Colors.background)
    .preferredColorScheme(.dark)
}
