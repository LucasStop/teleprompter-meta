import Foundation

/// Calcula o Word Error Rate (WER) entre uma referência e uma hipótese via distância de Levenshtein por palavra.
enum WordErrorRate {
    static func normalize(_ text: String) -> [String] {
        let folded = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "pt-BR")
        )
        return folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func calculate(reference: String, hypothesis: String) -> Double {
        let refWords = normalize(reference)
        let hypWords = normalize(hypothesis)

        if refWords.isEmpty {
            return hypWords.isEmpty ? 0.0 : 1.0
        }
        if hypWords.isEmpty {
            return 1.0
        }

        let refCount = refWords.count
        let hypCount = hypWords.count
        var matrix = Array(repeating: Array(repeating: 0, count: hypCount + 1), count: refCount + 1)

        for refIndex in 0...refCount {
            matrix[refIndex][0] = refIndex
        }
        for hypIndex in 0...hypCount {
            matrix[0][hypIndex] = hypIndex
        }

        for refIndex in 1...refCount {
            for hypIndex in 1...hypCount {
                if refWords[refIndex - 1] == hypWords[hypIndex - 1] {
                    matrix[refIndex][hypIndex] = matrix[refIndex - 1][hypIndex - 1]
                } else {
                    let substitution = matrix[refIndex - 1][hypIndex - 1] + 1
                    let deletion = matrix[refIndex - 1][hypIndex] + 1
                    let insertion = matrix[refIndex][hypIndex - 1] + 1
                    matrix[refIndex][hypIndex] = min(substitution, min(deletion, insertion))
                }
            }
        }

        return Double(matrix[refCount][hypCount]) / Double(refCount)
    }
}
