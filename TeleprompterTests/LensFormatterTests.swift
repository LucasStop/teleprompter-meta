import XCTest
@testable import Teleprompter

final class LensFormatterTests: XCTestCase {
    private let fmt = LensFormatter()

    private func lines(_ text: String, _ format: AnswerFormat) -> [String] {
        fmt.format(text, as: format).components(separatedBy: "\n")
    }

    func testBulletsFromListLines() {
        let out = lines("- DAT SDK só tem Swift\n- Menor latência", .bullets)
        XCTAssertEqual(out, ["• DAT SDK só tem Swift", "• Menor latência"])
    }

    func testBulletsFromSentences() {
        let out = lines("O SDK é Swift. A latência é menor.", .bullets)
        XCTAssertEqual(out, ["• O SDK é Swift", "• A latência é menor"])
    }

    func testBulletsWrapWithIndent() {
        let out = lines("- Acesso direto ao SpeechAnalyzer do iOS", .bullets)
        XCTAssertEqual(out, ["• Acesso direto ao", "  SpeechAnalyzer do iOS"])
    }

    func testKeywordsOnePerLine() {
        XCTAssertEqual(lines("DAT SDK, Swift, Baixa latência", .keywords), ["DAT SDK", "Swift", "Baixa latência"])
    }

    func testFullTextWrapsAtWidth() {
        let out = lines("O SDK da Meta só oferece módulos Swift e o app precisa de microfone", .fullText)
        XCTAssertTrue(out.allSatisfy { $0.count <= LensFormatter.maxChars })
        XCTAssertEqual(out.joined(separator: " "), "O SDK da Meta só oferece módulos Swift e o app precisa de microfone")
    }

    func testNeverExceedsLimitsAndMarksCut() {
        let long = (1...40).map { "palavra\($0)" }.joined(separator: " ")
        for format in AnswerFormat.allCases {
            let out = lines(long, format)
            XCTAssertLessThanOrEqual(out.count, LensFormatter.maxLines, "\(format)")
            XCTAssertTrue(out.allSatisfy { $0.count <= LensFormatter.maxChars }, "\(format)")
        }
        XCTAssertTrue(lines(long, .fullText).last!.hasSuffix("…"))
    }

    func testEmptyTextGivesEmpty() {
        XCTAssertEqual(fmt.format("  \n ", as: .bullets), "")
    }
}
