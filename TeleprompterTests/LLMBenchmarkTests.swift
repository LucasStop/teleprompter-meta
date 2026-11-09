import Foundation
import XCTest
@testable import Teleprompter

final class LLMBenchmarkTests: XCTestCase {
    private let lastError = ErrorBox()

    private var tempDirectory: URL!
    private var databaseURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMBench-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        databaseURL = tempDirectory.appendingPathComponent("bench.sqlite3")
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    func testLLMProvidersBenchmark() async throws {
        let isBenchEnabled = ProcessInfo.processInfo.environment["RUN_LLM"] == "1" ||
            ProcessInfo.processInfo.environment["TEST_RUNNER_RUN_LLM"] == "1" ||
            ProcessInfo.processInfo.environment["SIMCTL_CHILD_RUN_LLM"] == "1"
        try XCTSkipUnless(isBenchEnabled, "Benchmark de LLM desativado (ative com RUN_LLM=1).")

        guard let rawProviders = readEnv("LLM_PROVIDERS") else {
            throw XCTSkip("Nenhum provedor configurado em LLM_PROVIDERS.")
        }

        let profiles = rawProviders
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\t" || $0 == "\n" })
            .map(String.init)
            .filter { !$0.isEmpty }

        guard !profiles.isEmpty else {
            throw XCTSkip("Lista de provedores em LLM_PROVIDERS está vazia.")
        }

        let retriever = try LocalRetriever(databaseURL: databaseURL, qaThreshold: 0.40, chunkThreshold: 0.25, topK: 3)
        let corpus = makeBenchmarkCorpus()
        try retriever.index(corpus)

        let questions = makeBenchmarkQuestions()
        XCTAssertEqual(questions.count, 30)

        var profileSummaries: [ProfileSummary] = []

        for profile in profiles {
            guard let generator = makeGenerator(for: profile) else {
                continue
            }

            // 1 rodada de aquecimento descartada
            await performWarmup(generator: generator, retriever: retriever, question: questions[0])

            let results = await measureProfile(
                profileName: profile,
                generator: generator,
                retriever: retriever,
                questions: questions
            )

            let summary = buildSummary(profile: profile, results: results)
            profileSummaries.append(summary)

            printDetailTable(profile: profile, results: results)
        }

        printSummaryTable(summaries: profileSummaries)
    }

