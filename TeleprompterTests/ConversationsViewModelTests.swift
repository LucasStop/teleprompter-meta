import Foundation
import XCTest
@testable import Teleprompter

@MainActor
final class ConversationsViewModelTests: XCTestCase {
    private var store: InMemoryConversationStore!
    private var calendar: Calendar!
    private var baseNow: Date!

    override func setUp() async throws {
        try await super.setUp()
        store = InMemoryConversationStore()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: -3 * 3600)!
        cal.locale = Locale(identifier: "pt_BR")
        self.calendar = cal

        // Data fixa de referência: 2026-11-09 15:30:00 -03:00
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 9
        components.hour = 15
        components.minute = 30
        self.baseNow = cal.date(from: components)!
    }

    private func makeViewModel() -> ConversationsViewModel {
        let fixedNow = self.baseNow!
        return ConversationsViewModel(
            store: store,
            calendar: calendar,
            nowProvider: { fixedNow }
        )
    }

    func testDateFormattingCases() {
        let now = baseNow!

        // Hoje, 14:20
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        todayComponents.hour = 14
        todayComponents.minute = 20
        let todayDate = calendar.date(from: todayComponents)!
        let formattedToday = ConversationItemState.formatDate(todayDate, calendar: calendar, now: now)
        XCTAssertEqual(formattedToday, "Hoje, 14:20")

        // Ontem
        let yesterdayDate = calendar.date(byAdding: .day, value: -1, to: now)!
        let formattedYesterday = ConversationItemState.formatDate(yesterdayDate, calendar: calendar, now: now)
        XCTAssertEqual(formattedYesterday, "Ontem")

        // Data anterior: 5 nov
        var pastComponents = DateComponents()
        pastComponents.year = 2026
        pastComponents.month = 11
        pastComponents.day = 5
        pastComponents.hour = 10
        pastComponents.minute = 0
        let pastDate = calendar.date(from: pastComponents)!
        let formattedPast = ConversationItemState.formatDate(pastDate, calendar: calendar, now: now)
        XCTAssertEqual(formattedPast, "5 nov")
    }

    func testViewModelEmptyState() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .vazio)
        XCTAssertTrue(viewModel.items.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testViewModelStandardStateWithConversations() async throws {
        let now = baseNow!

        let conv1 = Conversation(
            id: UUID(),
            title: "Por que Swift nativo e não Flutter?",
            createdAt: now,
            updatedAt: now,
            messages: [
                Message(role: .question, text: "Por que Swift nativo e não Flutter?"),
                Message(role: .answer, text: "Módulos DAT SDK...")
            ]
        )

        let conv2 = Conversation(
            id: UUID(),
            title: "Ensaio da banca",
            createdAt: now.addingTimeInterval(-86400),
            updatedAt: now.addingTimeInterval(-86400),
            messages: Array(repeating: Message(role: .question, text: "P"), count: 34)
        )

        try await store.save(conv1)
        try await store.save(conv2)

        let viewModel = makeViewModel()
        await viewModel.load()

        XCTAssertEqual(viewModel.state, .padrao)
        XCTAssertEqual(viewModel.items.count, 2)

        let item1 = viewModel.items[0]
        XCTAssertEqual(item1.title, "Por que Swift nativo e não Flutter?")
        XCTAssertEqual(item1.formattedDate, "Hoje, 15:30")
        XCTAssertEqual(item1.messageCount, 2)
        XCTAssertEqual(item1.formattedMessageCount, "2 msgs")

        let item2 = viewModel.items[1]
        XCTAssertEqual(item2.title, "Ensaio da banca")
        XCTAssertEqual(item2.formattedDate, "Ontem")
        XCTAssertEqual(item2.messageCount, 34)
        XCTAssertEqual(item2.formattedMessageCount, "34 msgs")
    }

    func testViewModelSearchQueryFiltering() async throws {
        let now = baseNow!

        let conv1 = Conversation(
            title: "Por que Swift nativo e não Flutter?",
            createdAt: now,
            updatedAt: now,
            messages: [Message(role: .question, text: "Swift nativo")]
        )
        let conv2 = Conversation(
            title: "Ensaio da banca",
            createdAt: now,
            updatedAt: now,
            messages: [Message(role: .question, text: "Treino")]
        )
        let conv3 = Conversation(
            title: "Qual o problema que o app resolve?",
            createdAt: now,
            updatedAt: now,
            messages: [Message(role: .question, text: "Problema")]
        )

        try await store.save(conv1)
        try await store.save(conv2)
        try await store.save(conv3)

        let viewModel = makeViewModel()
        await viewModel.load()

        XCTAssertEqual(viewModel.items.count, 3)

        // Busca por palavra-chave no título
        viewModel.searchQuery = "swift"
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.title, "Por que Swift nativo e não Flutter?")

        // Busca por conteúdo de mensagem
        viewModel.searchQuery = "treino"
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.title, "Ensaio da banca")

        // Busca sem correspondência
        viewModel.searchQuery = "inexistente"
        XCTAssertTrue(viewModel.items.isEmpty)
        // O estado geral continua .padrao porque existem conversas no banco, apenas a busca filtrou
        XCTAssertEqual(viewModel.state, .padrao)

        // Limpa busca
        viewModel.searchQuery = ""
        XCTAssertEqual(viewModel.items.count, 3)
    }

    func testViewModelDeleteSingleConversation() async throws {
        let now = baseNow!
        let conv1 = Conversation(title: "C1", createdAt: now, updatedAt: now, messages: [])
        let conv2 = Conversation(title: "C2", createdAt: now, updatedAt: now, messages: [])

        try await store.save(conv1)
        try await store.save(conv2)

        let viewModel = makeViewModel()
        await viewModel.load()
        XCTAssertEqual(viewModel.items.count, 2)

        await viewModel.delete(id: conv1.id)
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.id, conv2.id)

        let storeItems = try await store.list()
        XCTAssertEqual(storeItems.count, 1)
    }

    func testViewModelDeleteAllConversations() async throws {
        let now = baseNow!
        for idx in 1...3 {
            let conv = Conversation(title: "C\(idx)", createdAt: now, updatedAt: now, messages: [])
            try await store.save(conv)
        }

        let viewModel = makeViewModel()
        await viewModel.load()
        XCTAssertEqual(viewModel.state, .padrao)
        XCTAssertEqual(viewModel.items.count, 3)

        await viewModel.deleteAll()
        XCTAssertEqual(viewModel.state, .vazio)
        XCTAssertTrue(viewModel.items.isEmpty)

        let storeItems = try await store.list()
        XCTAssertTrue(storeItems.isEmpty)
    }
}
