import XCTest
@testable import Teleprompter

final class QuestionDetectorTests: XCTestCase {
    func testEmitsOnceWhenSilenceMeetsThreshold() {
        var detector = PauseQuestionDetector(silenceThreshold: 1.2)
        let transcript = Transcript(text: "Qual é a arquitetura?", isFinal: false)

        XCTAssertNil(detector.feed(transcript, silenceSeconds: 0.5))
        XCTAssertEqual(detector.feed(transcript, silenceSeconds: 1.2), "Qual é a arquitetura?")
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 1.3))
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 2.0))
    }

    func testDoesNotEmitBelowThreshold() {
        var detector = PauseQuestionDetector(silenceThreshold: 1.2)
        let transcript = Transcript(text: "Como funciona?", isFinal: false)

        XCTAssertNil(detector.feed(transcript, silenceSeconds: 0.0))
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 0.6))
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 1.19))
    }

    func testDoesNotEmitForEmptyOrWhitespaceText() {
        var detector = PauseQuestionDetector(silenceThreshold: 1.2)

        XCTAssertNil(detector.feed(Transcript(text: "", isFinal: false), silenceSeconds: 2.0))
        XCTAssertNil(detector.feed(Transcript(text: "   \n\t  ", isFinal: false), silenceSeconds: 2.0))
        XCTAssertNil(detector.feed(Transcript(text: "", isFinal: true), silenceSeconds: 2.0))
    }

    func testPartialRewriteReplacesInsteadOfConcatenating() {
        var detector = PauseQuestionDetector(silenceThreshold: 1.2)

        XCTAssertNil(detector.feed(Transcript(text: "Qual", isFinal: false), silenceSeconds: 0.1))
        XCTAssertNil(detector.feed(Transcript(text: "Qual o", isFinal: false), silenceSeconds: 0.2))
        XCTAssertNil(detector.feed(Transcript(text: "Qual o prazo final?", isFinal: false), silenceSeconds: 0.3))

        let emitted = detector.feed(Transcript(text: "Qual o prazo final?", isFinal: false), silenceSeconds: 1.2)
        XCTAssertEqual(emitted, "Qual o prazo final?")
    }

    func testTwoConsecutiveQuestionsEmitIndependently() {
        var detector = PauseQuestionDetector(silenceThreshold: 1.2)

        XCTAssertNil(detector.feed(Transcript(text: "Primeira pergunta?", isFinal: false), silenceSeconds: 0.2))
        XCTAssertEqual(detector.feed(Transcript(text: "Primeira pergunta?", isFinal: false), silenceSeconds: 1.2), "Primeira pergunta?")
        XCTAssertNil(detector.feed(Transcript(text: "Primeira pergunta?", isFinal: false), silenceSeconds: 1.5))

        XCTAssertNil(detector.feed(Transcript(text: "Segunda pergunta?", isFinal: false), silenceSeconds: 0.1))
        XCTAssertEqual(detector.feed(Transcript(text: "Segunda pergunta?", isFinal: false), silenceSeconds: 1.2), "Segunda pergunta?")
        XCTAssertNil(detector.feed(Transcript(text: "Segunda pergunta?", isFinal: false), silenceSeconds: 1.6))
    }

    func testCustomSilenceThreshold() {
        var detector = PauseQuestionDetector(silenceThreshold: 0.8)
        let transcript = Transcript(text: "Pergunta rápida?", isFinal: false)

        XCTAssertNil(detector.feed(transcript, silenceSeconds: 0.5))
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 0.79))
        XCTAssertEqual(detector.feed(transcript, silenceSeconds: 0.8), "Pergunta rápida?")
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 1.0))
    }

    func testRepeatedCallsWithHighSilenceDoNotEmitAgain() {
        var detector = PauseQuestionDetector(silenceThreshold: 1.2)
        let transcript = Transcript(text: "Pergunta teste", isFinal: false)

        XCTAssertEqual(detector.feed(transcript, silenceSeconds: 1.2), "Pergunta teste")
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 1.3))
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 1.8))
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 5.0))
    }

    func testExplicitResetAllowsReemission() {
        var detector = PauseQuestionDetector(silenceThreshold: 1.2)
        let transcript = Transcript(text: "Pergunta repetida", isFinal: false)

        XCTAssertEqual(detector.feed(transcript, silenceSeconds: 1.2), "Pergunta repetida")
        XCTAssertNil(detector.feed(transcript, silenceSeconds: 1.5))

        detector.reset()

        XCTAssertEqual(detector.feed(transcript, silenceSeconds: 1.2), "Pergunta repetida")
    }
}
