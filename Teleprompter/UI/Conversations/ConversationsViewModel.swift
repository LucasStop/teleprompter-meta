import Foundation
import Observation

/// Estado puro de um item de conversa para renderização na lista (T07).
struct ConversationItemState: Identifiable, Sendable, Equatable {
    let id: UUID
    let title: String
    let formattedDate: String
    let messageCount: Int
    let formattedMessageCount: String
    let conversation: Conversation

    init(conversation: Conversation, calendar: Calendar = .current, now: Date = Date()) {
        self.id = conversation.id
        self.title = conversation.title
        self.conversation = conversation
        self.messageCount = conversation.messages.count
        self.formattedMessageCount = conversation.messages.count == 1 ? "1 msg" : "\(conversation.messages.count) msgs"
        self.formattedDate = Self.formatDate(conversation.updatedAt, calendar: calendar, now: now)
    }

    /// Formatação em português conforme o protótipo: Hoje, 14:20 | Ontem | 5 nov
    static func formatDate(_ date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateFormat = "HH:mm"
            return "Hoje, \(formatter.string(from: date))"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "Ontem"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "d MMM"
        let string = formatter.string(from: date).replacingOccurrences(of: ".", with: "")
        return string.lowercased()
    }
}

/// Estados da tela T07 (vazio e padrão, conforme design/prototypes/t07-conversas.html).
enum ConversationsScreenState: String, Sendable, Equatable {
    case vazio
    case padrao
}

/// Orquestra o estado da tela T07 Conversas (PRD US-14).
@MainActor
@Observable
final class ConversationsViewModel {
    var searchQuery: String = ""
    private(set) var rawConversations: [Conversation] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    let store: any ConversationStore
    let calendar: Calendar
    var nowProvider: @Sendable () -> Date

    init(
        store: any ConversationStore,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    /// Estado da tela conforme presença de conversas no armazenamento local.
    var state: ConversationsScreenState {
        rawConversations.isEmpty ? .vazio : .padrao
    }

    /// Lista filtrada de itens segundo a busca por título ou texto das mensagens.
    var items: [ConversationItemState] {
        let now = nowProvider()
        let all = rawConversations.map {
            ConversationItemState(conversation: $0, calendar: calendar, now: now)
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return all
        }

        return all.filter { item in
            if item.title.lowercased().contains(query) {
                return true
            }
            return item.conversation.messages.contains { msg in
                msg.text.lowercased().contains(query)
            }
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            rawConversations = try await store.list()
        } catch {
            errorMessage = "Falha ao carregar conversas salvas."
        }
        isLoading = false
    }

    func delete(id: UUID) async {
        do {
            try await store.delete(id: id)
            rawConversations.removeAll { $0.id == id }
        } catch {
            errorMessage = "Falha ao apagar conversa."
        }
    }

    func deleteAll() async {
        do {
            try await store.deleteAll()
            rawConversations.removeAll()
        } catch {
            errorMessage = "Falha ao apagar todas as conversas."
        }
    }
}
