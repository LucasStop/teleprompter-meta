import Foundation
import SwiftUI

extension Banner.Style: Equatable {}

/// Estado puro da tela de Chat (T02) desacoplado de SwiftUI.
struct ChatScreenState: Equatable, Sendable {
    enum Kind: String, CaseIterable, Equatable, Sendable {
        case vazio
        case digitando
        case escuta
        case pensando
        case conversa
        case semMaterial
        case erro
        case desconectado
    }

    struct BannerState: Equatable, Sendable {
        var style: Banner.Style
        var title: String
        var message: String
        var actionTitle: String?

        init(
            style: Banner.Style,
            title: String,
            message: String,
            actionTitle: String? = nil
        ) {
            self.style = style
            self.title = title
            self.message = message
            self.actionTitle = actionTitle
        }
    }

    struct BadgeState: Equatable, Sendable {
        var status: StatusBadge.Status
        var title: String
    }

    struct MessageItem: Identifiable, Equatable, Sendable {
        let id: String
        var role: MessageBubble.Role
        var text: String
        var bullets: [String]
        var sources: [String]
        var caption: String?
        var isPartial: Bool

        init(
            id: String = UUID().uuidString,
            role: MessageBubble.Role,
            text: String,
            bullets: [String] = [],
            sources: [String] = [],
            caption: String? = nil,
            isPartial: Bool = false
        ) {
            self.id = id
            self.role = role
            self.text = text
            self.bullets = bullets
            self.sources = sources
            self.caption = caption
            self.isPartial = isPartial
        }
    }

    var kind: Kind
    var badge: BadgeState
    var banner: BannerState?
    var messages: [MessageItem]
    var showEmptyPlaceholder: Bool
    var isListening: Bool
    var composerPlaceholder: String
    var suggestionChips: [String]

    init(
        kind: Kind,
        badge: BadgeState,
        banner: BannerState? = nil,
        messages: [MessageItem] = [],
        showEmptyPlaceholder: Bool = false,
        isListening: Bool = false,
        composerPlaceholder: String = "Pergunte sobre o seu material",
        suggestionChips: [String] = [
            "Qual o problema que o app resolve?",
            "Como funciona a busca?"
        ]
    ) {
        self.kind = kind
        self.badge = badge
        self.banner = banner
        self.messages = messages
        self.showEmptyPlaceholder = showEmptyPlaceholder
        self.isListening = isListening
        self.composerPlaceholder = composerPlaceholder
        self.suggestionChips = suggestionChips
    }
}

// MARK: - Factory / Mapeamento

extension ChatScreenState {
    @MainActor
    init(from viewModel: ConversationViewModel, composerText: String = "") {
        let isTyping = !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let determinedKind = Self.determineKind(viewModel: viewModel, isTyping: isTyping)
        let (badgeState, bannerState) = Self.makeBadgeAndBanner(
            for: determinedKind,
            errorMessage: viewModel.errorMessage
        )

        self.kind = determinedKind
        self.badge = badgeState
        self.banner = bannerState
        self.isListening = viewModel.isListening
        self.composerPlaceholder = (determinedKind == .escuta) ? "Ouvindo..." : "Pergunte sobre o seu material"
        self.showEmptyPlaceholder = (determinedKind == .vazio || determinedKind == .digitando)
            && viewModel.messages.isEmpty
        self.suggestionChips = [
            "Qual o problema que o app resolve?",
            "Como funciona a busca?"
        ]
        self.messages = Self.makeMessages(for: determinedKind, viewModel: viewModel)
    }

    @MainActor
    private static func determineKind(viewModel: ConversationViewModel, isTyping: Bool) -> Kind {
        if !viewModel.isGlassesConnected || viewModel.state == .desconectado {
            return .desconectado
        }
        if viewModel.state == .erro {
            return .erro
        }
        if viewModel.isListening || viewModel.state == .ouvindo {
            return .escuta
        }
        if viewModel.state == .pensando {
            return .pensando
        }
        if viewModel.state == .semMaterial {
            return .semMaterial
        }
        if !viewModel.messages.isEmpty {
            return .conversa
        }
        return isTyping ? .digitando : .vazio
    }

