import Foundation
import Observation

/// Estado da folha de projetos conforme o protótipo T02 (projetos, novo, excluir).
enum ProjectsSheetState: Equatable, Sendable {
    case list
    case novo
    case renomear
    case excluir
}

/// Item de apresentação para cada projeto na lista.
struct ProjectRowItem: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let isDefault: Bool
    let isActive: Bool
    let filesCount: Int
    let chunksCount: Int
    let conversationsCount: Int
    let formattedStats: String

    init(
        project: Project,
        isActive: Bool,
        filesCount: Int,
        chunksCount: Int,
        conversationsCount: Int
    ) {
        self.id = project.id
        self.name = project.name
        self.isDefault = project.id == Project.defaultId
        self.isActive = isActive
        self.filesCount = filesCount
        self.chunksCount = chunksCount
        self.conversationsCount = conversationsCount

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")

        let filesFormatted = formatter.string(from: NSNumber(value: filesCount)) ?? "\(filesCount)"
        let chunksFormatted = formatter.string(from: NSNumber(value: chunksCount)) ?? "\(chunksCount)"
        let convFormatted = formatter.string(from: NSNumber(value: conversationsCount)) ?? "\(conversationsCount)"

        let filesLabel = filesCount == 1 ? "arquivo" : "arquivos"
        let chunksLabel = chunksCount == 1 ? "trecho" : "trechos"
        let convLabel = conversationsCount == 1 ? "conversa" : "conversas"

        self.formattedStats = "\(filesFormatted) \(filesLabel) · \(chunksFormatted) \(chunksLabel) · \(convFormatted) \(convLabel)"
    }
}

/// Gerencia o estado e operações da folha de seleção e gerenciamento de projetos (T02).
@MainActor
@Observable
final class ProjectsViewModel {
    var sheetState: ProjectsSheetState = .list
    var isShowingSheet: Bool = false
    var projectNameInput: String = ""
    var errorMessage: String?
    var isLoading: Bool = false

    var rawProjects: [Project] = []
    var projectItems: [ProjectRowItem] = []
    var activeProjectId: String = Project.defaultId

    let projectStore: any ProjectStore
    let settingsStore: any SettingsStore
    let conversationStore: any ConversationStore
    let retriever: any Retriever

    var onProjectChanged: (@MainActor (String) -> Void)?

    init(
        projectStore: any ProjectStore,
        settingsStore: any SettingsStore,
        conversationStore: any ConversationStore,
        retriever: any Retriever,
        onProjectChanged: (@MainActor (String) -> Void)? = nil
    ) {
        self.projectStore = projectStore
        self.settingsStore = settingsStore
        self.conversationStore = conversationStore
        self.retriever = retriever
        self.onProjectChanged = onProjectChanged
        self.activeProjectId = settingsStore.load().activeProjectId
    }

    var activeProject: Project {
        rawProjects.first(where: { $0.id == activeProjectId })
            ?? Project(id: activeProjectId, name: Project.defaultName)
    }

    var activeProjectName: String {
        activeProject.name
    }

    // MARK: - Carregamento

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            var list = try await projectStore.list()
            if list.isEmpty {
                list = [Project.default]
            }
            self.rawProjects = list

            var currentActive = settingsStore.load().activeProjectId
            if !list.contains(where: { $0.id == currentActive }) {
                currentActive = Project.defaultId
                var updatedSettings = settingsStore.load()
                updatedSettings.activeProjectId = Project.defaultId
                settingsStore.save(updatedSettings)
            }
            self.activeProjectId = currentActive

            await refreshProjectItems()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshProjectItems() async {
        var items: [ProjectRowItem] = []
        for project in rawProjects {
            let (files, chunks) = fetchStats(for: project.id)
            let convCount = (try? await conversationStore.count(forProjectId: project.id)) ?? 0
            let item = ProjectRowItem(
                project: project,
                isActive: project.id == activeProjectId,
                filesCount: files,
                chunksCount: chunks,
                conversationsCount: convCount
            )
            items.append(item)
        }
        self.projectItems = items
    }

    private func fetchStats(for projectId: String) -> (Int, Int) {
        if let prodRetriever = retriever as? ProductionAppRetriever {
            return prodRetriever.stats(for: projectId)
        }
        if let inMemoryRetriever = retriever as? InMemoryAppRetriever {
            return inMemoryRetriever.stats(for: projectId)
        }
        return (0, 0)
    }

    // MARK: - Ações de Projeto

    func selectProject(id: String) async {
        guard activeProjectId != id else {
            isShowingSheet = false
            sheetState = .list
            return
        }

        activeProjectId = id
        var settings = settingsStore.load()
        settings.activeProjectId = id
        settingsStore.save(settings)

        await refreshProjectItems()
        onProjectChanged?(id)

        isShowingSheet = false
        sheetState = .list
    }

    func openNewProject() {
        projectNameInput = ""
        errorMessage = nil
        sheetState = .novo
    }

    func confirmCreateProject() async {
        let trimmed = projectNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "O nome do projeto não pode ser vazio."
            return
        }

        do {
            let created = try await projectStore.create(name: trimmed)
            rawProjects = try await projectStore.list()
            await selectProject(id: created.id)
        } catch let err as ProjectStoreError {
            errorMessage = err.localizedDescription
        } catch {
            errorMessage = "Não foi possível criar o projeto."
        }
    }

    func openRenameProject() {
        projectNameInput = activeProject.name
        errorMessage = nil
        sheetState = .renomear
    }

    func confirmRenameProject() async {
        let trimmed = projectNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "O nome do projeto não pode ser vazio."
            return
        }

        do {
            _ = try await projectStore.rename(id: activeProjectId, to: trimmed)
            rawProjects = try await projectStore.list()
            await refreshProjectItems()
            sheetState = .list
        } catch let err as ProjectStoreError {
            errorMessage = err.localizedDescription
        } catch {
            errorMessage = "Não foi possível renomear o projeto."
        }
    }

    func openDeleteProject() {
        guard activeProjectId != Project.defaultId else { return }
        errorMessage = nil
        sheetState = .excluir
    }

    func confirmDeleteProject() async {
        let targetId = activeProjectId
        guard targetId != Project.defaultId else { return }

        do {
            try await projectStore.delete(id: targetId)

            if let prodRetriever = retriever as? ProductionAppRetriever {
                try? prodRetriever.deleteIndex(for: targetId)
            }
            if let inMemoryRetriever = retriever as? InMemoryAppRetriever {
                try? inMemoryRetriever.deleteIndex(for: targetId)
            }

            try await conversationStore.deleteAll(forProjectId: targetId)

            rawProjects = try await projectStore.list()
            await selectProject(id: Project.defaultId)
        } catch {
            errorMessage = "Não foi possível excluir o projeto."
        }
    }

    func cancelSheetAction() {
        errorMessage = nil
        projectNameInput = ""
        sheetState = .list
    }
}
