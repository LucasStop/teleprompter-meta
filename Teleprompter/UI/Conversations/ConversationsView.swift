import SwiftUI

/// Tela T07 Conversas salvas localmente no aparelho (PRD US-14, design/prototypes/t07-conversas.html).
struct ConversationsView: View {
    @Bindable var viewModel: ConversationsViewModel
    var onBack: () -> Void
    var onSelectConversation: (Conversation) -> Void

    @State private var showingDeleteAllConfirmation: Bool = false

    init(
        viewModel: ConversationsViewModel,
        onBack: @escaping () -> Void = {},
        onSelectConversation: @escaping (Conversation) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onSelectConversation = onSelectConversation
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, Spacing.s4)
                .padding(.top, Spacing.s4)
                .padding(.bottom, Spacing.s2)

            switch viewModel.state {
            case .vazio:
                emptyStateView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .padrao:
                standardStateView
            }
        }
        .background(Colors.background)
        .task {
            await viewModel.load()
        }
        .alert(
            "Apagar todas as conversas?",
            isPresented: $showingDeleteAllConfirmation,
            actions: {
                Button("Apagar todas", role: .destructive) {
                    Task {
                        await viewModel.deleteAll()
                    }
                }
                Button("Cancelar", role: .cancel) {}
            },
            message: {
                Text("Esta ação não pode ser desfeita. Todas as conversas salvas neste aparelho serão apagadas.")
            }
        )
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Text("Conversas")
                .font(Typography.h1)
                .foregroundStyle(Colors.foreground)
                .accessibilityIdentifier("conversas-title")

            Spacer()

            Button(
                action: onBack,
                label: {
                    Text("Chat")
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
            .accessibilityLabel("Voltar para o Chat")
            .accessibilityIdentifier("conversas-back-button")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.s3) {
            Spacer()

            Text("Nenhuma conversa salva")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Colors.foreground)
                .multilineTextAlignment(.center)

            Text("As conversas do chat aparecem aqui, só neste aparelho.")
                .font(Typography.bodySm)
                .foregroundStyle(Colors.muted)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, Spacing.s4)
        .padding(.vertical, Spacing.s6)
        .accessibilityElement(children: .combine)
    }

    private var standardStateView: some View {
        VStack(spacing: Spacing.s3) {
            searchFieldView
                .padding(.horizontal, Spacing.s4)

            ScrollView {
                VStack(spacing: Spacing.s2) {
                    conversationsCardView
                        .padding(.horizontal, Spacing.s4)

                    captionView
                        .padding(.horizontal, Spacing.s4)
                }
                .padding(.top, Spacing.s1)
                .padding(.bottom, Spacing.s4)
            }

            deleteAllButtonView
                .padding(.horizontal, Spacing.s4)
                .padding(.bottom, Spacing.s3)
        }
    }

    private var searchFieldView: some View {
        HStack(spacing: Spacing.s2) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Colors.muted)
                .font(.system(size: 15))

            TextField("Buscar nas conversas", text: $viewModel.searchQuery)
                .font(Typography.body)
                .foregroundStyle(Colors.foreground)
                .accessibilityLabel("Buscar nas conversas")

            if !viewModel.searchQuery.isEmpty {
                Button(
                    action: { viewModel.searchQuery = "" },
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Colors.muted)
                            .font(.system(size: 15))
                    }
                )
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, Spacing.s3)
        .frame(minHeight: Spacing.minTouchTarget)
        .background(Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.sm)
                .stroke(Colors.border, lineWidth: Borders.standard)
        )
    }

    private var conversationsCardView: some View {
        VStack(spacing: 0) {
            if viewModel.items.isEmpty {
                Text("Nenhuma conversa encontrada")
                    .font(Typography.bodySm)
                    .foregroundStyle(Colors.muted)
                    .padding(Spacing.s4)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .background(Colors.border)
                    }

                    conversationItemRow(item)
                }
            }
        }
        .background(Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.md)
                .stroke(Colors.border, lineWidth: Borders.standard)
        )
    }

    private func conversationItemRow(_ item: ConversationItemState) -> some View {
        Button(
            action: { onSelectConversation(item.conversation) },
            label: {
                HStack(alignment: .center, spacing: Spacing.s3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(Typography.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Colors.foreground)
                            .lineLimit(1)

                        Text(item.formattedDate)
                            .font(Typography.caption)
                            .foregroundStyle(Colors.muted)
                    }

                    Spacer()

                    Text(item.formattedMessageCount)
                        .font(Typography.bodySm)
                        .foregroundStyle(Colors.muted)
                }
                .padding(.horizontal, Spacing.s4)
                .padding(.vertical, Spacing.s3)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
        )
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    await viewModel.delete(id: item.id)
                }
            } label: {
                Label("Apagar conversa", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.formattedDate), \(item.formattedMessageCount)")
        .accessibilityHint("Toque para abrir a conversa ou segure para opções.")
    }

    private var captionView: some View {
        HStack {
            Text("Deslize para apagar uma conversa. Nada sai do aparelho.")
                .font(Typography.caption)
                .foregroundStyle(Colors.muted)
            Spacer()
        }
    }

    private var deleteAllButtonView: some View {
        Button(
            action: { showingDeleteAllConfirmation = true },
            label: {
                Text("Apagar todas as conversas")
                    .font(Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Colors.danger)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.md)
                            .stroke(Colors.danger, lineWidth: Borders.standard)
                    )
            }
        )
        .buttonStyle(.plain)
        .accessibilityLabel("Apagar todas as conversas")
        .accessibilityIdentifier("conversas-delete-all-button")
    }
}

