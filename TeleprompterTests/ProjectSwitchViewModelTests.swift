import Foundation
import XCTest
@testable import Teleprompter

@MainActor
final class ProjectSwitchViewModelTests: XCTestCase {
    private struct Context {
        let settingsStore: InMemorySettingsStore
        let convVM: ConversationViewModel
        let convsVM: ConversationsViewModel
        let projectsVM: ProjectsViewModel
    }

    private func makeContext() async throws -> Context {
        let settingsStore = InMemorySettingsStore(initial: Settings.default)
        let projectStore = InMemoryProjectStore(initialProjects: [
            Project(id: Project.defaultId, name: "Padrão"),
            Project(id: "projeto-novo", name: "Projeto Novo")
        ])
        let convStore = InMemoryConversationStore(
            initialConversations: [],
            activeProjectIdProvider: { settingsStore.load().activeProjectId }
        )
        let retriever = InMemoryAppRetriever(settingsStore: settingsStore)

        try await convStore.save(Conversation(title: "Conversa Padrão", messages: []))

        let convVM = ConversationViewModel(
            retriever: retriever,
            generator: InMemoryAppGenerator(),
            formatter: LensFormatter(),
            lens: SimulatedLens(),
            transcriber: InMemoryAppTranscriber(),
            detector: PauseQuestionDetector(silenceThreshold: 1.2),
            format: .bullets,
            settingsStore: settingsStore,
            secretStore: InMemorySecretStore(),
            conversationStore: convStore
        )

        let convsVM = ConversationsViewModel(store: convStore)
        await convsVM.load()

        let projectsVM = ProjectsViewModel(
            projectStore: projectStore,
            settingsStore: settingsStore,
            conversationStore: convStore,
            retriever: retriever
        )
        return Context(settingsStore: settingsStore, convVM: convVM, convsVM: convsVM, projectsVM: projectsVM)
    }

    func testSwitchingProjectClearsChatAndUpdatesConversations() async throws {
        let context = try await makeContext()
        XCTAssertEqual(context.convsVM.rawConversations.count, 1)

        // Simula estado ativo em tela
        context.convVM.messages = [
            ChatMessage(question: "Pergunta anterior", answer: "Resposta anterior", sources: [], latency: nil)
        ]
        context.convVM.lastLensContent = LensContent(question: "Pergunta", body: "Lente ativa", sources: [])
        context.convVM.currentTranscript = "Transcrição parcial"

        let convVM = context.convVM
        let convsVM = context.convsVM
        context.projectsVM.onProjectChanged = { newId in
            Task { @MainActor in
                await convVM.switchProject(to: newId)
                await convsVM.load()
            }
        }

        await context.projectsVM.selectProject(id: "projeto-novo")
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(context.settingsStore.load().activeProjectId, "projeto-novo")
        XCTAssertTrue(context.convVM.messages.isEmpty)
        XCTAssertNil(context.convVM.lastLensContent)
        XCTAssertTrue(context.convVM.currentTranscript.isEmpty)
        XCTAssertTrue(context.convsVM.rawConversations.isEmpty)
    }

    func testChatScreenStateEmptyPlaceholderAdaptsToMaterialPresence() {
        let badge = ChatScreenState.BadgeState(status: .pronto, title: "Pronto")
        let stateWithoutMaterial = ChatScreenState(kind: .vazio, badge: badge, hasMaterial: false)
        XCTAssertEqual(stateWithoutMaterial.emptyPlaceholderTitle, "Nenhum material neste projeto")
        XCTAssertTrue(stateWithoutMaterial.emptyPlaceholderSubtitle.localizedCaseInsensitiveContains("aba Material"))

        let stateWithMaterial = ChatScreenState(kind: .vazio, badge: badge, hasMaterial: true)
        XCTAssertEqual(stateWithMaterial.emptyPlaceholderTitle, "Pergunte sobre o seu projeto")
        XCTAssertTrue(stateWithMaterial.emptyPlaceholderSubtitle.contains("Respondo só com o material"))
    }
}
