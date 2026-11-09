import Foundation
import XCTest
@testable import Teleprompter

final class RetrievalBenchmarkTests: XCTestCase {
    private var tempDirectory: URL!
    private var databaseURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Bench-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        databaseURL = tempDirectory.appendingPathComponent("bench.sqlite3")
    }

    override func tearDownWithError() throws {
        if let tempDirectory { try? FileManager.default.removeItem(at: tempDirectory) }
        try super.tearDownWithError()
    }

    func testRetrievalAndPipelineBenchmark() async throws {
        let isBenchEnabled = ProcessInfo.processInfo.environment["RUN_BENCH"] == "1" ||
            ProcessInfo.processInfo.environment["TEST_RUNNER_RUN_BENCH"] == "1" ||
            ProcessInfo.processInfo.environment["SIMCTL_CHILD_RUN_BENCH"] == "1"
        try XCTSkipUnless(isBenchEnabled, "Benchmark de recuperação desativado (ative com RUN_BENCH=1).")

        let retriever = try LocalRetriever(databaseURL: databaseURL, qaThreshold: 0.40, chunkThreshold: 0.25, topK: 3)
        let corpus = makeBenchmarkCorpus()
        try retriever.index(corpus)
        _ = try await retriever.retrieve("warmup projeto arquitetura")

        let questions = makeBenchmarkQuestions()
        XCTAssertEqual(questions.count, 30)

        let (latencies, quality) = try await runBenchmarkRounds(retriever: retriever, questions: questions, rounds: 5)
        let pipelineMetrics = await measurePipelineStages(retriever: retriever)

        printBenchmarkReport(latencies: latencies, quality: quality, pipeline: pipelineMetrics, corpusCount: corpus.count)
        assertQuality(quality: quality)
    }

    private func runBenchmarkRounds(
        retriever: LocalRetriever,
        questions: [BenchQuestion],
        rounds: Int
    ) async throws -> ([Double], QualityCounters) {
        var latencies: [Double] = []
        var quality = QualityCounters()

        for round in 0..<rounds {
            for item in questions {
                let start = DispatchTime.now().uptimeNanoseconds
                let result = try await retriever.retrieve(item.question)
                let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0
                latencies.append(elapsedMs)

                if round == 0 {
                    evaluateQuality(item: item, result: result, quality: &quality)
                }
            }
        }
        return (latencies.sorted(), quality)
    }

    private func evaluateQuality(item: BenchQuestion, result: Retrieval, quality: inout QualityCounters) {
        switch item.category {
        case .qaNote(let source):
            if let note = result.qaNote, note.source.path == source {
                quality.qaHits += 1
            } else {
                quality.falseNegatives += 1
                print("[BENCH DETAIL] QA Miss: pergunta=\(item.question) | obtido=\(result.qaNote?.source.path ?? "nil")")
            }
        case .documentOrCode(let keyword):
            if result.qaNote == nil, let chunk = result.chunks.first, chunk.text.localizedCaseInsensitiveContains(keyword) {
                quality.docHits += 1
            } else {
                quality.falseNegatives += 1
                print("[BENCH DETAIL] Doc Miss: pergunta=\(item.question) | chunk=\(result.chunks.first?.text.prefix(40) ?? "vazio")")
            }
        case .notFound:
            if result.isEmpty {
                quality.correctNotFound += 1
            } else {
                quality.falsePositives += 1
                print("[BENCH DETAIL] Falso Positivo: pergunta=\(item.question) | chunks=\(result.chunks.count)")
            }
        }
    }

    private func assertQuality(quality: QualityCounters) {
        XCTAssertEqual(quality.qaHits, 10, "10 notas de Q&A preparadas devem ser recuperadas no caminho rápido.")
        XCTAssertGreaterThanOrEqual(quality.docHits, 8, "A maioria das perguntas de docs/código deve recuperar o trecho.")
        XCTAssertGreaterThanOrEqual(quality.correctNotFound, 5, "Perguntas fora de escopo devem em sua maioria cair em 'não encontrei'.")
    }

    private func printBenchmarkReport(
        latencies: [Double],
        quality: QualityCounters,
        pipeline: PipelineStageMetrics,
        corpusCount: Int
    ) {
        let count = latencies.count
        let mean = latencies.reduce(0.0, +) / Double(count)
        let p50 = latencies[count / 2]
        let p95 = latencies[min(Int(Double(count) * 0.95), count - 1)]

        print("==================================================")
        print("RELATÓRIO MEDIDO DE BENCHMARK - GATE G1")
        print("==================================================")
        print(String(format: "Corpus indexado: %d itens (20 Q&A, 200 documentos/código)", corpusCount))
        print("Perguntas avaliadas: 30 (10 Q&A, 12 Docs/Código, 8 Não Encontrado)")
        print(String(format: "Amostras de latência: %d (5 rodadas)", count))
        print(String(format: "Busca LocalRetriever - Média: %.3f ms | p50: %.3f ms | p95: %.3f ms | Min: %.3f ms | Max: %.3f ms",
                     mean, p50, p95, latencies.first ?? 0, latencies.last ?? 0))
        print("--- Qualidade da Busca ---")
        print("Acertos Q&A: \(quality.qaHits)/10 | Docs/Código: \(quality.docHits)/12 | Não encontrei: \(quality.correctNotFound)/8")
        print("Falsos positivos: \(quality.falsePositives) | Falsos negativos: \(quality.falseNegatives)")
        let totalHits = quality.qaHits + quality.docHits + quality.correctNotFound
        print(String(format: "Acurácia total: %d/30 (%.1f%%)", totalHits, Double(totalHits) / 0.3))
        print("--- Latência por Etapa do Pipeline (Fakes / Piso sem rede) ---")
        print(String(format: "1. Detecção (PauseQuestionDetector feed): média %.4f ms | p95 %.4f ms",
                     pipeline.detectorMean, pipeline.detectorP95))
        print(String(format: "2. Recuperação (LocalRetriever): média %.4f ms | p95 %.4f ms",
                     pipeline.retrievalMean, pipeline.retrievalP95))
        print(String(format: "3. Geração LLM (Fake streaming): média %.4f ms | p95 %.4f ms",
                     pipeline.generatorMean, pipeline.generatorP95))
        print(String(format: "4. Formatação (LensFormatter): média %.4f ms | p95 %.4f ms",
                     pipeline.formatterMean, pipeline.formatterP95))
        print(String(format: "5. Lente (RecordingLens show): média %.4f ms | p95 %.4f ms",
                     pipeline.lensMean, pipeline.lensP95))
        print(String(format: "TOTAL Pipeline ponta a ponta: média %.4f ms | p95 %.4f ms",
                     pipeline.totalMean, pipeline.totalP95))
        print("==================================================")
    }
}