    private func readEnv(_ key: String) -> String? {
        let env = ProcessInfo.processInfo.environment
        if let val = env[key], !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return val.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let val = env["SIMCTL_CHILD_" + key], !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return val.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let val = env["TEST_RUNNER_" + key], !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return val.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func makeGenerator(for profile: String) -> (any AnswerGenerator)? {
        let profileLower = profile.lowercased()
        if profileLower == "apple" {
            if FoundationModelsAnswerGenerator.isSupported {
                return FoundationModelsAnswerGenerator()
            }
            print("[AVISO] Perfil apple ignorado: FoundationModels não disponível ou indisponível em runtime.")
            return nil
        }

        let normalized = profile.uppercased().replacingOccurrences(of: "-", with: "_")
        guard let key = readEnv("LLM_\(normalized)_KEY") else {
            print("[AVISO] Perfil \(profile) pulado: chave não encontrada em LLM_\(normalized)_KEY.")
            return nil
        }

        guard let urlString = readEnv("LLM_\(normalized)_BASE_URL"),
              let baseURL = URL(string: urlString) else {
            print("[AVISO] Perfil \(profile) pulado: URL base inválida em LLM_\(normalized)_BASE_URL.")
            return nil
        }

        let model = readEnv("LLM_\(normalized)_MODEL") ?? "default"
        let formatStr = readEnv("LLM_\(normalized)_FORMAT")?.lowercased()
        let format: StreamingAnswerGenerator.Format = (formatStr == "anthropic") ? .anthropic : .openAI
        let secretStore = InMemorySecretStore(initial: ["api_key": key])

        return StreamingAnswerGenerator(
            baseURL: baseURL,
            model: model,
            secretStore: secretStore,
            apiKeyKey: "api_key",
            format: format,
            onError: { [lastError] error in lastError.set(error.localizedDescription) }
        )
    }

    private func performWarmup(generator: any AnswerGenerator, retriever: LocalRetriever, question: String) async {
        let retrieval = (try? await retriever.retrieve(question)) ?? Retrieval(qaNote: nil, chunks: [])
        let context: [Chunk]
        if !retrieval.chunks.isEmpty {
            context = retrieval.chunks
        } else if let note = retrieval.qaNote {
            context = [note]
        } else {
            context = []
        }
        for await _ in generator.generate(question: question, context: context) {}
    }

    private func measureProfile(
        profileName: String,
        generator: any AnswerGenerator,
        retriever: LocalRetriever,
        questions: [String]
    ) async -> [QuestionResult] {
        var results: [QuestionResult] = []
        let clock = ContinuousClock()

        for (index, questionText) in questions.enumerated() {
            let retrieval = (try? await retriever.retrieve(questionText)) ?? Retrieval(qaNote: nil, chunks: [])
            let context: [Chunk]
            if !retrieval.chunks.isEmpty {
                context = retrieval.chunks
            } else if let note = retrieval.qaNote {
                context = [note]
            } else {
                context = []
            }

            let start = clock.now
            var firstTokenInstant: ContinuousClock.Instant?
            var collected = ""
            lastError.set(nil)

            let stream = generator.generate(question: questionText, context: context)
            for await delta in stream {
                if firstTokenInstant == nil && !delta.isEmpty {
                    firstTokenInstant = clock.now
                }
                collected += delta
            }
            let end = clock.now

            let totalDuration = start.duration(to: end)
            let (totSec, totAtto) = totalDuration.components
            let totalMs = Double(totSec) * 1000.0 + Double(totAtto) / 1_000_000_000_000_000.0

            var ttftMs: Double?
            if let first = firstTokenInstant {
                let ttftDuration = start.duration(to: first)
                let (fSec, fAtto) = ttftDuration.components
                ttftMs = Double(fSec) * 1000.0 + Double(fAtto) / 1_000_000_000_000_000.0
            }

            let failure = lastError.get()
            if let failure {
                print("[ERRO] \(profileName) #\(index + 1): \(failure)")
            }

            results.append(QuestionResult(
                index: index + 1,
                question: questionText,
                ttftMs: ttftMs,
                totalMs: totalMs,
                response: collected,
                hadError: failure != nil
            ))
        }

        return results
    }

    private func buildSummary(profile: String, results: [QuestionResult]) -> ProfileSummary {
        let validTTFTs = results.compactMap(\.ttftMs).sorted()
        let totals = results.map(\.totalMs).sorted()

        let ttftMean = validTTFTs.isEmpty ? 0 : (validTTFTs.reduce(0.0, +) / Double(validTTFTs.count))
        let ttftP50 = validTTFTs.isEmpty ? 0 : validTTFTs[validTTFTs.count / 2]
        let ttftP95 = validTTFTs.isEmpty ? 0 : validTTFTs[min(Int(Double(validTTFTs.count) * 0.95), validTTFTs.count - 1)]

        let totalMean = totals.isEmpty ? 0 : (totals.reduce(0.0, +) / Double(totals.count))
        let totalP50 = totals.isEmpty ? 0 : totals[totals.count / 2]
        let totalP95 = totals.isEmpty ? 0 : totals[min(Int(Double(totals.count) * 0.95), totals.count - 1)]

        let emptyCount = results.filter { $0.response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let errorCount = results.filter(\.hadError).count

        return ProfileSummary(
            profile: profile,
            ttftMean: ttftMean,
            ttftP50: ttftP50,
            ttftP95: ttftP95,
            totalMean: totalMean,
            totalP50: totalP50,
            totalP95: totalP95,
            emptyCount: emptyCount,
            errorCount: errorCount
        )
    }

    private func printSummaryTable(summaries: [ProfileSummary]) {
        guard !summaries.isEmpty else { return }
        print("\n### Resumo Comparativo de Provedores de LLM")
        let header = "| Perfil | TTFT Médio (ms) | TTFT p50 (ms) | TTFT p95 (ms) | Total Médio (ms) | Total p50 (ms) | "
            + "Total p95 (ms) | Vazias | Erros |"
        print(header)
        print("|---|---|---|---|---|---|---|---|---|")
        for summary in summaries {
            print(String(
                format: "| %@ | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %d | %d |",
                summary.profile, summary.ttftMean, summary.ttftP50, summary.ttftP95,
                summary.totalMean, summary.totalP50, summary.totalP95,
                summary.emptyCount, summary.errorCount
            ))
        }
        print("")
    }

    private func printDetailTable(profile: String, results: [QuestionResult]) {
        print("\n### Detalhes por Pergunta — Perfil: \(profile)")
        print("| # | Pergunta | TTFT (ms) | Total (ms) | Resposta (truncada 200 chars) |")
        print("|---|---|---|---|---|")
        for result in results {
            let ttftStr = result.ttftMs.map { String(format: "%.2f", $0) } ?? "-"
            let totalStr = String(format: "%.2f", result.totalMs)
            let sanitized = truncate(result.response, limit: 200)
            print("| \(result.index) | \(result.question) | \(ttftStr) | \(totalStr) | \(sanitized) |")
        }
        print("")
    }

    private func truncate(_ text: String, limit: Int) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "|", with: "\\|")
            .trimmingCharacters(in: .whitespaces)
        if singleLine.isEmpty {
            return "(vazia)"
        }
        if singleLine.count <= limit {
            return singleLine
        }
        return String(singleLine.prefix(limit)) + "..."
    }
}

