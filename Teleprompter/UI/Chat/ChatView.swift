import SwiftUI

/// Aba principal de Chat da sessão (T02) no iPhone.
/// Apenas renderiza e delega ações; todo mapeamento de negócio vive em `ChatScreenState`.
struct ChatView: View {
    @Bindable var viewModel: ConversationViewModel
    var lens: Lens
    var initialComposerText: String?
    var onOpenConversations: (() -> Void)?
    var activeProjectName: String
    var onOpenProjects: (() -> Void)?

    @State private var composerText: String = ""
    @State private var isShowingLens: Bool = false

    init(
        viewModel: ConversationViewModel,
        lens: Lens,
        initialComposerText: String? = nil,
        onOpenConversations: (() -> Void)? = nil,
        activeProjectName: String = Project.defaultName,
        onOpenProjects: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.lens = lens
        self.initialComposerText = initialComposerText
        self.onOpenConversations = onOpenConversations
        self.activeProjectName = activeProjectName
        self.onOpenProjects = onOpenProjects
    }

    private var screenState: ChatScreenState {
        ChatScreenState(from: viewModel, composerText: composerText)
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBarView
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s2)
                .padding(.bottom, Spacing.s2)

            if let bannerState = screenState.banner {
                Banner(
                    style: bannerState.style,
                    title: bannerState.title,
                    message: bannerState.message,
                    actionTitle: bannerState.actionTitle,
                    action: {
                        if screenState.kind == .erro {
                            viewModel.state = .vazio
                        }
                    }
                )
                .padding(.horizontal, Spacing.s4)
                .padding(.bottom, Spacing.s2)
                .transition(.opacity)
            }

            chatAreaView

            composerSectionView
        }
        .background(Colors.background)
        .onAppear {
            if let initialComposerText, composerText.isEmpty {
                composerText = initialComposerText
            }
        }
        .sheet(isPresented: $isShowingLens) {
            SimulatedLensModalView(
                content: viewModel.lastLensContent ?? (lens as? SimulatedLens)?.content
            )
        }
    }

    // MARK: - Subviews

    /// Uma linha só (projeto, estado e atalhos) para sobrar altura ao chat.
    private var topBarView: some View {
        HStack(spacing: Spacing.s2) {
            ProjectChip(projectName: activeProjectName, action: onOpenProjects)
                .layoutPriority(1)
            StatusBadge(status: screenState.badge.status, title: screenState.badge.title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if let onOpenConversations {
                topIconButton(
                    systemName: "list.bullet",
                    label: "Abrir conversas",
                    identifier: "chat-conversas-button",
                    action: onOpenConversations
                )
            }
            topIconButton(
                systemName: "eyeglasses",
                label: "Abrir lente simulada",
                identifier: "chat-lens-button",
                action: { isShowingLens = true }
            )
        }
    }

    private func topIconButton(
        systemName: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(
            action: action,
            label: {
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Colors.foreground)
                    .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                    .background(Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Colors.border, lineWidth: Borders.standard)
                    )
            }
        )
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var chatAreaView: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    if screenState.showEmptyPlaceholder {
                        emptyPlaceholderView
                            .padding(.top, Spacing.s6)
                    } else {
                        LazyVStack(spacing: Spacing.s3) {
                            ForEach(screenState.messages) { item in
                                MessageBubble(
                                    role: item.role,
                                    text: item.text,
                                    bullets: item.bullets,
                                    sources: item.sources,
                                    caption: item.caption,
                                    isSentToLens: item.isSentToLens,
                                    isSourcesExpanded: item.isSourcesExpanded,
                                    maxBubbleWidth: geometry.size.width * 0.8
                                )
                                .id(item.id)
                            }
                        }
                        .padding(.horizontal, Spacing.s4)
                        .padding(.vertical, Spacing.s2)

                        // Folga para a pergunta nova poder subir ao topo mesmo com resposta curta.
                        Color.clear.frame(height: geometry.size.height * 0.7)
                    }
                }
                // Nova pergunta sobe ao topo; a resposta cresce abaixo sem puxar a rolagem.
                .onChange(of: screenState.lastQuestionId, { _, newId in
                    if let newId {
                        withAnimation {
                            proxy.scrollTo(newId, anchor: .top)
                        }
                    }
                })
            }
        }
    }

    private var emptyPlaceholderView: some View {
        ChatEmptyPlaceholderView(
            screenState: screenState,
            onAskQuestion: { askQuestion($0) }
        )
    }

    private var composerSectionView: some View {
        ChatComposerSectionView(
            text: $composerText,
            isListening: screenState.isListening,
            placeholder: screenState.composerPlaceholder,
            onToggleListening: { viewModel.toggleListening() },
            onSend: { sendCurrentText() }
        )
    }

    // MARK: - Actions

    private func sendCurrentText() {
        let textToSend = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else { return }
        composerText = ""
        askQuestion(textToSend)
    }

    private func askQuestion(_ text: String) {
        Task {
            await viewModel.ask(text)
        }
    }
}
