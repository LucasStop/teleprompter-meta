import SwiftUI

/// Aba principal de Chat da sessão (T02) no iPhone.
/// Apenas renderiza e delega ações; todo mapeamento de negócio vive em `ChatScreenState`.
struct ChatView: View {
    @Bindable var viewModel: ConversationViewModel
    var lens: Lens
    var initialComposerText: String?
    var onOpenConversations: (() -> Void)?

    @State private var composerText: String = ""
    @State private var isShowingLens: Bool = false

    init(
        viewModel: ConversationViewModel,
        lens: Lens,
        initialComposerText: String? = nil,
        onOpenConversations: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.lens = lens
        self.initialComposerText = initialComposerText
        self.onOpenConversations = onOpenConversations
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
        HStack {
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
        VStack(spacing: Spacing.s3) {
            Text("Pergunte sobre o seu material")
                .font(Typography.h2)
                .foregroundStyle(Colors.foreground)
                .multilineTextAlignment(.center)

            Text("Respondo só com o material que você importou. Digite, toque no microfone ou ligue a escuta contínua.")
                .font(Typography.bodySm)
                .foregroundStyle(Colors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.s4)

            VStack(spacing: Spacing.s2) {
                ForEach(screenState.suggestionChips, id: \.self) { chip in
                    Button(
                        action: { askQuestion(chip) },
                        label: {
                            Text(chip)
                                .font(Typography.bodySm)
                                .foregroundStyle(Colors.foreground)
                                .padding(.horizontal, Spacing.s3)
                                .padding(.vertical, Spacing.s2)
                                .frame(minHeight: Spacing.minTouchTarget)
                                .background(Colors.surface)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Colors.border, lineWidth: Borders.standard)
                                )
                        }
                    )
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sugestão de pergunta: \(chip)")
                }
            }
            .padding(.top, Spacing.s2)
        }
        .padding(.horizontal, Spacing.s4)
        .frame(maxWidth: .infinity)
    }

    private var composerSectionView: some View {
        VStack(spacing: Spacing.s2) {
            HStack {
                Toggle(isOn: Binding(
                    get: { viewModel.isListening },
                    set: { _ in viewModel.toggleListening() }
                )) {
                    Text("Escuta contínua")
                        .font(Typography.bodySm)
                        .foregroundStyle(Colors.foreground)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(SwitchToggleStyle(tint: Colors.primary))
                .accessibilityLabel("Escuta contínua")
                .accessibilityHint(viewModel.isListening ? "Desativar escuta contínua" : "Ativar escuta contínua")
                .frame(minHeight: Spacing.minTouchTarget)

                Spacer()

                Text("Só material importado")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.muted)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, Spacing.s4)

            ComposerField(
                text: $composerText,
                placeholder: screenState.composerPlaceholder,
                isListening: screenState.isListening,
                onSend: { sendCurrentText() },
                onMicTapped: { viewModel.toggleListening() }
            )
            .accessibilityIdentifier("chat-composer-field")
            .padding(.horizontal, Spacing.s4)
            .padding(.bottom, Spacing.s3)
        }
        .background(Colors.surface)
        .overlay(
            Rectangle()
                .frame(height: Borders.standard)
                .foregroundStyle(Colors.border),
            alignment: .top
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