// MARK: - Tipos de Apoio ao Benchmark

private final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    func set(_ newValue: String?) { lock.lock(); value = newValue; lock.unlock() }
    func get() -> String? { lock.lock(); defer { lock.unlock() }; return value }
}

private struct QuestionResult: Sendable {
    let index: Int
    let question: String
    let ttftMs: Double?
    let totalMs: Double
    let response: String
    let hadError: Bool
}

private struct ProfileSummary: Sendable {
    let profile: String
    let ttftMean: Double
    let ttftP50: Double
    let ttftP95: Double
    let totalMean: Double
    let totalP50: Double
    let totalP95: Double
    let emptyCount: Int
    let errorCount: Int
}

// MARK: - Corpus e Perguntas de Exemplo

extension LLMBenchmarkTests {
    private func makeBenchmarkQuestions() -> [String] {
        [
            "Qual é o objetivo principal do Teleprompter?", "Por que foi escolhido Swift nativo?",
            "Qual o limiar de silêncio para detectar pergunta?", "Como funciona a política de RAG fechado?",
            "Qual a resolução nativa da lente?", "Qual o formato do áudio recebido dos óculos?",
            "Qual a meta de latência até o primeiro texto?", "O que acontece se a rede cair na apresentação?",
            "Onde ficam armazenadas as chaves de API?", "Quantas linhas cabem no display da lente?",
            "Como o modo WAL melhora concorrência?", "Como funciona o algoritmo BM25?",
            "Qual a taxa padrão da struct AudioBuffer?", "Como funciona reconexão Bluetooth HFP?",
            "Como é feita remoção de diacríticos?", "Quais cores na tela monocromática?",
            "Como o parser SSE processa eventos?", "Qual nível de proteção kSecAttrAccessible?",
            "Como roda workflow no GitHub Actions?", "Como SwiftLint strict valida o código?",
            "Como actor RecordingLens isola estado?", "Como a margem de segurança evita corte?",
            "Qual a receita tradicional de pizza calabresa artesanal?",
            "Como cultivar tomates orgânicos no jardim de casa?",
            "Qual foi o placar final do clássico de futebol de ontem?",
            "Quais foram os principais acontecimentos da Revolução Francesa?",
            "Quais são os melhores museus para visitar em Paris?",
            "Como trocar o pneu traseiro de uma bicicleta de montanha?",
            "Qual a fórmula química da fotossíntese nas plantas verdes?",
            "Qual a previsão do tempo para a cidade de Tóquio?"
        ]
    }

    private func makeBenchmarkCorpus() -> [IndexedChunk] {
        makeQACorpus() + makeDocCorpus()
    }

