import Foundation

/// Representação de uma fonte importada no material do app (DESIGN.md T04).
struct MaterialSource: Identifiable, Equatable, Sendable {
    var id: String { path }
    let name: String
    let path: String
    let kind: IndexedChunk.Kind
    var chunkCount: Int
    var subtitle: String
    var importedAt: Date

    init(
        name: String,
        path: String,
        kind: IndexedChunk.Kind,
        chunkCount: Int,
        subtitle: String,
        importedAt: Date = Date()
    ) {
        self.name = name
        self.path = path
        self.kind = kind
        self.chunkCount = chunkCount
        self.subtitle = subtitle
        self.importedAt = importedAt
    }

    /// Valor exibido no item da lista (ex: "30 itens" ou "12 trechos").
    var displayCount: String {
        if kind == .qa {
            return "\(chunkCount) \(chunkCount == 1 ? "item" : "itens")"
        } else {
            return "\(chunkCount) \(chunkCount == 1 ? "trecho" : "trechos")"
        }
    }
}
