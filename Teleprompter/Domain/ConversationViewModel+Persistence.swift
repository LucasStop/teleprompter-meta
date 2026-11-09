import Foundation

// MARK: - Conversas e Persistência

extension ConversationViewModel {
    func loadConversation(_ conversation: Conversation) {
        self.currentConversationId = conversation.id
        var chatMessages: [ChatMessage] = []
        var currentQuestion: Message?

        for msg in conversation.messages {
            if msg.role == .question {
                currentQuestion = msg
            } else if msg.role == .answer {
                let latency = msg.latencyMs.map {
                    LatencyReport(retrievalSeconds: 0, totalSeconds: Double($0) / 1000.0)
                }
                chatMessages.append(
                    ChatMessage(
                        id: msg.id, question: currentQuestion?.text ?? "",
                        answer: msg.text, sources: msg.sources, latency: latency
                    )
                )
                currentQuestion = nil
            }
        }

        if let pendingQ = currentQuestion {
            chatMessages.append(ChatMessage(id: pendingQ.id, question: pendingQ.text, answer: "", sources: []))
        }

        self.messages = chatMessages
        self.state = chatMessages.isEmpty ? .vazio : .respondido
    }

    func saveToConversationStore(
        question: String,
        answer: String,
        sources: [SourceRef],
        latency: LatencyReport?
    ) async {
        guard let conversationStore else { return }

        let convId = currentConversationId ?? UUID()
        currentConversationId = convId

        let activeProject = settingsStore?.load().activeProjectId ?? Project.defaultId

        let latencyMs = latency.map { Int($0.totalSeconds * 1000.0) }
        let qMessage = Message(role: .question, text: question, sources: [], latencyMs: nil, createdAt: Date())
        let aMessage = Message(role: .answer, text: answer, sources: sources, latencyMs: latencyMs, createdAt: Date())

        do {
            var conv = try await conversationStore.load(id: convId) ?? Conversation(
                id: convId, title: Conversation.deriveTitle(from: question),
                projectId: activeProject,
                createdAt: Date(), updatedAt: Date(), messages: []
            )
            conv.projectId = activeProject
            conv.updatedAt = Date()
            conv.messages.append(qMessage)
            conv.messages.append(aMessage)
            try await conversationStore.save(conv)
        } catch {
            // Falha ao salvar não derruba o chat
        }
    }
}
