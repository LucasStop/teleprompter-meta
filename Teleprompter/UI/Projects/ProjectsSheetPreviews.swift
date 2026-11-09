import SwiftUI

@MainActor
enum ProjectsPreviewHelper {
    static func make(state: ProjectsSheetState = .list) -> ProjectsViewModel {
        var settings = Settings.default
        settings.activeProjectId = "cursos"
        let settingsStore = InMemorySettingsStore(initial: settings)

        let projectStore = InMemoryProjectStore(initialProjects: [
            Project(id: "cursos", name: "Plataforma de cursos"),
            Project(id: Project.defaultId, name: "Teleprompter Meta")
        ])

        let convStore = InMemoryConversationStore(
            initialConversations: [],
            activeProjectIdProvider: { settingsStore.load().activeProjectId }
        )

        let retriever = InMemoryAppRetriever(settingsStore: settingsStore)

        let viewModel = ProjectsViewModel(
            projectStore: projectStore,
            settingsStore: settingsStore,
            conversationStore: convStore,
            retriever: retriever
        )
        viewModel.sheetState = state
        viewModel.rawProjects = [
            Project(id: "cursos", name: "Plataforma de cursos"),
            Project(id: Project.defaultId, name: "Teleprompter Meta")
        ]
        viewModel.projectItems = [
            ProjectRowItem(
                project: Project(id: "cursos", name: "Plataforma de cursos"),
                isActive: true,
                filesCount: 123,
                chunksCount: 1910,
                conversationsCount: 8
            ),
            ProjectRowItem(
                project: Project(id: Project.defaultId, name: "Teleprompter Meta"),
                isActive: false,
                filesCount: 143,
                chunksCount: 1265,
                conversationsCount: 3
            )
        ]
        return viewModel
    }
}

#Preview("T02 - Projetos: Lista (Claro)") {
    ProjectsSheetView(viewModel: ProjectsPreviewHelper.make(state: .list))
}

#Preview("T02 - Projetos: Lista (Escuro)") {
    ProjectsSheetView(viewModel: ProjectsPreviewHelper.make(state: .list))
        .preferredColorScheme(.dark)
}

#Preview("T02 - Projetos: Novo (Claro)") {
    ProjectsSheetView(viewModel: ProjectsPreviewHelper.make(state: .novo))
}

#Preview("T02 - Projetos: Novo (Escuro)") {
    ProjectsSheetView(viewModel: ProjectsPreviewHelper.make(state: .novo))
        .preferredColorScheme(.dark)
}

#Preview("T02 - Projetos: Excluir (Claro)") {
    ProjectsSheetView(viewModel: ProjectsPreviewHelper.make(state: .excluir))
}

#Preview("T02 - Projetos: Excluir (Escuro)") {
    ProjectsSheetView(viewModel: ProjectsPreviewHelper.make(state: .excluir))
        .preferredColorScheme(.dark)
}
