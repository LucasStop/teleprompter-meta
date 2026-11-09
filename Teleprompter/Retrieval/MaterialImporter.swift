import Foundation

enum MaterialImporterError: LocalizedError, Equatable, Sendable {
    case emptyFile(String)
    case unreadableFile(String, reason: String)

    var errorDescription: String? {
        switch self {
        case .emptyFile(let name):
            return "O arquivo \"\(name)\" está vazio. Escolha um arquivo com conteúdo."
        case .unreadableFile(let name, let reason):
            return "Não consegui ler \"\(name)\". \(reason) Escolha o arquivo de novo."
        }
    }
}

/// Chunker de texto por parágrafos/seções com tamanho máximo e sobreposição.
struct MaterialChunker: Sendable {
    let maxCharacters: Int
    let overlapCharacters: Int

    init(maxCharacters: Int = 600, overlapCharacters: Int = 80) {
        self.maxCharacters = max(50, maxCharacters)
        self.overlapCharacters = max(0, min(overlapCharacters, maxCharacters / 2))
    }

    func chunk(text: String, source: String, kind: IndexedChunk.Kind) -> [IndexedChunk] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let paragraphs = splitIntoParagraphs(trimmed)
        var chunks: [IndexedChunk] = []
        var currentBuffer = ""

        for paragraph in paragraphs {
            if currentBuffer.isEmpty {
                if paragraph.count > maxCharacters {
                    let slices = splitLongText(paragraph)
                    for slice in slices {
                        chunks.append(IndexedChunk(kind: kind, text: slice, source: source))
                    }
                } else {
                    currentBuffer = paragraph
                }
            } else {
                let candidate = currentBuffer + "\n\n" + paragraph
                if candidate.count <= maxCharacters {
                    currentBuffer = candidate
                } else {
                    chunks.append(IndexedChunk(kind: kind, text: currentBuffer, source: source))
                    if paragraph.count > maxCharacters {
                        let slices = splitLongText(paragraph)
                        for slice in slices {
                            chunks.append(IndexedChunk(kind: kind, text: slice, source: source))
                        }
                        currentBuffer = ""
                    } else {
                        // Aplica sobreposição pegando os últimos caracteres do buffer anterior
                        let overlapPrefix = makeOverlapPrefix(from: currentBuffer)
                        if !overlapPrefix.isEmpty && (overlapPrefix.count + paragraph.count + 1) <= maxCharacters {
                            currentBuffer = overlapPrefix + "\n" + paragraph
                        } else {
                            currentBuffer = paragraph
                        }
                    }
                }
            }
        }

        if !currentBuffer.isEmpty {
            chunks.append(IndexedChunk(kind: kind, text: currentBuffer, source: source))
        }

