import Foundation
import XCTest
@testable import Teleprompter

final class STTTranscriberTests: XCTestCase {
    func testTranscriberInstantiationAndLocale() {
        let transcriber = SpeechAnalyzerTranscriber(locale: Locale(identifier: "pt-BR"))
        XCTAssertEqual(transcriber.locale.identifier, "pt-BR")
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

    func testSTTErrorDescriptions() {
        XCTAssertNotNil(STTError.unavailable.errorDescription)
        XCTAssertNotNil(STTError.conversionFailed.errorDescription)
        XCTAssertNotNil(STTError.unsupportedLocale(Locale(identifier: "pt-BR")).errorDescription)
        XCTAssertNotNil(STTError.internalError("falha").errorDescription)
    }
}
