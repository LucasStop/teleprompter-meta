import Foundation
import XCTest
@testable import Teleprompter

final class MaterialImporterTests: XCTestCase {
    private var importer: MaterialImporter!

    override func setUp() {
        super.setUp()
        importer = MaterialImporter(chunker: MaterialChunker(maxCharacters: 300, overlapCharacters: 40))
    }

    func testEmptyContentThrowsEmptyFileError() {
        XCTAssertThrowsError(try importer.parse(content: "", sourceName: "vazio.md")) { error in
            guard let importError = error as? MaterialImporterError else {
                return XCTFail("Tipo de erro inesperado: \(error)")
            }
            XCTAssertEqual(importError, .emptyFile("vazio.md"))
            XCTAssertTrue(importError.localizedDescription.contains("vazio"))
        }

        XCTAssertThrowsError(try importer.parse(content: "   \n\n\t  ", sourceName: "espacos.txt")) { error in
            guard let importError = error as? MaterialImporterError else {
                return XCTFail("Tipo de erro inesperado: \(error)")
            }
            XCTAssertEqual(importError, .emptyFile("espacos.txt"))
        }
    }

    func testQAParserWithPRFormat() throws {
        let content = """
        P: Qual é o objetivo do projeto?
        R: Auxiliar o apresentador na defesa com respostas rápidas na lente do Ray-Ban Display.

        P: Por que usar Swift nativo?
        R: Porque o Meta DAT SDK só possui bindings para Swift e oferece menor latência de áudio.
        """

        let chunks = try importer.parse(content: content, sourceName: "qa/perguntas.md")
        XCTAssertEqual(chunks.count, 2)

        XCTAssertEqual(chunks[0].kind, .qa)
        XCTAssertEqual(chunks[0].question, "Qual é o objetivo do projeto?")
        XCTAssertEqual(chunks[0].text, "Auxiliar o apresentador na defesa com respostas rápidas na lente do Ray-Ban Display.")
        XCTAssertEqual(chunks[0].source.path, "qa/perguntas.md")

        XCTAssertEqual(chunks[1].kind, .qa)
        XCTAssertEqual(chunks[1].question, "Por que usar Swift nativo?")
        XCTAssertTrue(chunks[1].text.contains("Meta DAT SDK"))
    }

    func testQAParserWithVariationsAndMultilineAnswer() throws {
        let content = """
        Pergunta: Como funciona a busca no material?
        Resposta: A busca utiliza LocalRetriever sobre SQLite com extensão FTS5.
        Além disso, calcula similaridade semântica se houver embedder disponível.

        Q: Qual a plataforma alvo?
        A: iOS 17.2 ou superior em iPhone físico.
        """

        let chunks = try importer.parse(content: content, sourceName: "qa_variado.txt")
        XCTAssertEqual(chunks.count, 2)

        XCTAssertEqual(chunks[0].kind, .qa)
        XCTAssertEqual(chunks[0].question, "Como funciona a busca no material?")
        XCTAssertTrue(chunks[0].text.contains("FTS5"))
        XCTAssertTrue(chunks[0].text.contains("embedder"))

        XCTAssertEqual(chunks[1].kind, .qa)
        XCTAssertEqual(chunks[1].question, "Qual a plataforma alvo?")
        XCTAssertEqual(chunks[1].text, "iOS 17.2 ou superior em iPhone físico.")
    }

    func testQAParserWithFrontMatter() throws {
        let content = """
        ---
        pergunta: Qual é a arquitetura adotada no aplicativo?
        ---
        A arquitetura adota um pipeline linear estrito com protocolos isolados por etapa, \
        garantindo testabilidade com fakes sem depender do hardware real.
        """

        let chunks = try importer.parse(content: content, sourceName: "qa/arquitetura.md")
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0].kind, .qa)
        XCTAssertEqual(chunks[0].question, "Qual é a arquitetura adotada no aplicativo?")
        XCTAssertTrue(chunks[0].text.contains("pipeline linear estrito"))
    }

    func testMarkdownAndTextDocumentParsedAsDocumentKind() throws {
        let content = """
        # Visão Geral do Teleprompter
        O app foi concebido para uso pessoal durante apresentações e bancas avaliadoras.

        ## Decisões de Arquitetura
        Cada parte do pipeline segue um protocolo com fake correspondente nos testes.
        """

        let chunks = try importer.parse(content: content, sourceName: "README.md")
        XCTAssertFalse(chunks.isEmpty)
        for chunk in chunks {
            XCTAssertEqual(chunk.kind, .document)
            XCTAssertEqual(chunk.source.path, "README.md")
            XCTAssertNil(chunk.question)
        }
    }

    func testSourceCodeExtensionsParsedAsCodeKind() throws {
        let swiftCode = """
        import SwiftUI

        struct ContentView: View {
            var body: some View {
                Text("Olá Mundo")
            }
        }
        """

        let swiftChunks = try importer.parse(content: swiftCode, sourceName: "ContentView.swift")
        XCTAssertFalse(swiftChunks.isEmpty)
        XCTAssertEqual(swiftChunks.first?.kind, .code)

        let tsCode = "export const answer = 42;"
        let tsChunks = try importer.parse(content: tsCode, sourceName: "index.ts")
        XCTAssertEqual(tsChunks.first?.kind, .code)

        let phpCode = "<?php echo 'teste'; ?>"
        let phpChunks = try importer.parse(content: phpCode, sourceName: "script.php")
        XCTAssertEqual(phpChunks.first?.kind, .code)
    }
}