        return chunks
    }

    private func splitIntoParagraphs(_ text: String) -> [String] {
        let rawParagraphs = text.components(separatedBy: "\n\n")
        var result: [String] = []
        for raw in rawParagraphs {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                result.append(trimmed)
            }
        }
        return result
    }

    private func splitLongText(_ text: String) -> [String] {
        var slices: [String] = []
        var startIndex = text.startIndex

        while startIndex < text.endIndex {
            let remainingDistance = text.distance(from: startIndex, to: text.endIndex)
            let takeCount = min(maxCharacters, remainingDistance)
            let tentativeEnd = text.index(startIndex, offsetBy: takeCount)

            var actualEnd = tentativeEnd
            if tentativeEnd < text.endIndex {
                // Tenta quebrar em espaço ou pontuação para não cortar palavras
                let searchRange = startIndex..<tentativeEnd
                if let lastBreak = text.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards, range: searchRange) {
                    if text.distance(from: startIndex, to: lastBreak.lowerBound) > maxCharacters / 3 {
                        actualEnd = lastBreak.upperBound
                    }
                }
            }

            let slice = String(text[startIndex..<actualEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !slice.isEmpty {
                slices.append(slice)
            }

            if actualEnd >= text.endIndex {
                break
            }

            // Próximo início considerando overlap
            let advanceOffset = max(1, text.distance(from: startIndex, to: actualEnd) - overlapCharacters)
            startIndex = text.index(startIndex, offsetBy: advanceOffset)
        }

        return slices
    }

    private func makeOverlapPrefix(from previousText: String) -> String {
        guard overlapCharacters > 0, !previousText.isEmpty else { return "" }
        if previousText.count <= overlapCharacters {
            return previousText
        }
        let index = previousText.index(previousText.endIndex, offsetBy: -overlapCharacters)
        return String(previousText[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Importador puro de material: processa texto e nome do arquivo gerando IndexedChunks.
struct MaterialImporter: Sendable {
    let chunker: MaterialChunker

    init(chunker: MaterialChunker = MaterialChunker()) {
        self.chunker = chunker
    }

    func parse(content: String, sourceName: String) throws -> [IndexedChunk] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MaterialImporterError.emptyFile(sourceName)
        }

        // 1. Tenta formato Q&A
        if let qaChunks = parseQA(content: trimmed, sourceName: sourceName), !qaChunks.isEmpty {
            return qaChunks
        }

        // 2. Determina tipo pelo sufixo do arquivo
        let kind = determineKind(for: sourceName)

        // 3. Quebra em trechos via chunker
        return chunker.chunk(text: trimmed, source: sourceName, kind: kind)
    }

    private func determineKind(for sourceName: String) -> IndexedChunk.Kind {
        let codeExtensions: Set<String> = [
            "swift", "ts", "js", "php", "py", "sql", "json", "yml", "yaml", "sh", "rb", "go", "rs", "c", "cpp", "h"
        ]
        let ext = (sourceName as NSString).pathExtension.lowercased()
        if codeExtensions.contains(ext) {
            return .code
        }
        return .document
    }

    private func parseQA(content: String, sourceName: String) -> [IndexedChunk]? {
        if content.hasPrefix("---"), let frontMatterChunks = parseFrontMatterQA(content: content, sourceName: sourceName) {
            return frontMatterChunks
        }
        return parseLinePairsQA(content: content, sourceName: sourceName)
    }

    private func parseFrontMatterQA(content: String, sourceName: String) -> [IndexedChunk]? {
        let parts = content.components(separatedBy: "---")
        guard parts.count >= 3 else { return nil }

        let frontMatter = parts[1]
        let body = parts.dropFirst(2).joined(separator: "---").trimmingCharacters(in: .whitespacesAndNewlines)
        var question: String?

        for line in frontMatter.components(separatedBy: .newlines) {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmedLine.lowercased()
            if lower.hasPrefix("pergunta:") {
                let idx = trimmedLine.index(trimmedLine.startIndex, offsetBy: 9)
                question = String(trimmedLine[idx...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if lower.hasPrefix("question:") {
                let idx = trimmedLine.index(trimmedLine.startIndex, offsetBy: 9)
                question = String(trimmedLine[idx...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let question, !question.isEmpty, !body.isEmpty else { return nil }
        return [
            IndexedChunk(kind: .qa, text: body, source: sourceName, question: question)
        ]
    }

    private func parseLinePairsQA(content: String, sourceName: String) -> [IndexedChunk]? {
        let lines = content.components(separatedBy: .newlines)
        var pairs: [IndexedChunk] = []
        var currentQuestion: String?
        var currentAnswerLines: [String] = []

        func flushCurrentPair() {
            if let question = currentQuestion, !currentAnswerLines.isEmpty {
                let answer = currentAnswerLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !answer.isEmpty {
                    pairs.append(IndexedChunk(kind: .qa, text: answer, source: sourceName, question: question))
                }
            }
            currentQuestion = nil
            currentAnswerLines = []
        }

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if let parsedQuestion = extractPrefix(from: trimmedLine, prefixes: ["P:", "Pergunta:", "Q:"]) {
                flushCurrentPair()
                currentQuestion = parsedQuestion
            } else if let parsedAnswer = extractPrefix(from: trimmedLine, prefixes: ["R:", "Resposta:", "A:"]) {
                currentAnswerLines.append(parsedAnswer)
            } else if currentQuestion != nil && !currentAnswerLines.isEmpty {
                currentAnswerLines.append(line)
            }
        }
        flushCurrentPair()

        return pairs.isEmpty ? nil : pairs
    }

    private func extractPrefix(from text: String, prefixes: [String]) -> String? {
        for prefix in prefixes where text.localizedStandardContains(prefix) {
            let lower = text.lowercased()
            let pLower = prefix.lowercased()
            if lower.hasPrefix(pLower) {
                let index = text.index(text.startIndex, offsetBy: prefix.count)
                return String(text[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}
