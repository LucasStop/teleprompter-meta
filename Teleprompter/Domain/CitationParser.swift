import Foundation
import UIKit

/// Atributo tipado para identificação de citações no AttributedString.
public struct CitationAttribute: AttributedStringKey {
    public typealias Value = Int
    public static let name = "CitationAttribute"
}

public extension AttributeScopes {
    struct TeleprompterAttributes: AttributeScope {
        public let citation: CitationAttribute
        public let uikit: UIKitAttributes
    }
    var teleprompter: TeleprompterAttributes.Type { TeleprompterAttributes.self }
}

/// Parser puro e testável para citações inline [n] e remoção de marcadores para a lente (issue #113).
public enum CitationParser: Sendable {
    private static let citationPattern = #"\[(\d+)\]"#
    private static let stripPattern = #"(?<=\S)\s*\[\d+\]|\[\d+\]\s*"#

    /// Remove marcadores [n] de texto (usado para a lente, onde citações nunca são exibidas).
    public static func stripCitations(_ text: String) -> String {
        guard text.contains("[") else { return text }
        return text.replacingOccurrences(of: stripPattern, with: "", options: .regularExpression)
    }

    /// Processa o texto com markdown inline e converte marcadores [n] válidos (1...sourceCount)
    /// em número sobrescrito pequeno em `primary` (SF Mono, peso semibold).
    /// Números fora do intervalo de fontes (ou quando sourceCount == 0) são removidos.
    public static func parse(_ text: String, sourceCount: Int) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var attr = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)

        guard text.contains("[") else {
            return attr
        }

        let plain = String(attr.characters)
        guard let regex = try? NSRegularExpression(pattern: citationPattern) else {
            return attr
        }

        let nsString = plain as NSString
        let matches = regex.matches(in: plain, range: NSRange(location: 0, length: nsString.length))
        guard !matches.isEmpty else {
            return attr
        }

        let primaryColor = SemanticColor.primary.uiColor
        let citeFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold)

        for match in matches.reversed() {
            let fullNSRange = match.range
            let numNSRange = match.range(at: 1)
            let numStr = nsString.substring(with: numNSRange)

            guard let strRange = Range(fullNSRange, in: plain),
                  let attrStart = AttributedString.Index(strRange.lowerBound, within: attr),
                  let attrEnd = AttributedString.Index(strRange.upperBound, within: attr) else {
                continue
            }
            let attrRange = attrStart..<attrEnd

            let num = Int(numStr) ?? 0
            if sourceCount > 0 && (1...sourceCount).contains(num) {
                var citeAttr = AttributedString(numStr)
                var container = AttributeContainer()
                container.uiKit.font = citeFont
                container.uiKit.foregroundColor = primaryColor
                container.uiKit.baselineOffset = 4.0
                container.baselineOffset = 4.0
                container[CitationAttribute.self] = num
                citeAttr.mergeAttributes(container)
                attr.replaceSubrange(attrRange, with: citeAttr)
            } else {
                attr.replaceSubrange(attrRange, with: AttributedString(""))
            }
        }

        return attr
    }
}
