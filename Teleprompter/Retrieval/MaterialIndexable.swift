import Foundation

/// Protocolo para indexação e remoção de material no índice de busca.
protocol MaterialIndexable: Sendable {
    func index(_ items: [IndexedChunk]) throws
    func removeSource(_ path: String) throws
}

extension LocalRetriever: MaterialIndexable {}
