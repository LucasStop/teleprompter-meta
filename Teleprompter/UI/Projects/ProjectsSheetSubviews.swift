import SwiftUI

// MARK: - Subviews de Projetos

struct ProjectRowView: View {
    let item: ProjectRowItem
    var onSelect: () -> Void

    var body: some View {
        Button(
            action: onSelect,
            label: {
                HStack(alignment: .center, spacing: Spacing.s2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(Typography.body)
                            .fontWeight(.bold)
                            .foregroundStyle(Colors.foreground)
                            .lineLimit(1)

                        Text(item.formattedStats)
                            .font(Typography.caption)
                            .foregroundStyle(Colors.muted)
                            .lineLimit(1)
                    }

                    Spacer()

                    if item.isActive {
                        Text("✓")
                            .font(Typography.body)
                            .fontWeight(.bold)
                            .foregroundStyle(Colors.primary)
                    }
                }
                .padding(.horizontal, Spacing.s3)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(item.isActive ? Colors.primary : Colors.border, lineWidth: Borders.standard)
                )
            }
        )
        .buttonStyle(.plain)
        .accessibilityIdentifier("project-item-\(item.id)")
        .accessibilityLabel("\(item.name), \(item.formattedStats)\(item.isActive ? ", selecionado" : "")")
    }
}

struct NewProjectSheetView: View {
    @Bindable var viewModel: ProjectsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Novo projeto")
                .font(Typography.h2)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("project-new-title")

            Text("Cada projeto tem a sua pasta de material e as suas conversas. Depois de criar, importe a pasta na aba Material.")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)

            TextField("Nome do projeto", text: $viewModel.projectNameInput)
                .font(Typography.body)
                .padding(.horizontal, Spacing.s4)
                .frame(minHeight: Spacing.minTouchTarget)
                .background(Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(viewModel.errorMessage != nil ? Colors.danger : Colors.border, lineWidth: Borders.standard)
                )
                .accessibilityIdentifier("project-name-input")

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(Colors.danger)
            }

            VStack(spacing: Spacing.s2) {
                Button(
                    action: { Task { await viewModel.confirmCreateProject() } },
                    label: {
                        Text("Criar projeto")
                            .font(Typography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.primaryForeground)
                            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                            .background(Colors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-create-confirm-button")

                Button(
                    action: { viewModel.cancelSheetAction() },
                    label: {
                        Text("Cancelar")
                            .font(Typography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.foreground)
                            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                            .background(Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Colors.border, lineWidth: Borders.standard)
                            )
                    }
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-create-cancel-button")
            }
            .padding(.top, Spacing.s2)
        }
    }
}

struct RenameProjectSheetView: View {
    @Bindable var viewModel: ProjectsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Renomear projeto")
                .font(Typography.h2)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("project-rename-title")

            TextField("Nome do projeto", text: $viewModel.projectNameInput)
                .font(Typography.body)
                .padding(.horizontal, Spacing.s4)
                .frame(minHeight: Spacing.minTouchTarget)
                .background(Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.md)
                        .stroke(viewModel.errorMessage != nil ? Colors.danger : Colors.border, lineWidth: Borders.standard)
                )
                .accessibilityIdentifier("project-rename-input")

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(Typography.caption)
                    .foregroundStyle(Colors.danger)
            }

            VStack(spacing: Spacing.s2) {
                Button(
                    action: { Task { await viewModel.confirmRenameProject() } },
                    label: {
                        Text("Renomear")
                            .font(Typography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.primaryForeground)
                            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                            .background(Colors.primary)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-rename-confirm-button")

                Button(
                    action: { viewModel.cancelSheetAction() },
                    label: {
                        Text("Cancelar")
                            .font(Typography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.foreground)
                            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                            .background(Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Colors.border, lineWidth: Borders.standard)
                            )
                    }
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-rename-cancel-button")
            }
            .padding(.top, Spacing.s2)
        }
    }
}

struct DeleteProjectSheetView: View {
    @Bindable var viewModel: ProjectsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Excluir \"\(viewModel.activeProjectName)\"?")
                .font(Typography.h2)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("project-delete-title")

            let activeItem = viewModel.projectItems.first(where: { $0.id == viewModel.activeProjectId })
            let convCount = activeItem?.conversationsCount ?? 0
            let convText = convCount == 1 ? "1 conversa" : "\(convCount) conversas"

            Text("Apaga o material importado e as \(convText) deste projeto, só neste aparelho. Não dá para desfazer.")
                .font(Typography.bodySm)
                .foregroundStyle(Colors.foreground)

            VStack(spacing: Spacing.s2) {
                Button(
                    action: { Task { await viewModel.confirmDeleteProject() } },
                    label: {
                        Text("Excluir projeto")
                            .font(Typography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.danger)
                            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                            .background(Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Colors.danger, lineWidth: Borders.standard)
                            )
                    }
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-delete-confirm-button")

                Button(
                    action: { viewModel.cancelSheetAction() },
                    label: {
                        Text("Cancelar")
                            .font(Typography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.foreground)
                            .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                            .background(Colors.background)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.md)
                                    .stroke(Colors.border, lineWidth: Borders.standard)
                            )
                    }
                )
                .buttonStyle(.plain)
                .accessibilityIdentifier("project-delete-cancel-button")
            }
            .padding(.top, Spacing.s2)
        }
    }
}