    private static func makeBadgeAndBanner(
        for kind: Kind,
        errorMessage: String?
    ) -> (BadgeState, BannerState?) {
        switch kind {
        case .vazio, .digitando:
            return (BadgeState(status: .pronto, title: "Pronto"), nil)
        case .escuta:
            return (BadgeState(status: .ativo, title: "Ouvindo a banca"), nil)
        case .pensando:
            return (BadgeState(status: .ativo, title: "Buscando no material"), nil)
        case .conversa:
            return (BadgeState(status: .ok, title: "Resposta enviada à lente"), nil)
        case .semMaterial:
            return (BadgeState(status: .pronto, title: "Sem resposta no material"), nil)
        case .erro:
            let defaultMsg = "Respondendo só com as notas de Q&A. Verifique a rede e tente de novo."
            let banner = BannerState(
                style: .danger,
                title: "Sem conexão",
                message: errorMessage ?? defaultMsg
            )
            return (BadgeState(status: .erro, title: "Sem conexão"), banner)
        case .desconectado:
            let banner = BannerState(
                style: .warning,
                title: "Óculos desconectados",
                message: "A resposta aparece só no iPhone. Reconecte pelo app Meta AI."
            )
            return (BadgeState(status: .erro, title: "Óculos desconectados"), banner)
        }
    }

    @MainActor
    private static func makeMessages(
        for kind: Kind,
        viewModel: ConversationViewModel
    ) -> [MessageItem] {
        var items: [MessageItem] = []

        if kind == .escuta && viewModel.messages.isEmpty {
            items.append(
                MessageItem(
                    role: .answer,
                    text: "Escuta contínua ligada. Detecto o fim da pergunta e respondo sozinho."
                )
            )
        }

        for msg in viewModel.messages {
            items.append(MessageItem(role: .question, text: msg.question))
            items.append(makeAnswerItem(for: msg))
        }

        if kind == .pensando {
            if let pending = viewModel.pendingQuestion {
                items.append(MessageItem(role: .question, text: pending))
            }
            items.append(
                MessageItem(
                    role: .answer,
                    text: "Buscando no material...",
                    caption: "Buscando resposta"
                )
            )
        }

        if kind == .escuta && !viewModel.currentTranscript.isEmpty {
            items.append(
                MessageItem(
                    role: .partial,
                    text: viewModel.currentTranscript,
                    caption: "Pergunta parcial",
                    isPartial: true
                )
            )
        }

        return items
    }

    private static func makeAnswerItem(for msg: ChatMessage) -> MessageItem {
        if msg.answer == AnswerPipeline.notFoundMessage {
            return MessageItem(
                role: .answer,
                text: AnswerPipeline.notFoundMessage,
                bullets: ["Importe uma nota ou documento sobre o assunto, ou reformule a pergunta."],
                sources: [],
                caption: "Nada acima do limiar de similaridade"
            )
        }

        let (intro, bullets) = parseBullets(from: msg.answer)
        let caption = formatCaption(sources: msg.sources, latency: msg.latency)
        return MessageItem(
            role: .answer,
            text: intro,
            bullets: bullets,
            sources: msg.sources.map(\.path),
            caption: caption
        )
    }

    private static func parseBullets(from answer: String) -> (intro: String, bullets: [String]) {
        let lines = answer.components(separatedBy: .newlines)
        var bullets: [String] = []
        var introLines: [String] = []
        let bulletChars: Set<Character> = ["•", "-", "*"]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let first = trimmed.first, bulletChars.contains(first) {
                let cleaned = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                bullets.append(cleaned)
            } else {
                if bullets.isEmpty {
                    introLines.append(trimmed)
                } else {
                    bullets.append(trimmed)
                }
            }
        }

        return (introLines.joined(separator: "\n"), bullets)
    }

    private static func formatCaption(sources: [SourceRef], latency: LatencyReport?) -> String? {
        guard let latency else {
            if sources.contains(where: { $0.path.contains("qa/") }) {
                return "nota de Q&A"
            }
            return sources.first.map { "trecho de \((($0.path as NSString).lastPathComponent))" }
        }

        let latencyStr = String(format: "%.1f s", latency.totalSeconds)
            .replacingOccurrences(of: ".", with: ",")

        if sources.contains(where: { $0.path.contains("qa/") }) {
            return "nota de Q&A · \(latencyStr)"
        }
        if let first = sources.first {
            let fileName = (first.path as NSString).lastPathComponent
            let displayName = fileName.replacingOccurrences(of: ".md", with: "")
            return "trecho de \(displayName) · \(latencyStr)"
        }
        return latencyStr
    }
}