// MARK: - Medição de Pipeline com Fakes

extension RetrievalBenchmarkTests {
    fileprivate struct PipelineStageMetrics {
        let detectorMean: Double; let detectorP95: Double
        let retrievalMean: Double; let retrievalP95: Double
        let generatorMean: Double; let generatorP95: Double
        let formatterMean: Double; let formatterP95: Double
        let lensMean: Double; let lensP95: Double
        let totalMean: Double; let totalP95: Double
    }

    private func measurePipelineStages(retriever: Retriever) async -> PipelineStageMetrics {
        var detTimes: [Double] = []; var retTimes: [Double] = []; var genTimes: [Double] = []
        var fmtTimes: [Double] = []; var lenTimes: [Double] = []; var totTimes: [Double] = []
        let fmt = LensFormatter(), lens = RecordingLens(), generator = FakeGenerator()
        var det = PauseQuestionDetector(silenceThreshold: 1.2)

        for idx in 0..<100 {
            let startAll = DispatchTime.now().uptimeNanoseconds
            let startDet = DispatchTime.now().uptimeNanoseconds
            let query = det.feed(Transcript(text: "Pergunta \(idx)", isFinal: false), silenceSeconds: 1.2) ?? "Pergunta"
            detTimes.append(Double(DispatchTime.now().uptimeNanoseconds - startDet) / 1_000_000.0)

            let startRet = DispatchTime.now().uptimeNanoseconds
            let found = (try? await retriever.retrieve(query)) ?? Retrieval(qaNote: nil, chunks: [])
            retTimes.append(Double(DispatchTime.now().uptimeNanoseconds - startRet) / 1_000_000.0)

            let startGen = DispatchTime.now().uptimeNanoseconds
            var text = found.qaNote?.text ?? (found.isEmpty ? AnswerPipeline.notFoundMessage : "")
            if !found.isEmpty && found.qaNote == nil {
                for await piece in generator.generate(question: query, context: found.chunks) { text += piece }
            }
            genTimes.append(Double(DispatchTime.now().uptimeNanoseconds - startGen) / 1_000_000.0)

            let startFmt = DispatchTime.now().uptimeNanoseconds
            let formatted = fmt.format(text, as: .bullets)
            fmtTimes.append(Double(DispatchTime.now().uptimeNanoseconds - startFmt) / 1_000_000.0)

            let startLen = DispatchTime.now().uptimeNanoseconds
            await lens.show(LensContent(question: query, body: formatted, sources: []))
            lenTimes.append(Double(DispatchTime.now().uptimeNanoseconds - startLen) / 1_000_000.0)
            totTimes.append(Double(DispatchTime.now().uptimeNanoseconds - startAll) / 1_000_000.0)
            det.reset()
        }

        func calcStats(_ values: [Double]) -> (Double, Double) {
            let sorted = values.sorted(), meanVal = sorted.reduce(0.0, +) / Double(sorted.count)
            return (meanVal, sorted[min(Int(Double(sorted.count) * 0.95), sorted.count - 1)])
        }
        let statDet = calcStats(detTimes), statRet = calcStats(retTimes), statGen = calcStats(genTimes)
        let statFmt = calcStats(fmtTimes), statLen = calcStats(lenTimes), statTot = calcStats(totTimes)
        return PipelineStageMetrics(
            detectorMean: statDet.0, detectorP95: statDet.1, retrievalMean: statRet.0, retrievalP95: statRet.1,
            generatorMean: statGen.0, generatorP95: statGen.1, formatterMean: statFmt.0, formatterP95: statFmt.1,
            lensMean: statLen.0, lensP95: statLen.1, totalMean: statTot.0, totalP95: statTot.1
        )
    }
}

