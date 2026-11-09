import SwiftUI

/// Folha modal de gerenciamento de projetos conforme o protótipo T02 (projetos, novo, excluir).
struct ProjectsSheetView: View {
    @Bindable var viewModel: ProjectsViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.s3) {
                switch viewModel.sheetState {
                case .list:
                    listView
                case .novo:
                    NewProjectSheetView(viewModel: viewModel)
                case .renomear:
                    RenameProjectSheetView(viewModel: viewModel)
                case .excluir:
                    DeleteProjectSheetView(viewModel: viewModel)
                }
            }
            .padding(Spacing.s4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Colors.surface)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Estado: Lista de Projetos

    private var listView: some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            Text("Projetos")
                .font(Typography.h2)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("projects-sheet-title")

            ScrollView {
                VStack(spacing: Spacing.s2) {
                    ForEach(viewModel.projectItems) { item in
                        ProjectRowView(item: item) {
                            Task {
                                await viewModel.selectProject(id: item.id)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 280)

            actionButtons
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Spacing.s2) {
            Button(
                action: { viewModel.openNewProject() },
                label: {
                    Text("Novo projeto")
                        .font(Typography.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Colors.primaryForeground)
                        .frame(maxWidth: .infinity, minHeight: Spacing.minTouchTarget)
                        .background(Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                }
            )
            .buttonStyle(.plain)
            .accessibilityIdentifier("projects-new-button")

            Button(
                action: { viewModel.openRenameProject() },
                label: {
                    Text("Renomear projeto ativo")
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
            .accessibilityIdentifier("projects-rename-button")

            if viewModel.activeProjectId != Project.defaultId {
                Button(
                    action: { viewModel.openDeleteProject() },
                    label: {
                        Text("Excluir projeto ativo")
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
                .accessibilityIdentifier("projects-delete-button")
            }
        }
        .padding(.top, Spacing.s2)
    }
}
