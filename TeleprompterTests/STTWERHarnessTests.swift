import Foundation
import XCTest
@testable import Teleprompter

final class WERHarnessTests: XCTestCase {
    func testWordErrorRateOnRecordedQuestions() async throws {
        let isSTTEnabled = ProcessInfo.processInfo.environment["RUN_STT"] == "1" ||
            ProcessInfo.processInfo.environment["SIMCTL_CHILD_RUN_STT"] == "1"
        try XCTSkipUnless(
            isSTTEnabled,
            "STT real desativado (ative com RUN_STT=1)."
        )

        guard #available(iOS 26, *) else {
            throw XCTSkip("SpeechAnalyzer requer iOS 26 ou superior.")
        }

        let fixturesDirectory = findFixturesDirectory()
        guard let dirURL = fixturesDirectory else {
            throw XCTSkip(skipMessage)
        }

        let datasets = WERDatasetDiscovery.discoverDatasets(in: dirURL)
        let totalSamples = datasets.reduce(0) { $0 + $1.pairs.count }
        guard totalSamples > 0 else {
            throw XCTSkip(skipMessage)
        }

        let transcriber = SpeechAnalyzerTranscriber(locale: Locale(identifier: "pt-BR"))

        for dataset in datasets {
            var evaluations: [WERSampleEvaluation] = []
            for pair in dataset.pairs {
                let reference = try String(contentsOf: pair.txtURL, encoding: .utf8)
                let audioSource = FileAudioSource(url: pair.wavURL)
                let hypothesis = await transcribeAll(source: audioSource, using: transcriber)
                let wer = WordErrorRate.calculate(reference: reference, hypothesis: hypothesis)

                evaluations.append(WERSampleEvaluation(
                    pair: pair,
                    reference: reference,
                    hypothesis: hypothesis,
                    wer: wer
                ))
            }

            let report = WERDatasetEvaluation(datasetName: dataset.name, evaluations: evaluations)
            print(report.formattedSummary)

            if dataset.name.lowercased() == "humano" {
                let averageString = String(format: "%.2f%%", report.averageWER * 100)
                XCTAssertLessThanOrEqual(
                    report.averageWER,
                    0.15,
                    "WER médio do conjunto humano (\(averageString)) acima da meta de 15% (PRD US-01)."
                )
            }
        }
    }

    private var skipMessage: String {
        "Nenhum áudio encontrado nos conjuntos de Fixtures/perguntas. " +
        "Gere os áudios sintéticos com tools/gerar-audios.sh ou grave na pasta humano/."
    }

    private func transcribeAll(
        source: FileAudioSource,
        using transcriber: SpeechAnalyzerTranscriber
    ) async -> String {
        var hypothesis = ""
        for await transcript in transcriber.transcribe(source.start()) {
            if transcript.isFinal {
                hypothesis = transcript.text
            } else if hypothesis.isEmpty {
                hypothesis = transcript.text
            }
        }
        return hypothesis
    }

    private func findFixturesDirectory() -> URL? {
        if let bundleResource = Bundle(for: Self.self).url(forResource: "perguntas", withExtension: nil) {
            return bundleResource
        }
        let testFileSourceURL = URL(fileURLWithPath: #filePath)
        let candidate = testFileSourceURL
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/perguntas")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        return nil
    }

    // MARK: - Testes Unitários de Pareamento de Arquivos (sem STT real)

    func testDatasetDiscoveryPairsSubfolderWavWithParentTxt() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Root/01.txt
        let parentTxt = tempDir.appendingPathComponent("01.txt")
        try "Qual a diferença entre requisito funcional e não funcional?".write(
            to: parentTxt,
            atomically: true,
            encoding: .utf8
        )

        // Root/voz-a/01.wav
        let vozA = tempDir.appendingPathComponent("voz-a")
        try FileManager.default.createDirectory(at: vozA, withIntermediateDirectories: true)
        let wavA = vozA.appendingPathComponent("01.wav")
        try Data("dummy wav".utf8).write(to: wavA)

        let datasets = WERDatasetDiscovery.discoverDatasets(in: tempDir)

        XCTAssertEqual(datasets.count, 1)
        guard let firstDataset = datasets.first else { return }
        XCTAssertEqual(firstDataset.name, "voz-a")
        XCTAssertEqual(firstDataset.pairs.count, 1)
        XCTAssertEqual(firstDataset.pairs.first?.sampleName, "01")
        XCTAssertEqual(firstDataset.pairs.first?.wavURL, wavA)
        XCTAssertEqual(firstDataset.pairs.first?.txtURL, parentTxt)
    }

    func testDatasetDiscoveryPrefersLocalTxtOverParentTxt() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Root/01.txt
        let parentTxt = tempDir.appendingPathComponent("01.txt")
        try "Pergunta genérica".write(to: parentTxt, atomically: true, encoding: .utf8)

        // Root/humano/01.wav e Root/humano/01.txt
        let humanoDir = tempDir.appendingPathComponent("humano")
        try FileManager.default.createDirectory(at: humanoDir, withIntermediateDirectories: true)
        let wavURL = humanoDir.appendingPathComponent("01.wav")
        try Data("dummy wav".utf8).write(to: wavURL)
        let localTxt = humanoDir.appendingPathComponent("01.txt")
        try "Gravação humana específica".write(to: localTxt, atomically: true, encoding: .utf8)

        let datasets = WERDatasetDiscovery.discoverDatasets(in: tempDir)

        XCTAssertEqual(datasets.count, 1)
        guard let firstDataset = datasets.first else { return }
        XCTAssertEqual(firstDataset.name, "humano")
        XCTAssertEqual(firstDataset.pairs.count, 1)
        XCTAssertEqual(firstDataset.pairs.first?.txtURL, localTxt)
        let content = try String(contentsOf: try XCTUnwrap(firstDataset.pairs.first?.txtURL), encoding: .utf8)
        XCTAssertEqual(content, "Gravação humana específica")
    }

    func testDatasetDiscoveryIgnoresSubdirectoriesWithoutWav() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let emptyDir = tempDir.appendingPathComponent("vazia")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        try "apenas texto".write(to: emptyDir.appendingPathComponent("01.txt"), atomically: true, encoding: .utf8)

        let datasets = WERDatasetDiscovery.discoverDatasets(in: tempDir)
        XCTAssertTrue(datasets.isEmpty)
    }

    func testDatasetDiscoveryIgnoresWavWithoutReferenceTxt() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let vozA = tempDir.appendingPathComponent("voz-a")
        try FileManager.default.createDirectory(at: vozA, withIntermediateDirectories: true)
        try Data("dummy".utf8).write(to: vozA.appendingPathComponent("99.wav"))

        let datasets = WERDatasetDiscovery.discoverDatasets(in: tempDir)
        XCTAssertTrue(datasets.isEmpty)
    }

    func testDatasetDiscoveryOrdersDatasetsAndSamplesAlphabetically() throws {
        let tempDir = try createTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try "p01".write(to: tempDir.appendingPathComponent("01.txt"), atomically: true, encoding: .utf8)
        try "p02".write(to: tempDir.appendingPathComponent("02.txt"), atomically: true, encoding: .utf8)

        let vozB = tempDir.appendingPathComponent("voz-b")
        let vozA = tempDir.appendingPathComponent("voz-a")
        try FileManager.default.createDirectory(at: vozB, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: vozA, withIntermediateDirectories: true)

        try Data("b02".utf8).write(to: vozB.appendingPathComponent("02.wav"))
        try Data("b01".utf8).write(to: vozB.appendingPathComponent("01.wav"))
        try Data("a01".utf8).write(to: vozA.appendingPathComponent("01.wav"))

        let datasets = WERDatasetDiscovery.discoverDatasets(in: tempDir)

        XCTAssertEqual(datasets.map(\.name), ["voz-a", "voz-b"])
        XCTAssertEqual(datasets[0].pairs.map(\.sampleName), ["01"])
        XCTAssertEqual(datasets[1].pairs.map(\.sampleName), ["01", "02"])
    }

    func testWERDatasetEvaluationCalculatesAverageAndWorstSample() {
        let dummyWav = URL(fileURLWithPath: "/tmp/dummy.wav")
        let dummyTxt = URL(fileURLWithPath: "/tmp/dummy.txt")

        let eval1 = WERSampleEvaluation(
            pair: WERSamplePair(datasetName: "voz-a", sampleName: "01", wavURL: dummyWav, txtURL: dummyTxt),
            reference: "como funciona o rag",
            hypothesis: "como funciona o rag",
            wer: 0.0
        )
        let eval2 = WERSampleEvaluation(
            pair: WERSamplePair(datasetName: "voz-a", sampleName: "02", wavURL: dummyWav, txtURL: dummyTxt),
            reference: "o gato subiu no telhado",
            hypothesis: "o cachorro subiu no telhado",
            wer: 0.20
        )
        let eval3 = WERSampleEvaluation(
            pair: WERSamplePair(datasetName: "voz-a", sampleName: "03", wavURL: dummyWav, txtURL: dummyTxt),
            reference: "palavra",
            hypothesis: "outra",
            wer: 1.00
        )

        let report = WERDatasetEvaluation(datasetName: "voz-a", evaluations: [eval1, eval2, eval3])

        XCTAssertEqual(report.averageWER, 0.40, accuracy: 0.0001)
        XCTAssertEqual(report.worstEvaluation?.pair.sampleName, "03")
        XCTAssertEqual(report.worstEvaluation?.wer, 1.00)
        XCTAssertTrue(report.formattedSummary.contains("Relatório de WER: conjunto [voz-a]"))
        XCTAssertTrue(report.formattedSummary.contains("Pior pergunta: 03"))
    }

    private func createTempDirectory() throws -> URL {
        let tempBase = FileManager.default.temporaryDirectory
        let uniqueDir = tempBase.appendingPathComponent("WERDiscoveryTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: uniqueDir, withIntermediateDirectories: true)
        return uniqueDir
    }
}
