import Foundation

struct PauseQuestionDetector: QuestionDetector {
    let silenceThreshold: Double

    private var lastEmittedText: String?

    init(silenceThreshold: Double = 1.2) {
        self.silenceThreshold = silenceThreshold
    }

    mutating func feed(_ transcript: Transcript, silenceSeconds: Double) -> String? {
        let text = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            lastEmittedText = nil
            return nil
        }

        if silenceSeconds < silenceThreshold {
            lastEmittedText = nil
            return nil
        }

        guard text != lastEmittedText else {
            return nil
        }

        lastEmittedText = text
        return text
    }

    mutating func reset() {
        lastEmittedText = nil
    }
}