    private func makeQACorpus() -> [IndexedChunk] {
        func seed(_ question: String, _ answer: String, _ path: String) -> IndexedChunk {
            IndexedChunk(kind: .qa, text: answer, source: path, question: question)
        }
        return [
            seed("Qual é o objetivo principal do Teleprompter?", "Auxiliar na banca exibindo respostas curtas.", "qa/01.md"),
            seed("Por que foi escolhido Swift nativo?", "Porque o Meta DAT SDK exige integração nativa.", "qa/02.md"),
            seed("Qual o limiar de silêncio para detectar pergunta?", "Detector usa 1.2 segundos de silêncio.", "qa/03.md"),
            seed("Como funciona a política de RAG fechado?", "Consulta só trechos acima do limiar configurado.", "qa/04.md"),
            seed("Qual a resolução nativa da lente?", "Lente monocromática verde com 600x600 pixels.", "qa/05.md"),
            seed("Qual o formato do áudio recebido dos óculos?", "Áudio de voz em 8 kHz mono linear PCM via HFP.", "qa/06.md"),
            seed("Qual a meta de latência até o primeiro texto?", "Exibir primeiras palavras em menos de 2 segundos.", "qa/07.md"),
            seed("O que acontece se a rede cair na apresentação?", "App responde offline com notas locais de Q&A.", "qa/08.md"),
            seed("Onde ficam armazenadas as chaves de API?", "Credenciais sensíveis ficam no Keychain.", "qa/09.md"),
            seed("Quantas linhas cabem no display da lente?", "Comporta até 5 linhas com 28 caracteres.", "qa/10.md"),
            seed("Qual motor de reconhecimento de fala é utilizado?", "SpeechAnalyzer on-device no iOS 26.", "qa/11.md"),
            seed("Qual a tolerância de erro de palavras WER?", "Critério US-01 estabelece WER abaixo de 15%.", "qa/12.md"),
            seed("Como funciona o caminho rápido de busca?", "Notas de Q&A acima de 0.40 vão direto à lente.", "qa/13.md"),
            seed("Qual mecanismo de banco suporta a busca local?", "SQLite embarcado com tabelas FTS5 unicode61.", "qa/14.md"),
            seed("Quais formatos de resposta estão disponíveis?", "Bullets curtos, palavras-chave ou resumido.", "qa/15.md"),
            seed("Como funciona a lente simulada para testes?", "SimulatedLens espelha em janela SwiftUI 600x600.", "qa/16.md"),
            seed("Existe backend próprio intermediando o app?", "Sem backend; iPhone comanda requisições.", "qa/17.md"),
            seed("Como o Neural Band interage com a apresentação?", "Gestos permitem pedir de novo ou descartar.", "qa/18.md"),
            seed("Qual o tratamento de privacidade para dados de voz?", "Nenhum texto de fala é registrado em log.", "qa/19.md"),
            seed("Quando será realizada a defesa perante a banca?", "Apresentação em novembro de 2027.", "qa/20.md")
        ]
    }

    private func makeDocCorpus() -> [IndexedChunk] {
        var items: [IndexedChunk] = []
        let topics = [
            ("WAL", "O modo WAL (Write-Ahead Logging) melhora a concorrência permitindo leituras simultâneas."),
            ("BM25", "O algoritmo BM25 calcula relevância de termos no FTS5 ponderando frequência e saturação."),
            ("AudioBuffer", "A struct AudioBuffer encapsula o array de amostras float e taxa de amostragem padrão."),
            ("reconexão", "O gerenciador Bluetooth HFP executa reconexão periódica se a conexão for interrompida."),
            ("diacríticos", "O tokenizador remove diacríticos e acentos normalizando texto para comparações."),
            ("monocromática", "A paleta visual do LensTokens adota tela monocromática verde esmeralda com fundo preto."),
            ("SSE", "O parser de Server-Sent Events (SSE) decodifica pacotes data: alimentando o AsyncStream."),
            ("kSecAttrAccessible", "As chaves usam kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly para proteção."),
            ("GitHub Actions", "O fluxo no GitHub Actions roda em runners macOS executando testes do projeto."),
            ("SwiftLint", "A ferramenta SwiftLint com modo strict valida regras de estilo no código Swift 6."),
            ("RecordingLens", "O actor RecordingLens armazena a última resposta garantindo isolamento seguro."),
            ("margem de segurança", "A margem de segurança delimita 28 caracteres por linha para evitar cortes.")
        ]

        var counter = 1
        for round in 0..<17 {
            for (keyword, desc) in topics {
                guard items.count < 200 else { break }
                let kind: IndexedChunk.Kind = (counter % 3 == 0) ? .code : .document
                let src = (kind == .code) ? "Sources/Module\(round)/Part\(counter).swift" : "docs/spec_\(round)_\(counter).md"
                let text = "[\(keyword)] \(desc) Trecho de documentação e especificação técnica \(counter)."
                items.append(IndexedChunk(kind: kind, text: text, source: src))
                counter += 1
            }
        }
        return items
    }
}
