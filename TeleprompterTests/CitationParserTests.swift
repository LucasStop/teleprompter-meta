import Foundation
import UIKit
import XCTest
@testable import Teleprompter

final class CitationParserTests: XCTestCase {
    func testCitationInIntervalBecomesSuperscriptCitation() {
        let input = "DAT SDK só tem módulos Swift[1]"
        let attr = CitationParser.parse(input, sourceCount: 1)
        let plain = String(attr.characters)

        XCTAssertEqual(plain, "DAT SDK só tem módulos Swift1")

        // Verifica que o número 1 recebeu atributo de citação e estilo sobrescrito
        var foundCitationRun = false
        for run in attr.runs where run[CitationAttribute.self] == 1 {
            foundCitationRun = true
            XCTAssertEqual(run.uiKit.baselineOffset, 4)
            XCTAssertNotNil(run.uiKit.font)
            XCTAssertNotNil(run.uiKit.foregroundColor)
        }
        XCTAssertTrue(foundCitationRun, "Deveria conter run de citação com valor 1")
    }

    func testCitationOutOfIntervalIsRemoved() {
        let input = "Texto fora [9] do intervalo"
        let attr = CitationParser.parse(input, sourceCount: 2)
        let plain = String(attr.characters)

        XCTAssertEqual(plain, "Texto fora  do intervalo")
        XCTAssertFalse(attr.runs.contains(where: { $0[CitationAttribute.self] != nil }))

        // Também testa quando sourceCount == 0
        let attrNoSources = CitationParser.parse("Texto [1] sem fontes", sourceCount: 0)
        XCTAssertEqual(String(attrNoSources.characters), "Texto  sem fontes")
    }

    func testTextWithoutCitationRemainsIntact() {
        let input = "Texto sem nenhum marcador de citação."
        let attr = CitationParser.parse(input, sourceCount: 3)
        let plain = String(attr.characters)

        XCTAssertEqual(plain, input)
        XCTAssertFalse(attr.runs.contains(where: { $0[CitationAttribute.self] != nil }))
    }

    func testCitationAttachedToMarkdownBold() {
        let input = "**x**[2]"
        let attr = CitationParser.parse(input, sourceCount: 2)
        let plain = String(attr.characters)

        XCTAssertEqual(plain, "x2")

        var foundBoldX = false
        var foundCitation2 = false
        for run in attr.runs {
            let runText = String(attr[run.range].characters)
            if runText == "x" {
                foundBoldX = true
                XCTAssertEqual(run.inlinePresentationIntent, .stronglyEmphasized)
            } else if runText == "2" {
                foundCitation2 = true
                XCTAssertEqual(run[CitationAttribute.self], 2)
                XCTAssertEqual(run.uiKit.baselineOffset, 4)
            }
        }
        XCTAssertTrue(foundBoldX, "Deveria ter 'x' em negrito")
        XCTAssertTrue(foundCitation2, "Deveria ter '2' como citação")
    }

    func testStripCitationsForLens() {
        let input1 = "• DAT SDK só tem módulos Swift[1]\n• Menor latência de áudio[2]"
        let stripped1 = CitationParser.stripCitations(input1)
        XCTAssertEqual(stripped1, "• DAT SDK só tem módulos Swift\n• Menor latência de áudio")

        let input2 = "**x**[2]"
        let stripped2 = CitationParser.stripCitations(input2)
        XCTAssertEqual(stripped2, "**x**")

        let input3 = "Texto [1] com espaço antes"
        let stripped3 = CitationParser.stripCitations(input3)
        XCTAssertEqual(stripped3, "Texto com espaço antes")

        let input4 = "Texto sem marcadores"
        let stripped4 = CitationParser.stripCitations(input4)
        XCTAssertEqual(stripped4, "Texto sem marcadores")
    }

    func testMessageBubbleMarkdownDelegatesToCitationParser() {
        let rendered = MessageBubble.markdown("Acesso ao **SpeechAnalyzer**[2]", sourceCount: 2)
        let plain = String(rendered.characters)
        XCTAssertEqual(plain, "Acesso ao SpeechAnalyzer2")
        XCTAssertTrue(rendered.runs.contains(where: { $0[CitationAttribute.self] == 2 }))
    }
}
