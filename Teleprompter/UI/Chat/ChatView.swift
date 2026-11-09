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
            headerView
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s4)
                .padding(.bottom, Spacing.s2)

            badgeView
                .padding(.horizontal, Spacing.s4)
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

    private var headerView: some View {
        HStack(spacing: Spacing.s2) {
            Text("Chat")
                .font(Typography.h1)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("chat-title")

            Spacer()

            if let onOpenConversations {
                Button(
                    action: onOpenConversations,
                    label: {
                        Text("Conversas")
                            .font(Typography.bodySm)
                            .fontWeight(.medium)
                            .foregroundStyle(Colors.foreground)
                            .padding(.horizontal, Spacing.s3)
                            .frame(minHeight: Spacing.minTouchTarget)
                            .background(Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.sm)
                                    .stroke(Colors.border, lineWidth: Borders.standard)
                            )
                    }
                )
                .buttonStyle(.plain)
                .accessibilityLabel("Abrir conversas")
                .accessibilityIdentifier("chat-conversas-button")
            }

            Button(
                action: { isShowingLens = true },
                label: {
                    HStack(spacing: Spacing.s1) {
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 15, weight: .medium))
                        Text("Lente")
                            .font(Typography.bodySm)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Colors.foreground)
                    .padding(.horizontal, Spacing.s3)
                    .frame(minHeight: Spacing.minTouchTarget)
                    .background(Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .stroke(Colors.border, lineWidth: Borders.standard)
                    )
                }
            )
            .buttonStyle(.plain)
            .accessibilityLabel("Abrir lente simulada")
            .accessibilityIdentifier("chat-lens-button")
        }
    }

    private var badgeView: some View {
        HStack(spacing: Spacing.s2) {
            ProjectChip(
                projectName: activeProjectName,
                action: onOpenProjects
            )
            StatusBadge(
                status: screenState.badge.status,
                title: screenState.badge.title
            )
            Spacer()
        }
    }

    private var chatAreaView: some View {
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
                                caption: item.caption
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s2)
                }
            }
            // Rola ao perguntar, ao chegar a resposta e a cada trecho do streaming.
            .onChange(of: screenState.scrollSignature, { _, _ in
                if let lastId = screenState.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            })
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
