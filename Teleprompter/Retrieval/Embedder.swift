import Foundation

protocol Embedder: Sendable {
    func embed(_ text: String) -> [Float]
}

final class FakeEmbedder: Embedder, @unchecked Sendable {
    let dimension: Int
    private let custom: [String: [Float]]

    init(dimension: Int = 16, custom: [String: [Float]] = [:]) {
        self.dimension = max(1, dimension)
        self.custom = custom
    }

    func embed(_ text: String) -> [Float] {
        if let vector = custom[text] {
            return normalize(vector)
        }
        var vector = [Float](repeating: 0, count: dimension)
        let words = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        for word in words {
            let hash = abs(word.hashValue)
            let index = hash % dimension
            let sign: Float = ((hash / dimension) % 2 == 0) ? 1.0 : -1.0
            vector[index] += sign * 1.0
        }

        return normalize(vector)
    }

    private func normalize(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else {
            var fallback = [Float](repeating: 0, count: dimension)
            fallback[0] = 1.0
            return fallback
        }
        return vector.map { $0 / norm }
    }
}
