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
                        }
                    )
                } else {
                    ChatView(
                        viewModel: environment.conversationViewModel,
                        lens: environment.lens,
                        onOpenConversations: {
                            isShowingConversations = true
                        }
                    )
                }
            }
            .tabItem {
                Label(AppTab.chat.title, systemImage: AppTab.chat.iconName)
            }
            .tag(AppTab.chat)

            MaterialView(viewModel: environment.materialViewModel)
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
    }

    private func openConversation(_ conversation: Conversation) {
        var chatMessages: [ChatMessage] = []
        var currentQuestion: Message?

        for msg in conversation.messages {
            if msg.role == .question {
                currentQuestion = msg
            } else if msg.role == .answer {
                let qText = currentQuestion?.text ?? ""
                let latencyReport = msg.latencyMs.map {
                    LatencyReport(
                        retrievalSeconds: 0,
                        totalSeconds: Double($0) / 1000.0
                    )
                }
                chatMessages.append(
                    ChatMessage(
                        id: msg.id,
                        question: qText,
                        answer: msg.text,
                        sources: msg.sources,
                        latency: latencyReport
                    )
                )
                currentQuestion = nil
            }
        }

        if let pendingQ = currentQuestion {
            chatMessages.append(
                ChatMessage(
                    id: pendingQ.id,
                    question: pendingQ.text,
                    answer: "",
                    sources: []
                )
            )
        }

        environment.conversationViewModel.messages = chatMessages
        environment.conversationViewModel.state = chatMessages.isEmpty ? .vazio : .respondido
    }
}

#Preview {
    RootTabView()
}
