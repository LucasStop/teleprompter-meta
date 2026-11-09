import Foundation
import XCTest
@testable import Teleprompter

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var progressValues: [Double] = []

    func record(_ progress: Progress) {
        lock.withLock {
            progressValues.append(progress.fractionCompleted)
        }
    }

    var recordedValues: [Double] {
        lock.withLock { progressValues }
    }
}

private final class ErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var error: STTError?

    func set(_ error: STTError) {
        lock.withLock { self.error = error }
    }

    var value: STTError? {
        lock.withLock { error }
    }
}

final class STTTranscriberTests: XCTestCase {
    func testTranscriberInstantiationAndLocale() {
        let transcriber = SpeechAnalyzerTranscriber(locale: Locale(identifier: "pt-BR"))
        XCTAssertEqual(transcriber.locale.identifier, "pt-BR")
    }

    func testSTTErrorDescriptions() {
        XCTAssertNotNil(STTError.unavailable.errorDescription)
        XCTAssertNotNil(STTError.conversionFailed.errorDescription)
        XCTAssertNotNil(STTError.unsupportedLocale(Locale(identifier: "pt-BR")).errorDescription)
        XCTAssertNotNil(STTError.internalError("falha").errorDescription)

        let downloadError = STTError.assetDownloadFailed("Sem espaço em disco")
        let description = downloadError.errorDescription
        XCTAssertNotNil(description)
        XCTAssertTrue(description?.contains("Sem espaço em disco") == true)
        XCTAssertTrue(description?.contains("espaço disponível") == true)
    }

    func testTranscriberWithAssetAlreadyInstalledDoesNotInstall() async {
        let fakeManager = FakeSpeechAssetManager(installedLocales: ["pt-BR"])
        let transcriber = SpeechAnalyzerTranscriber(
            locale: Locale(identifier: "pt-BR"),
            assetManager: fakeManager
        )
        let (audioStream, audioContinuation) = AsyncStream<Teleprompter.AudioBuffer>.makeStream()
        audioContinuation.finish()

        var results: [Transcript] = []
        for await transcript in transcriber.transcribe(audioStream) {
            results.append(transcript)
        }

        XCTAssertTrue(results.isEmpty)
        XCTAssertGreaterThan(fakeManager.isInstalledCallCount, 0)
        XCTAssertEqual(fakeManager.installCallCount, 0, "Quando já instalado, não deve chamar install")
    }

    func testTranscriberWithAssetNotInstalledDownloadsAndReportsProgressBeforeTranscribing() async {
        let fakeManager = FakeSpeechAssetManager(
            supportedLocales: ["pt-BR"],
            installedLocales: [],
            simulatedProgressSteps: [0.25, 0.5, 0.75, 1.0]
        )
        let recorder = ProgressRecorder()
        let transcriber = SpeechAnalyzerTranscriber(
            locale: Locale(identifier: "pt-BR"),
            assetManager: fakeManager,
            onProgress: { progress in
                recorder.record(progress)
            }
        )

        let (audioStream, audioContinuation) = AsyncStream<Teleprompter.AudioBuffer>.makeStream()
        audioContinuation.finish()

        var results: [Transcript] = []
        for await transcript in transcriber.transcribe(audioStream) {
            results.append(transcript)
        }

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(fakeManager.installCallCount, 1, "Quando não instalado, deve chamar install exatamente 1 vez")
        let recorded = recorder.recordedValues
        XCTAssertEqual(recorded, [0.25, 0.5, 0.75, 1.0], "Progresso deve ser reportado conforme o download avança")
    }

    func testTranscriberAssetDownloadFailureYieldsActionableSTTErrorAndFinishes() async {
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "A conexão com a internet parece estar inativa."]
        )
        let fakeManager = FakeSpeechAssetManager(
            supportedLocales: ["pt-BR"],
            installedLocales: [],
            installError: networkError
        )
        let errorBox = ErrorBox()
        let transcriber = SpeechAnalyzerTranscriber(
            locale: Locale(identifier: "pt-BR"),
            assetManager: fakeManager,
            onError: { error in
                errorBox.set(error)
            }
        )

        let (audioStream, audioContinuation) = AsyncStream<Teleprompter.AudioBuffer>.makeStream()
        audioContinuation.finish()

        var results: [Transcript] = []
        for await transcript in transcriber.transcribe(audioStream) {
            results.append(transcript)
        }

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(fakeManager.installCallCount, 1)

        guard let receivedError = errorBox.value else {
            XCTFail("Deveria ter recebido erro de download")
            return
        }

        switch receivedError {
        case .assetDownloadFailed(let reason):
            XCTAssertTrue(reason.contains("conexão"), "Mensagem de erro deve conter o motivo da falha")
            XCTAssertTrue(receivedError.localizedDescription.contains("conexão"), "Descrição deve ser acionável")
        default:
            XCTFail("Esperado STTError.assetDownloadFailed, recebido \(receivedError)")
        }
    }

    func testTranscriberUnsupportedLocaleYieldsUnsupportedLocaleErrorAndFinishes() async {
        let fakeManager = FakeSpeechAssetManager(
            supportedLocales: ["en-US"],
            installedLocales: []
        )
        let errorBox = ErrorBox()
        let transcriber = SpeechAnalyzerTranscriber(
            locale: Locale(identifier: "pt-BR"),
            assetManager: fakeManager,
            onError: { error in
                errorBox.set(error)
            }
        )

        let (audioStream, audioContinuation) = AsyncStream<Teleprompter.AudioBuffer>.makeStream()
        audioContinuation.finish()

        var results: [Transcript] = []
        for await transcript in transcriber.transcribe(audioStream) {
            results.append(transcript)
        }

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(fakeManager.installCallCount, 0, "Locale não suportado não deve tentar instalação")

        guard let receivedError = errorBox.value else {
            XCTFail("Deveria ter recebido erro de locale não suportado")
            return
        }

        XCTAssertEqual(
            receivedError,
            STTError.unsupportedLocale(Locale(identifier: "pt-BR")),
            "Esperado STTError.unsupportedLocale para pt-BR"
        )
    }

    func testSystemSpeechAssetManagerSupportedLocales() async {
        let manager = SystemSpeechAssetManager()
        if #available(iOS 26, *) {
            let isPtBRSupported = await manager.isSupported(for: Locale(identifier: "pt-BR"))
            XCTAssertTrue(isPtBRSupported)
            let isInvalidSupported = await manager.isSupported(for: Locale(identifier: "xx-YY"))
            XCTAssertFalse(isInvalidSupported)
        }
    }

    func testTranscriberWithEmptyStreamFinishesPromptly() async {
        let transcriber = SpeechAnalyzerTranscriber(locale: Locale(identifier: "pt-BR"))
        let (audioStream, audioContinuation) = AsyncStream<Teleprompter.AudioBuffer>.makeStream()
        audioContinuation.finish()

        var results: [Transcript] = []
        for await transcript in transcriber.transcribe(audioStream) {
            results.append(transcript)
        }

        XCTAssertTrue(results.isEmpty)
    }
}
