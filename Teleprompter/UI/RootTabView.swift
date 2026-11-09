import SwiftUI

/// Abas da aplicação (DESIGN.md 4).
public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case chat = "Chat"
    case material = "Material"
    case ensaio = "Ensaio"
    case ajustes = "Ajustes"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public var iconName: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .material: return "doc.text"
        case .ensaio: return "waveform"
        case .ajustes: return "gearshape"
        }
    }
}

/// Casca principal com 4 abas inferiores (DESIGN.md 4/5).
public struct RootTabView: View {
    public static let tabs: [AppTab] = [.chat, .material, .ensaio, .ajustes]

    @State private var selectedTab: AppTab = .chat
    @State private var isShowingConversations: Bool = false
    @State private var isShowingProjectsSheet: Bool = false
    private let environment: AppEnvironment

    public init() {
        self.environment = AppEnvironment()
    }

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            Group {
                if isShowingConversations {
                    ConversationsView(
                        viewModel: environment.conversationsViewModel,
                        onBack: {
                            isShowingConversations = false
                        },
                        onSelectConversation: { conversation in
                            openConversation(conversation)
                            isShowingConversations = false
                        },
                        activeProjectName: environment.projectsViewModel.activeProjectName,
                        onOpenProjects: {
                            isShowingProjectsSheet = true
                        }
                    )
                } else {
                    ChatView(
                        viewModel: environment.conversationViewModel,
                        lens: environment.lens,
                        onOpenConversations: {
                            isShowingConversations = true
                        },
                        activeProjectName: environment.projectsViewModel.activeProjectName,
                        onOpenProjects: {
                            isShowingProjectsSheet = true
                        }
                    )
                }
            }
            .tabItem {
                Label(AppTab.chat.title, systemImage: AppTab.chat.iconName)
            }
            .tag(AppTab.chat)

            MaterialView(
                viewModel: environment.materialViewModel,
                activeProjectName: environment.projectsViewModel.activeProjectName,
                onOpenProjects: {
                    isShowingProjectsSheet = true
                }
            )
            .tabItem {
                Label(AppTab.material.title, systemImage: AppTab.material.iconName)
            }
            .tag(AppTab.material)

            EnsaioView(viewModel: environment.ensaioViewModel)
                .tabItem {
                    Label(AppTab.ensaio.title, systemImage: AppTab.ensaio.iconName)
                }
                .tag(AppTab.ensaio)

            SettingsView(viewModel: environment.settingsViewModel)
                .tabItem {
                    Label(AppTab.ajustes.title, systemImage: AppTab.ajustes.iconName)
                }
                .tag(AppTab.ajustes)
        }
        .tint(Colors.primary)
        .sheet(isPresented: $isShowingProjectsSheet) {
            ProjectsSheetView(viewModel: environment.projectsViewModel)
        }
    }

    private func openConversation(_ conversation: Conversation) {
        environment.conversationViewModel.loadConversation(conversation)
    }
}

#Preview {
    RootTabView()
}
