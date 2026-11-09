import Foundation

/// Relógio injetável para medição determinística de latência e detecção de silêncio.
protocol Clock: Sendable {
    func now() -> ContinuousClock.Instant
}

/// Relógio do sistema baseado no `ContinuousClock`.
struct SystemClock: Clock {
    func now() -> ContinuousClock.Instant {
        ContinuousClock.now
    }
}

extension Duration {
    var seconds: Double {
        let (sec, atto) = self.components
        return Double(sec) + Double(atto) * 1e-18
    }
}

/// Relatório de latência por etapa (PRD US-04, ARCHITECTURE seção 8).
/// Não contém nenhum texto de fala ou pergunta/resposta (privacidade por design).
struct LatencyReport: Sendable, Equatable {
    var sttFinal: Duration?
    var retrieval: Duration
    var firstToken: Duration?
    var total: Duration

    init(
        sttFinal: Duration? = nil,
        retrieval: Duration,
        firstToken: Duration? = nil,
        total: Duration
    ) {
        self.sttFinal = sttFinal
        self.retrieval = retrieval
        self.firstToken = firstToken
        self.total = total
    }

    init(
        sttFinalSeconds: Double? = nil,
        retrievalSeconds: Double,
        firstTokenSeconds: Double? = nil,
        totalSeconds: Double
    ) {
        self.sttFinal = sttFinalSeconds.map { .nanoseconds(Int64($0 * 1_000_000_000)) }
        self.retrieval = .nanoseconds(Int64(retrievalSeconds * 1_000_000_000))
        self.firstToken = firstTokenSeconds.map { .nanoseconds(Int64($0 * 1_000_000_000)) }
        self.total = .nanoseconds(Int64(totalSeconds * 1_000_000_000))
    }

    var sttFinalSeconds: Double? { sttFinal?.seconds }
    var retrievalSeconds: Double { retrieval.seconds }
    var firstTokenSeconds: Double? { firstToken?.seconds }
    var totalSeconds: Double { total.seconds }

    var primeiroToken: Duration? { firstToken }
    var primeiroTokenLLM: Duration? { firstToken }
    var totalAteLente: Duration { total }
}
