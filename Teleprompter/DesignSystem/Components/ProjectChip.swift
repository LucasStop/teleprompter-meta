import SwiftUI

/// Componente visual para exibição e seleção do projeto ativo (DESIGN.md e T02 / T04 / T07).
struct ProjectChip: View {
    let projectName: String
    var action: (() -> Void)?

    init(projectName: String, action: (() -> Void)? = nil) {
        self.projectName = projectName
        self.action = action
    }

    var body: some View {
        Button(
            action: { action?() },
            label: {
                HStack(spacing: Spacing.s2) {
                    Text("Projeto")
                        .font(Typography.bodySm)
                        .foregroundStyle(Colors.muted)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(projectName)
                        .font(Typography.bodySm)
                        .fontWeight(.bold)
                        .foregroundStyle(Colors.foreground)
                        .fixedSize(horizontal: true, vertical: false)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Colors.muted)
                }
                .padding(.horizontal, Spacing.s3)
                .padding(.vertical, Spacing.s1)
                .frame(minHeight: Spacing.minTouchTarget)
                .background(Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(Colors.border, lineWidth: Borders.standard)
                )
                .accessibilityHidden(true)
            }
        )
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Projeto ativo: \(projectName)")
        .accessibilityHint("Toque para trocar ou gerenciar projetos")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("chat-project-selector")
    }
}

/// Linha simples de indicação do projeto ativo conforme t04-importacao e t07-conversas (.projline).
struct ProjectLine: View {
    let projectName: String
    var action: (() -> Void)?

    init(projectName: String, action: (() -> Void)? = nil) {
        self.projectName = projectName
        self.action = action
    }

    var body: some View {
        Button(
            action: { action?() },
            label: {
                HStack(spacing: Spacing.s2) {
                    Text("Projeto")
                        .font(Typography.bodySm)
                        .foregroundStyle(Colors.muted)
                        .fixedSize(horizontal: true, vertical: false)

                    Text(projectName)
                        .font(Typography.bodySm)
                        .fontWeight(.bold)
                        .foregroundStyle(Colors.foreground)
                        .fixedSize(horizontal: true, vertical: false)

                    if action != nil {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Colors.muted)
                    }

                    Spacer()
                }
                .frame(minHeight: Spacing.minTouchTarget)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
            }
        )
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Projeto ativo: \(projectName)")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("active-project-line")
    }
}