// MARK: - Previews

#Preview("Conversas - Padrão (Claro)") {
    let now = Date()
    let conv1 = Conversation(
        title: "Por que Swift nativo e não Flutter?",
        createdAt: now,
        updatedAt: now,
        messages: Array(repeating: Message(role: .question, text: "Q"), count: 8)
    )
    let conv2 = Conversation(
        title: "Ensaio da banca",
        createdAt: now.addingTimeInterval(-86400),
        updatedAt: now.addingTimeInterval(-86400),
        messages: Array(repeating: Message(role: .question, text: "Q"), count: 34)
    )
    let conv3 = Conversation(
        title: "Qual o problema que o app resolve?",
        createdAt: now.addingTimeInterval(-86400 * 4),
        updatedAt: now.addingTimeInterval(-86400 * 4),
        messages: Array(repeating: Message(role: .question, text: "Q"), count: 4)
    )

    let store = InMemoryConversationStore(initialConversations: [conv1, conv2, conv3])
    let viewModel = ConversationsViewModel(store: store)

    return ConversationsView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Conversas - Padrão (Escuro)") {
    let now = Date()
    let conv1 = Conversation(
        title: "Por que Swift nativo e não Flutter?",
        createdAt: now,
        updatedAt: now,
        messages: Array(repeating: Message(role: .question, text: "Q"), count: 8)
    )
    let conv2 = Conversation(
        title: "Ensaio da banca",
        createdAt: now.addingTimeInterval(-86400),
        updatedAt: now.addingTimeInterval(-86400),
        messages: Array(repeating: Message(role: .question, text: "Q"), count: 34)
    )
    let conv3 = Conversation(
        title: "Qual o problema que o app resolve?",
        createdAt: now.addingTimeInterval(-86400 * 4),
        updatedAt: now.addingTimeInterval(-86400 * 4),
        messages: Array(repeating: Message(role: .question, text: "Q"), count: 4)
    )

    let store = InMemoryConversationStore(initialConversations: [conv1, conv2, conv3])
    let viewModel = ConversationsViewModel(store: store)

    return ConversationsView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}

#Preview("Conversas - Vazio (Claro)") {
    let store = InMemoryConversationStore()
    let viewModel = ConversationsViewModel(store: store)

    return ConversationsView(viewModel: viewModel)
        .preferredColorScheme(.light)
}

#Preview("Conversas - Vazio (Escuro)") {
    let store = InMemoryConversationStore()
    let viewModel = ConversationsViewModel(store: store)

    return ConversationsView(viewModel: viewModel)
        .preferredColorScheme(.dark)
}
