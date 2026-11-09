import Foundation

/// Limites da lente 600x600 (propostos no T01, a validar no óculos): 5 linhas de 28 caracteres.
struct LensFormatter: ResponseFormatter {
    static let maxLines = 5
    static let maxChars = 28

    func format(_ text: String, as format: AnswerFormat) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let lines: [String]
        switch format {
        case .bullets: lines = bullets(items(trimmed))
        case .keywords: lines = items(trimmed, splitCommas: true).map { clip($0, Self.maxChars) }
        case .fullText: lines = wrap(trimmed, Self.maxChars)
        }
        return cap(lines).joined(separator: "\n")
    }

    private func items(_ text: String, splitCommas: Bool = false) -> [String] {
        let marker = try? NSRegularExpression(pattern: #"^\s*(?:[-•*]|\d+[.)])\s*"#)
        let rows = text.components(separatedBy: .newlines).compactMap { row -> String? in
            let range = NSRange(row.startIndex..., in: row)
            let clean = (marker?.stringByReplacingMatches(in: row, range: range, withTemplate: "") ?? row)
                .trimmingCharacters(in: .whitespaces)
            return clean.isEmpty ? nil : clean
        }
        if rows.count > 1 { return rows }
        let sep = splitCommas ? #"[,;]\s*|\.\s+"# : #"\.\s+|;\s*"#
        let parts = (rows.first ?? "").replacingOccurrences(of: sep, with: "\u{1}", options: .regularExpression)
            .components(separatedBy: "\u{1}")
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ". ")) }
        return parts.filter { !$0.isEmpty }
    }

    private func bullets(_ items: [String]) -> [String] {
        items.flatMap { item in
            wrap(item, Self.maxChars - 2).enumerated().map { ($0.offset == 0 ? "• " : "  ") + $0.element }
        }
    }

    private func wrap(_ text: String, _ width: Int) -> [String] {
        var out: [String] = []
        var line = ""
        for word in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            let word = clip(word, width)
            if line.isEmpty { line = word } else if line.count + 1 + word.count <= width { line += " " + word } else {
                out.append(line); line = word
            }
        }
        if !line.isEmpty { out.append(line) }
        return out
    }

    private func clip(_ text: String, _ width: Int) -> String {
        text.count <= width ? text : String(text.prefix(width - 1)) + "…"
    }

    private func cap(_ lines: [String]) -> [String] {
        guard lines.count > Self.maxLines else { return lines }
        var kept = Array(lines.prefix(Self.maxLines))
        kept[Self.maxLines - 1] = clip(kept[Self.maxLines - 1] + "…", Self.maxChars)
        return kept
    }
}
