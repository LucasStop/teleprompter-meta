import Foundation
import XCTest
@testable import Teleprompter

final class MaterialChunkerTests: XCTestCase {
    func testEmptyAndWhitespaceReturnsEmptyChunks() {
        let chunker = MaterialChunker(maxCharacters: 100, overlapCharacters: 20)

        XCTAssertTrue(chunker.chunk(text: "", source: "teste.txt", kind: .document).isEmpty)
        XCTAssertTrue(chunker.chunk(text: "   \n\t  \n  ", source: "teste.txt", kind: .document).isEmpty)
    }

    func testRespectsMaxCharactersLimit() {
        let chunker = MaterialChunker(maxCharacters: 120, overlapCharacters: 20)
        let longParagraph = """
        O objetivo do Teleprompter é auxiliar o apresentador na defesa de mestrado ou doutorado. \
        O sistema captura áudio, transcreve em tempo real e busca respostas nas notas de Q&A \
        e nos documentos do projeto, exibindo tudo na lente dos óculos inteligentes.
        """

        let chunks = chunker.chunk(text: longParagraph, source: "long.md", kind: .document)
        XCTAssertGreaterThan(chunks.count, 1)

        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.text.count, 140)
            XCTAssertEqual(chunk.source.path, "long.md")
            XCTAssertEqual(chunk.kind, .document)
        }
    }

    func testConsecutiveChunksHaveOverlap() {
        let chunker = MaterialChunker(maxCharacters: 100, overlapCharacters: 30)
        let text = """
        Primeira frase muito importante com contexto crucial. Segunda frase detalhando os requisitos arquiteturais.
        Terceira frase apresentando as conclusões do experimento e considerações finais para a banca examinadora.
        """

        let chunks = chunker.chunk(text: text, source: "overlap.md", kind: .document)
        XCTAssertGreaterThanOrEqual(chunks.count, 2)

        // Verifica que trechos consecutivos compartilham contexto
        for index in 0..<(chunks.count - 1) {
            let first = chunks[index].text
            let second = chunks[index + 1].text

            // Alguma palavra do fim do primeiro deve estar no segundo ou início do segundo
            let firstWords = Set(first.components(separatedBy: .whitespacesAndNewlines).suffix(4))
            let secondWords = Set(second.components(separatedBy: .whitespacesAndNewlines).prefix(6))
            let common = firstWords.intersection(secondWords)
            XCTAssertFalse(common.isEmpty, "Deveria haver palavras em comum na sobreposição entre trecho \(index) e \(index + 1)")
        }
    }

    func testSplitsParagraphsAndPreservesSourcesAndKind() {
        let chunker = MaterialChunker(maxCharacters: 500, overlapCharacters: 50)
        let text = """
        Seção 1: Introdução ao sistema de teleprompter inteligente.

        Seção 2: Detalhes de implementação do pipeline em Swift 6.

        Seção 3: Conclusões e validação com perguntas da banca.
        """

        let chunks = chunker.chunk(text: text, source: "Main.swift", kind: .code)
        XCTAssertFalse(chunks.isEmpty)

        for chunk in chunks {
            XCTAssertEqual(chunk.kind, .code)
            XCTAssertEqual(chunk.source.path, "Main.swift")
            XCTAssertFalse(chunk.text.isEmpty)
        }
    }
}
