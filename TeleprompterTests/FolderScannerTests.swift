import Foundation
import XCTest
@testable import Teleprompter

final class FolderScannerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FolderScannerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory, FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - 1. Extensões Válidas e Inválidas

    func testValidExtensionsAreAccepted() throws {
        let validExtensions = ["md", "txt", "swift", "ts", "tsx", "js", "php", "py", "json", "yml", "yaml"]
        for ext in validExtensions {
            let fileURL = tempDirectory.appendingPathComponent("test.\(ext)")
            try "conteudo de teste".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let scanner = DefaultFolderScanner()
        let result = try scanner.scan(url: tempDirectory)

        XCTAssertEqual(result.validFiles.count, validExtensions.count)
        XCTAssertEqual(result.ignoredFiles.count, 0)
    }

    func testInvalidExtensionsAreIgnoredAsBinary() throws {
        let invalidFiles = ["image.png", "doc.pdf", "archive.zip", "sound.mp3", "video.mp4", "app.exe"]
        for file in invalidFiles {
            let fileURL = tempDirectory.appendingPathComponent(file)
            try "qualquer dado".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let scanner = DefaultFolderScanner()
        let result = try scanner.scan(url: tempDirectory)

        XCTAssertEqual(result.validFiles.count, 0)
        XCTAssertEqual(result.ignoredFiles.count, invalidFiles.count)
        for ignored in result.ignoredFiles {
            XCTAssertEqual(ignored.reason, .binary)
        }
    }

    // MARK: - 2. Diretórios Ignorados

    func testIgnoredDirectoriesAreExcluded() throws {
        let ignoredDirs = [
            ".git", "node_modules", "build", "build.noindex",
            "DerivedData", "Pods", "vendor", ".next", "dist", "graphify-out"
        ]

        for dir in ignoredDirs {
            let dirURL = tempDirectory.appendingPathComponent(dir)
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
            let fileURL = dirURL.appendingPathComponent("file.swift")
            try "print(\"hello\")".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // Arquivo válido na raiz
        let validURL = tempDirectory.appendingPathComponent("Root.swift")
        try "print(\"root\")".write(to: validURL, atomically: true, encoding: .utf8)

        let scanner = DefaultFolderScanner()
        let result = try scanner.scan(url: tempDirectory)

        XCTAssertEqual(result.validFiles.count, 1)
        XCTAssertEqual(result.validFiles.first?.relativePath, "Root.swift")
        XCTAssertEqual(result.ignoredFiles.count, ignoredDirs.count)
        for ignored in result.ignoredFiles {
            XCTAssertEqual(ignored.reason, .ignoredDirectory)
        }
    }

    // MARK: - 3. Arquivos Ocultos

    func testHiddenFilesAndDirectoriesAreIgnored() throws {
        let hiddenFiles = [".DS_Store", ".env", ".gitignore", ".custom_hidden.txt"]
        for name in hiddenFiles {
            let fileURL = tempDirectory.appendingPathComponent(name)
            try "secret=123".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        // Subdiretório oculto
        let hiddenDirURL = tempDirectory.appendingPathComponent(".cache")
        try FileManager.default.createDirectory(at: hiddenDirURL, withIntermediateDirectories: true)
        let cachedFileURL = hiddenDirURL.appendingPathComponent("data.json")
        try "{}".write(to: cachedFileURL, atomically: true, encoding: .utf8)

        // Arquivo válido
        let validURL = tempDirectory.appendingPathComponent("visible.txt")
        try "visivel".write(to: validURL, atomically: true, encoding: .utf8)

        let scanner = DefaultFolderScanner()
        let result = try scanner.scan(url: tempDirectory)

        XCTAssertEqual(result.validFiles.count, 1)
        XCTAssertEqual(result.validFiles.first?.relativePath, "visible.txt")
        XCTAssertEqual(result.ignoredFiles.count, hiddenFiles.count + 1)
        for ignored in result.ignoredFiles {
            XCTAssertEqual(ignored.reason, .hidden)
        }
    }

    // MARK: - 4. Binário (Não decodifica como UTF-8)

    func testBinaryFilesAreIgnored() throws {
        let validURL = tempDirectory.appendingPathComponent("texto.txt")
        try "texto valido".write(to: validURL, atomically: true, encoding: .utf8)

        // Arquivo com extensão válida (.txt), mas com bytes não decodificáveis como UTF-8
        let corruptedURL = tempDirectory.appendingPathComponent("corrupted.txt")
        let nonUtf8Bytes: [UInt8] = [0xFF, 0xFE, 0xFD, 0x80, 0x81, 0x82]
        try Data(nonUtf8Bytes).write(to: corruptedURL)

        let scanner = DefaultFolderScanner()
        let result = try scanner.scan(url: tempDirectory)

        XCTAssertEqual(result.validFiles.count, 1)
        XCTAssertEqual(result.validFiles.first?.relativePath, "texto.txt")
        XCTAssertEqual(result.ignoredFiles.count, 1)
        XCTAssertEqual(result.ignoredFiles.first?.relativePath, "corrupted.txt")
        XCTAssertEqual(result.ignoredFiles.first?.reason, .binary)
    }

    // MARK: - 5. Arquivo > 500 KB

    func testFilesOver500KBAreIgnored() throws {
        let smallURL = tempDirectory.appendingPathComponent("pequeno.txt")
        let smallData = Data(repeating: 65, count: 400 * 1024) // 400 KB
        try smallData.write(to: smallURL)

        let largeURL = tempDirectory.appendingPathComponent("grande.txt")
        let largeData = Data(repeating: 66, count: 501 * 1024) // 501 KB
        try largeData.write(to: largeURL)

        let scanner = DefaultFolderScanner()
        let result = try scanner.scan(url: tempDirectory)

        XCTAssertEqual(result.validFiles.count, 1)
        XCTAssertEqual(result.validFiles.first?.relativePath, "pequeno.txt")
        XCTAssertEqual(result.ignoredFiles.count, 1)
        XCTAssertEqual(result.ignoredFiles.first?.relativePath, "grande.txt")
        XCTAssertEqual(result.ignoredFiles.first?.reason, .tooLarge)
    }

    // MARK: - 6. Teto de 500 Arquivos Válidos

    func testCeilingOf500ValidFiles() throws {
        // Cria 505 arquivos válidos
        for index in 1...505 {
            let fileName = String(format: "file_%03d.txt", index)
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            try "arquivo \(index)".write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let scanner = DefaultFolderScanner()
        let result = try scanner.scan(url: tempDirectory)

        XCTAssertEqual(result.validFiles.count, 500)
        XCTAssertEqual(result.ignoredFiles.count, 5)
        for ignored in result.ignoredFiles {
            XCTAssertEqual(ignored.reason, .limitExceeded)
        }
    }

    // MARK: - 7. Classificação por Caminho

    func testPathClassification() {
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "qa/apresentacao.md"), .qa)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "qa/sub/perguntas.txt"), .qa)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "QA/FAQ.md"), .qa)

        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "README.md"), .document)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "README-pt.txt"), .document)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "sub/README.markdown"), .document)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "docs/PRD.md"), .document)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "docs/adr/ADR-0001.md"), .document)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "DOCS/overview.txt"), .document)

        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "Teleprompter/App.swift"), .code)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "src/index.ts"), .code)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "server.php"), .code)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "script.py"), .code)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "package.json"), .code)
        XCTAssertEqual(DefaultFolderScanner.classify(relativePath: "config.yml"), .code)
    }

    // MARK: - 8. Erro de Leitura

    func testUnreadableDirectoryThrowsError() {
        let nonExistentURL = tempDirectory.appendingPathComponent("non_existent_folder")
        let scanner = DefaultFolderScanner()

        XCTAssertThrowsError(try scanner.scan(url: nonExistentURL)) { error in
            guard let scannerError = error as? FolderScannerError else {
                XCTFail("Deveria lançar FolderScannerError")
                return
            }
            if case .unreadableFolder(let name, _) = scannerError {
                XCTAssertEqual(name, "non_existent_folder")
            } else {
                XCTFail("Esperado unreadableFolder")
            }
        }
    }
}
