import Foundation
import XCTest
@testable import Teleprompter

final class STTWordErrorRateTests: XCTestCase {
    func testEqualStringsReturnZero() {
        XCTAssertEqual(
            WordErrorRate.calculate(
                reference: "Como funciona o RAG?",
                hypothesis: "como funciona o rag"
            ),
            0.0,
            accuracy: 0.0001
        )

        XCTAssertEqual(
            WordErrorRate.calculate(
                reference: "Apresentação da banca avaliadora!",
                hypothesis: "apresentacao da banca avaliadora"
            ),
            0.0,
            accuracy: 0.0001
        )
    }

    func testOneSubstitution() {
        XCTAssertEqual(
            WordErrorRate.calculate(
                reference: "o gato subiu",
                hypothesis: "o cachorro subiu"
            ),
            1.0 / 3.0,
            accuracy: 0.0001
        )
    }

    func testOneInsertion() {
        XCTAssertEqual(
            WordErrorRate.calculate(
                reference: "o gato subiu",
                hypothesis: "o gato preto subiu"
            ),
            1.0 / 3.0,
            accuracy: 0.0001
        )
    }

    func testOneDeletion() {
        XCTAssertEqual(
            WordErrorRate.calculate(
                reference: "o gato subiu",
                hypothesis: "o gato"
            ),
            1.0 / 3.0,
            accuracy: 0.0001
        )
    }

    func testEmptyStrings() {
        XCTAssertEqual(WordErrorRate.calculate(reference: "", hypothesis: ""), 0.0)
        XCTAssertEqual(WordErrorRate.calculate(reference: "   ", hypothesis: ""), 0.0)
        XCTAssertEqual(WordErrorRate.calculate(reference: "", hypothesis: "palavra"), 1.0)
        XCTAssertEqual(WordErrorRate.calculate(reference: "palavra", hypothesis: ""), 1.0)
    }

    func testAccentsAndPunctuationNormalization() {
        XCTAssertEqual(
            WordErrorRate.calculate(
                reference: "É ação e reação!",
                hypothesis: "e acao e reacao"
            ),
            0.0,
            accuracy: 0.0001
        )
    }
}
