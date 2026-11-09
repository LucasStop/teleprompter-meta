import Foundation

/// Estado puro da tela de Ensaio (T05) desacoplado de SwiftUI.
struct EnsaioScreenState: Sendable, Equatable {
    enum Kind: String, CaseIterable, Sendable, Equatable {
        case vazio
        case rodando
        case padrao
        case erro
    }

    struct Running: Sendable, Equatable {
        var current: Int
        var total: Int
        var currentQuestionTitle: String
        var progress: Double

        init(
            current: Int,
            total: Int,
            currentQuestionTitle: String,
            progress: Double
        ) {
            self.current = current
            self.total = total
            self.currentQuestionTitle = currentQuestionTitle
            self.progress = progress
        }

        var badgeText: String {
            "Ensaiando \(current) de \(total)"
        }
    }

    struct ErrorState: Sendable, Equatable {
        var title: String
        var message: String
        var actionTitle: String?

        init(title: String, message: String, actionTitle: String? = nil) {
            self.title = title
            self.message = message
            self.actionTitle = actionTitle
        }
    }

    var kind: Kind
    var summary: EnsaioRunSummary?
    var questions: [EnsaioQuestionResult]
    var running: Running?
    var error: ErrorState?

    init(
        kind: Kind,
        summary: EnsaioRunSummary? = nil,
        questions: [EnsaioQuestionResult] = [],
        running: Running? = nil,
        error: ErrorState? = nil
    ) {
        self.kind = kind
        self.summary = summary
        self.questions = questions
        self.running = running
        self.error = error
    }

    static var vazio: EnsaioScreenState {
        EnsaioScreenState(kind: .vazio)
    }

    static func rodando(current: Int, total: Int, questionTitle: String) -> EnsaioScreenState {
        let progress = total > 0 ? Double(current) / Double(total) : 0
        return EnsaioScreenState(
            kind: .rodando,
            running: Running(
                current: current,
                total: total,
                currentQuestionTitle: questionTitle,
                progress: progress
            )
        )
    }

    static func padrao(summary: EnsaioRunSummary, questions: [EnsaioQuestionResult]) -> EnsaioScreenState {
        EnsaioScreenState(
            kind: .padrao,
            summary: summary,
            questions: questions
        )
    }

    static func erro(title: String, message: String, actionTitle: String? = nil) -> EnsaioScreenState {
        EnsaioScreenState(
            kind: .erro,
            error: ErrorState(title: title, message: message, actionTitle: actionTitle)
        )
    }
}