// MARK: - Dados do Benchmark

extension RetrievalBenchmarkTests {
    fileprivate struct QualityCounters {
        var qaHits = 0; var docHits = 0; var correctNotFound = 0
        var falsePositives = 0; var falseNegatives = 0
    }

    fileprivate enum BenchCategory {
        case qaNote(source: String)
        case documentOrCode(keyword: String)
        case notFound
    }

    fileprivate struct BenchQuestion {
        let question: String
        let category: BenchCategory
    }

    fileprivate struct QAItem {
        let questionText: String; let answerText: String; let sourcePath: String
    }

    private func makeBenchmarkQuestions() -> [BenchQuestion] {
        [
            BenchQuestion(question: "Qual é o objetivo principal do Teleprompter?", category: .qaNote(source: "qa/01-objetivo.md")),
            BenchQuestion(question: "Por que foi escolhido Swift nativo?", category: .qaNote(source: "qa/02-swift.md")),
            BenchQuestion(question: "Qual o limiar de silêncio para detectar pergunta?", category: .qaNote(source: "qa/03-silencio.md")),
            BenchQuestion(question: "Como funciona a política de RAG fechado?", category: .qaNote(source: "qa/04-rag-fechado.md")),
            BenchQuestion(question: "Qual a resolução nativa da lente?", category: .qaNote(source: "qa/05-resolucao.md")),
            BenchQuestion(question: "Qual o formato do áudio recebido dos óculos?", category: .qaNote(source: "qa/06-audio.md")),
            BenchQuestion(question: "Qual a meta de latência até o primeiro texto?", category: .qaNote(source: "qa/07-latencia.md")),
            BenchQuestion(question: "O que acontece se a rede cair na apresentação?", category: .qaNote(source: "qa/08-offline.md")),
            BenchQuestion(question: "Onde ficam armazenadas as chaves de API?", category: .qaNote(source: "qa/09-keychain.md")),
            BenchQuestion(question: "Quantas linhas cabem no display da lente?", category: .qaNote(source: "qa/10-linhas.md")),

            BenchQuestion(question: "Como o modo WAL melhora concorrência?", category: .documentOrCode(keyword: "WAL")),
            BenchQuestion(question: "Como funciona o algoritmo BM25?", category: .documentOrCode(keyword: "BM25")),
            BenchQuestion(question: "Qual a taxa padrão da struct AudioBuffer?", category: .documentOrCode(keyword: "AudioBuffer")),
            BenchQuestion(question: "Como funciona reconexão Bluetooth HFP?", category: .documentOrCode(keyword: "reconexão")),
            BenchQuestion(question: "Como é feita remoção de diacríticos?", category: .documentOrCode(keyword: "diacríticos")),
            BenchQuestion(question: "Quais cores na tela monocromática?", category: .documentOrCode(keyword: "monocromática")),
            BenchQuestion(question: "Como o parser SSE processa eventos?", category: .documentOrCode(keyword: "SSE")),
            BenchQuestion(question: "Qual nível de proteção kSecAttrAccessible?", category: .documentOrCode(keyword: "kSecAttrAccessible")),
            BenchQuestion(question: "Como roda workflow no GitHub Actions?", category: .documentOrCode(keyword: "GitHub Actions")),
            BenchQuestion(question: "Como SwiftLint strict valida o código?", category: .documentOrCode(keyword: "SwiftLint")),
            BenchQuestion(question: "Como actor RecordingLens isola estado?", category: .documentOrCode(keyword: "RecordingLens")),
            BenchQuestion(question: "Como a margem de segurança evita corte?", category: .documentOrCode(keyword: "margem de segurança")),

            BenchQuestion(question: "Qual a receita tradicional de pizza calabresa artesanal?", category: .notFound),
            BenchQuestion(question: "Como cultivar tomates orgânicos no jardim de casa?", category: .notFound),
            BenchQuestion(question: "Qual foi o placar final do clássico de futebol de ontem?", category: .notFound),
            BenchQuestion(question: "Quais foram os principais acontecimentos da Revolução Francesa?", category: .notFound),
            BenchQuestion(question: "Quais são os melhores museus para visitar em Paris?", category: .notFound),
            BenchQuestion(question: "Como trocar o pneu traseiro de uma bicicleta de montanha?", category: .notFound),
            BenchQuestion(question: "Qual a fórmula química da fotossíntese nas plantas verdes?", category: .notFound),
            BenchQuestion(question: "Qual a previsão do tempo para a cidade de Tóquio?", category: .notFound)
        ]
    }

