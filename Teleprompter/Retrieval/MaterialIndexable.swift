import Foundation

/// Protocolo para indexação e remoção de material no índice de busca (ADR-0006 e ADR-0010).
protocol MaterialIndexable: Sendable {
    func index(_ items: [IndexedChunk]) throws
    func removeSource(_ path: String) throws
    func listActiveSources() -> [MaterialSource]
}

extension MaterialIndexable {
    func listActiveSources() -> [MaterialSource] { [] }
}

extension LocalRetriever: MaterialIndexable {}
