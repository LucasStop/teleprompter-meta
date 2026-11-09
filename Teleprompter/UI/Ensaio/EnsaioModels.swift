import Foundation

/// Item individual de ensaio contendo referência textual e áudio gravado.
struct EnsaioItem: Sendable, Identifiable, Equatable {
    let id: String
    let title: String
    let referenceText: String
    let audioURL: URL?

    init(
        id: String,
        title: String,
        referenceText: String,
        audioURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.referenceText = referenceText
        self.audioURL = audioURL
    }
}

/// Fonte de itens de ensaio por protocolo para permitir fakes em teste.
protocol EnsaioItemSource: Sendable {
    func loadItems() async throws -> [EnsaioItem]
}

/// Implementação de produção do EnsaioItemSource que descobre arquivos em Documents/Ensaio.
final class DocumentDirectoryEnsaioItemSource: EnsaioItemSource, @unchecked Sendable {
    let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let dir = directoryURL {
            self.directoryURL = dir
        } else if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.directoryURL = documents.appendingPathComponent("Ensaio")
        } else {
            self.directoryURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Ensaio")
        }
    }

    func loadItems() async throws -> [EnsaioItem] {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        if !fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDir) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            return []
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let audioFiles = contents.filter { $0.pathExtension.lowercased() == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var items: [EnsaioItem] = []
        for audioURL in audioFiles {
            let baseName = audioURL.deletingPathExtension().lastPathComponent
            let txtURL = audioURL.deletingPathExtension().appendingPathExtension("txt")
            let referenceText: String
            if let text = try? String(contentsOf: txtURL, encoding: .utf8) {
                referenceText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                referenceText = baseName
            }
            let title = referenceText.isEmpty ? baseName : referenceText
            items.append(EnsaioItem(
                id: baseName,
                title: title,
                referenceText: referenceText,
                audioURL: audioURL
            ))
        }

        return items
    }
}

/// Tipo da origem da resposta conforme protótipo T05 (nota de Q&A, LLM, não encontrei).
enum AnswerSourceKind: String, Sendable, CaseIterable, Equatable {
    case qaNote = "nota de Q&A"
    case llm = "LLM"
    case notFound = "não encontrei no material"
}

/// Resultado da execução de uma pergunta no ensaio.
struct EnsaioQuestionResult: Sendable, Identifiable, Equatable {
    let id: String
    let referenceQuestion: String
    let transcribedText: String
    let wer: Double
    let answer: String
    let answerKind: AnswerSourceKind
    let latency: LatencyReport
    let isOk: Bool

    init(
        id: String = UUID().uuidString,
        referenceQuestion: String,
        transcribedText: String,
        wer: Double,
        answer: String,
        answerKind: AnswerSourceKind,
        latency: LatencyReport,
        isOk: Bool? = nil
    ) {
        self.id = id
        self.referenceQuestion = referenceQuestion
        self.transcribedText = transcribedText
        self.wer = wer
        self.answer = answer
        self.answerKind = answerKind
        self.latency = latency
        if let isOk = isOk {
            self.isOk = isOk
        } else {
            let firstText = latency.primeiroToken?.seconds ?? latency.total.seconds
            self.isOk = firstText <= 2.0 && wer <= 0.15
        }
    }

    var werPercentageString: String {
        let pct = Int((wer * 100).rounded())
        return "WER \(pct)%"
    }

    var latencyFormatted: String {
        let seconds = latency.primeiroToken?.seconds ?? latency.total.seconds
        return String(format: "%.1f s", seconds).replacingOccurrences(of: ".", with: ",")
    }

    var subtitleString: String {
        switch answerKind {
        case .notFound:
            return "\(werPercentageString) · \(answerKind.rawValue)"
        case .qaNote, .llm:
            return "\(werPercentageString) · \(latencyFormatted) · \(answerKind.rawValue)"
        }
    }
}

/// Resumo métrico consolidado de uma rodada de ensaio (média, mediana e p95 de latência, WER médio).
struct EnsaioRunSummary: Sendable, Equatable {
    let totalQuestions: Int
    let averageWER: Double
    let averageLatencySeconds: Double
    let p95LatencySeconds: Double
    let medianLatencySeconds: Double

    init(
        totalQuestions: Int,
        averageWER: Double,
        averageLatencySeconds: Double,
        p95LatencySeconds: Double,
        medianLatencySeconds: Double
    ) {
        self.totalQuestions = totalQuestions
        self.averageWER = averageWER
        self.averageLatencySeconds = averageLatencySeconds
        self.p95LatencySeconds = p95LatencySeconds
        self.medianLatencySeconds = medianLatencySeconds
    }

    init(results: [EnsaioQuestionResult]) {
        self.totalQuestions = results.count
        if results.isEmpty {
            self.averageWER = 0.0
            self.averageLatencySeconds = 0.0
            self.p95LatencySeconds = 0.0
            self.medianLatencySeconds = 0.0
            return
        }

        let totalWER = results.reduce(0.0) { $0 + $1.wer }
        self.averageWER = totalWER / Double(results.count)

        let latencies = results.map { $0.latency.primeiroToken?.seconds ?? $0.latency.total.seconds }.sorted()
        let totalLatency = latencies.reduce(0.0, +)
        self.averageLatencySeconds = totalLatency / Double(latencies.count)

        if latencies.count % 2 == 1 {
            self.medianLatencySeconds = latencies[latencies.count / 2]
        } else {
            self.medianLatencySeconds = (latencies[latencies.count / 2 - 1] + latencies[latencies.count / 2]) / 2.0
        }

        let p95Index = Int(ceil(0.95 * Double(latencies.count))) - 1
        self.p95LatencySeconds = latencies[max(0, min(latencies.count - 1, p95Index))]
    }

    var werFormatted: String {
        let pct = Int((averageWER * 100).rounded())
        return "WER \(pct)%"
    }

    var summaryTitle: String {
        "Último ensaio · \(totalQuestions) \(totalQuestions == 1 ? "pergunta" : "perguntas")"
    }

    var summaryHeadline: String {
        let avgStr = String(format: "%.1f s", averageLatencySeconds).replacingOccurrences(of: ".", with: ",")
        let p95Str = String(format: "%.1f s", p95LatencySeconds).replacingOccurrences(of: ".", with: ",")
        return "\(werFormatted) · média \(avgStr) · p95 \(p95Str)"
    }
}

/// Notificação de progresso da execução de ensaio.
struct EnsaioRunProgress: Sendable, Equatable {
    let currentIndex: Int
    let totalCount: Int
    let currentQuestionTitle: String
    let fractionCompleted: Double
}

/// Estado de prontidão do SpeechAssetManager.
enum SpeechReadiness: Sendable, Equatable {
    case ready
    case unsupportedLocale(Locale)
    case assetNotInstalled(Locale)
}