    private func makeBenchmarkCorpus() -> [IndexedChunk] {
        var items: [IndexedChunk] = []
        for item in makeFirstTenQA() + makeSecondTenQA() {
            items.append(IndexedChunk(kind: .qa, text: item.answerText, source: item.sourcePath, question: item.questionText))
        }

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
                guard items.count < 220 else { break }
                let kind: IndexedChunk.Kind = (counter % 3 == 0) ? .code : .document
                let src = (kind == .code) ? "Sources/Module\(round)/Part\(counter).swift" : "docs/spec_\(round)_\(counter).md"
                let text = "[\(keyword)] \(desc) Trecho de documentação e especificação técnica \(counter)."
                items.append(IndexedChunk(kind: kind, text: text, source: src))
                counter += 1
            }
        }
        return items
    }

    private func makeFirstTenQA() -> [QAItem] {
        [
            QAItem(questionText: "Qual é o objetivo principal do Teleprompter?",
                   answerText: "Auxiliar o apresentador na banca exibindo respostas curtas na lente do Ray-Ban Display.",
                   sourcePath: "qa/01-objetivo.md"),
            QAItem(questionText: "Por que foi escolhido Swift nativo?",
                   answerText: "Porque o Meta DAT SDK é nativo para iOS e exige integração de baixo nível.",
                   sourcePath: "qa/02-swift.md"),
            QAItem(questionText: "Qual o limiar de silêncio para detectar pergunta?",
                   answerText: "O detector de pausas utiliza 1.2 segundos de silêncio para confirmar o fim da fala.",
                   sourcePath: "qa/03-silencio.md"),
            QAItem(questionText: "Como funciona a política de RAG fechado?",
                   answerText: "O gerador só consulta trechos acima do limiar; se nada for encontrado, avisa.",
                   sourcePath: "qa/04-rag-fechado.md"),
            QAItem(questionText: "Qual a resolução nativa da lente?",
                   answerText: "A lente do Ray-Ban Display projeta imagem monocromática verde em 600 por 600 pixels.",
                   sourcePath: "qa/05-resolucao.md"),
            QAItem(questionText: "Qual o formato do áudio recebido dos óculos?",
                   answerText: "O canal Bluetooth HFP entrega áudio de voz em 8 kHz mono linear PCM.",
                   sourcePath: "qa/06-audio.md"),
            QAItem(questionText: "Qual a meta de latência até o primeiro texto?",
                   answerText: "A meta do PRD é exibir as primeiras palavras da resposta em menos de 2 segundos.",
                   sourcePath: "qa/07-latencia.md"),
            QAItem(questionText: "O que acontece se a rede cair na apresentação?",
                   answerText: "O app opera offline respondendo diretamente as perguntas mapeadas nas notas locais.",
                   sourcePath: "qa/08-offline.md"),
            QAItem(questionText: "Onde ficam armazenadas as chaves de API?",
                   answerText: "Todas as credenciais sensíveis ficam seguras no Keychain do dispositivo.",
                   sourcePath: "qa/09-keychain.md"),
            QAItem(questionText: "Quantas linhas cabem no display da lente?",
                   answerText: "O formato seguro da lente comporta até 5 linhas com no máximo 28 caracteres.",
                   sourcePath: "qa/10-linhas.md")
        ]
    }

    private func makeSecondTenQA() -> [QAItem] {
        [
            QAItem(questionText: "Qual motor de reconhecimento de fala é utilizado?",
                   answerText: "O sistema adota o SpeechAnalyzer com SpeechTranscriber on-device no iOS 26.",
                   sourcePath: "qa/11-stt.md"),
            QAItem(questionText: "Qual a tolerância de erro de palavras WER?",
                   answerText: "O critério US-01 estabelece taxa de erro de palavras abaixo de 15%.",
                   sourcePath: "qa/12-wer.md"),
            QAItem(questionText: "Como funciona o caminho rápido de busca?",
                   answerText: "Notas de Q&A acima de 0.40 são entregues diretamente à lente sem LLM.",
                   sourcePath: "qa/13-fastpath.md"),
            QAItem(questionText: "Qual mecanismo de banco suporta a busca local?",
                   answerText: "Utiliza-se SQLite embarcado com tabelas virtuais FTS5 e tokenizador unicode61.",
                   sourcePath: "qa/14-sqlite.md"),
            QAItem(questionText: "Quais formatos de resposta estão disponíveis?",
                   answerText: "Estão disponíveis bullets curtos, palavras-chave ou texto resumido.",
                   sourcePath: "qa/15-formatos.md"),
            QAItem(questionText: "Como funciona a lente simulada para testes?",
                   answerText: "A SimulatedLens espelha a projeção em uma janela SwiftUI de 600x600.",
                   sourcePath: "qa/16-simulada.md"),
            QAItem(questionText: "Existe backend próprio intermediando o app?",
                   answerText: "Não há backend intermediário; o iPhone comanda as requisições diretamente.",
                   sourcePath: "qa/17-sem-backend.md"),
            QAItem(questionText: "Como o Neural Band interage com a apresentação?",
                   answerText: "Gestos na pulseira permitem pedir para repetir ou descartar a resposta.",
                   sourcePath: "qa/18-neural-band.md"),
            QAItem(questionText: "Qual o tratamento de privacidade para dados de voz?",
                   answerText: "Nenhum texto de fala é registrado em log e o pipeline opera localmente.",
                   sourcePath: "qa/19-privacidade.md"),
            QAItem(questionText: "Quando será realizada a defesa perante a banca?",
                   answerText: "A apresentação está agendada para novembro de 2027 com auxílio autorizado.",
                   sourcePath: "qa/20-cronograma.md")
        ]
    }
}
