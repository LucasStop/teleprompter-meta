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

        let wavFiles = collectWavFiles(from: dirURL)
        guard !wavFiles.isEmpty else {
            throw XCTSkip(skipMessage)
        }

        let transcriber = SpeechAnalyzerTranscriber(locale: Locale(identifier: "pt-BR"))
        let (totalWER, evaluatedCount) = try await evaluate(wavFiles: wavFiles, using: transcriber)

        guard evaluatedCount > 0 else {
            throw XCTSkip(skipMessage)
        }

        let averageWER = totalWER / Double(evaluatedCount)
        let averageString = String(format: "%.2f%%", averageWER * 100)
        print("WER médio: \(averageString)")

        XCTAssertLessThanOrEqual(
            averageWER,
            0.15,
            "WER médio (\(averageString)) acima da meta de 15% (PRD US-01)."
        )
    }

    private var skipMessage: String {
        "Nenhum áudio encontrado na pasta Fixtures/perguntas. " +
        "Gravar em 8 kHz mono, nome NN.wav e NN.txt (as 30 perguntas serão gravadas pelo Lucas)."
    }

    private func collectWavFiles(from dirURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: dirURL,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else { return [] }

        var wavFiles: [URL] = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension.lowercased() == "wav" {
            wavFiles.append(fileURL)
        }
        return wavFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func evaluate(
        wavFiles: [URL],
        using transcriber: SpeechAnalyzerTranscriber
    ) async throws -> (totalWER: Double, evaluatedCount: Int) {
        var totalWER: Double = 0.0
        var evaluatedCount = 0

        for wavURL in wavFiles {
            let txtURL = wavURL.deletingPathExtension().appendingPathExtension("txt")
            guard FileManager.default.fileExists(atPath: txtURL.path) else { continue }

            let reference = try String(contentsOf: txtURL, encoding: .utf8)
            let audioSource = FileAudioSource(url: wavURL)
            let hypothesis = await transcribeAll(source: audioSource, using: transcriber)

            let wer = WordErrorRate.calculate(reference: reference, hypothesis: hypothesis)
            totalWER += wer
            evaluatedCount += 1

            let percentageString = String(format: "%.2f%%", wer * 100)
            print("WER [\(wavURL.lastPathComponent)]: \(percentageString)")
        }

        return (totalWER, evaluatedCount)
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
}
