import Foundation

struct AudioBuffer: Sendable, Equatable {
    var samples: [Float]
    var sampleRate: Double
}

struct Transcript: Sendable, Equatable {
    var text: String
    var isFinal: Bool
}

enum AnswerFormat: String, Sendable, CaseIterable {
    case bullets, keywords, fullText
}

struct SourceRef: Sendable, Equatable {
    var path: String
}

struct Chunk: Sendable, Equatable {
    var text: String
    var source: SourceRef
}

/// Resultado da busca. `qaNote` vence os trechos (ADR-0004); sem nada, o RAG fechado não chama o LLM (ADR-0009).
struct Retrieval: Sendable, Equatable {
    var qaNote: Chunk?
    var chunks: [Chunk]
    var isEmpty: Bool { qaNote == nil && chunks.isEmpty }
}

struct LensContent: Sendable, Equatable {
    var question: String
    var body: String
    var sources: [SourceRef]
}
