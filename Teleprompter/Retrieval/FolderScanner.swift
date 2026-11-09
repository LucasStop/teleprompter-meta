import Foundation

/// Arquivo válido encontrado durante a varredura da pasta.
struct ScannedFile: Equatable, Sendable {
    let relativePath: String
    let url: URL
    let kind: IndexedChunk.Kind
    let size: Int64
}

/// Motivo pelo qual um arquivo ou diretório foi ignorado na varredura.
enum FolderIgnoreReason: String, CaseIterable, Equatable, Sendable {
    case ignoredDirectory
    case hidden
    case binary
    case tooLarge
    case limitExceeded

    var title: String {
        switch self {
        case .ignoredDirectory:
            return "Pastas de build e dependências"
        case .hidden:
            return "Arquivos ocultos"
        case .binary:
            return "Binários"
        case .tooLarge:
            return "Grandes demais"
        case .limitExceeded:
            return "Acima do limite"
        }
    }

    var subtitle: String {
        switch self {
        case .ignoredDirectory:
            return ".git, build, node_modules"
        case .hidden:
            return "iniciados com ponto"
        case .binary:
            return "imagens, áudio, zip"
        case .tooLarge:
            return "acima de 500 KB"
        case .limitExceeded:
            return "acima de 500 arquivos"
        }
    }
}

/// Item ignorado durante a varredura.
struct IgnoredFile: Equatable, Sendable {
    let relativePath: String
    let reason: FolderIgnoreReason
}

/// Agrupamento de itens ignorados para exibição na UI.
struct IgnoredGroup: Equatable, Sendable {
    let reason: FolderIgnoreReason
    let title: String
    let subtitle: String
    let count: Int
}

/// Resultado completo da varredura de uma pasta.
struct FolderScanResult: Equatable, Sendable {
    let folderName: String
    let folderURL: URL
    let validFiles: [ScannedFile]
    let ignoredFiles: [IgnoredFile]

    var qaCount: Int {
        validFiles.filter { $0.kind == .qa }.count
    }

    var documentCount: Int {
        validFiles.filter { $0.kind == .document }.count
    }

    var codeCount: Int {
        validFiles.filter { $0.kind == .code }.count
    }

    var ignoredGroups: [IgnoredGroup] {
        var groups: [IgnoredGroup] = []
        let orderedReasons: [FolderIgnoreReason] = [
            .ignoredDirectory,
            .tooLarge,
            .binary,
            .hidden,
            .limitExceeded
        ]
        for reason in orderedReasons {
            let count = ignoredFiles.filter { $0.reason == reason }.count
            if count > 0 {
                groups.append(IgnoredGroup(
                    reason: reason,
                    title: reason.title,
                    subtitle: reason.subtitle,
                    count: count
                ))
            }
        }
        return groups
    }
}

/// Erros possíveis ao tentar ler uma pasta.
enum FolderScannerError: LocalizedError, Equatable, Sendable {
    case unreadableFolder(name: String, reason: String)
    case notADirectory(name: String)

    var errorDescription: String? {
        switch self {
        case .unreadableFolder(let name, let reason):
            return "Não consegui ler a pasta \"\(name)\". \(reason)"
        case .notADirectory(let name):
            return "\"\(name)\" não é uma pasta válida."
        }
    }
}

/// Protocolo de varredura de pastas (sem SwiftUI, testável com FileManager/fakes).
protocol FolderScanning: Sendable {
    func scan(url: URL) throws -> FolderScanResult
}

/// Varredor padrão de pastas recursivo no sistema de arquivos.
struct DefaultFolderScanner: FolderScanning {
    static let defaultIgnoredDirectoryNames: Set<String> = [
        ".git",
        "node_modules",
        "build",
        "build.noindex",
        "deriveddata",
        "pods",
        "vendor",
        ".next",
        "dist",
        "graphify-out"
    ]

    static let defaultValidExtensions: Set<String> = [
        "md",
        "txt",
        "swift",
        "ts",
        "tsx",
        "js",
        "php",
        "py",
        "json",
        "yml",
        "yaml"
    ]

    static let maxFileSizeBytes: Int64 = 500 * 1024
    static let maxValidFilesCount: Int = 500

    let ignoredDirectoryNames: Set<String>
    let validExtensions: Set<String>
    let maxFileSizeBytes: Int64
    let maxValidFilesCount: Int

    init(
        ignoredDirectoryNames: Set<String> = defaultIgnoredDirectoryNames,
        validExtensions: Set<String> = defaultValidExtensions,
        maxFileSizeBytes: Int64 = maxFileSizeBytes,
        maxValidFilesCount: Int = maxValidFilesCount
    ) {
        self.ignoredDirectoryNames = ignoredDirectoryNames
        self.validExtensions = validExtensions
        self.maxFileSizeBytes = maxFileSizeBytes
        self.maxValidFilesCount = maxValidFilesCount
    }

    func scan(url: URL) throws -> FolderScanResult {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        try validateDirectory(at: url)

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: []
        ) else {
            throw FolderScannerError.unreadableFolder(name: url.lastPathComponent, reason: "Sem permissão de leitura.")
        }

        var validFiles: [ScannedFile] = []
        var ignoredFiles: [IgnoredFile] = []
        let basePrefix = makeBasePrefix(for: url)

        for case let itemURL as URL in enumerator {
            inspectItem(
                at: itemURL,
                basePrefix: basePrefix,
                validFiles: &validFiles,
                ignoredFiles: &ignoredFiles
            )
        }

        validFiles.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }

        let (finalValid, cappedIgnored) = applyCeiling(validFiles: validFiles)
        ignoredFiles.append(contentsOf: cappedIgnored)

        return FolderScanResult(
            folderName: url.lastPathComponent,
            folderURL: url,
            validFiles: finalValid,
            ignoredFiles: ignoredFiles
        )
    }

    private func validateDirectory(at url: URL) throws {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        guard exists, isDir.boolValue else {
            throw FolderScannerError.unreadableFolder(name: url.lastPathComponent, reason: "Sem permissão de leitura.")
        }

        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
        } catch {
            throw FolderScannerError.unreadableFolder(name: url.lastPathComponent, reason: "Sem permissão de leitura.")
        }
    }

    private func makeBasePrefix(for url: URL) -> String {
        let basePath = url.standardizedFileURL.path
        return basePath.hasSuffix("/") ? basePath : (basePath + "/")
    }

    private func inspectItem(
        at itemURL: URL,
        basePrefix: String,
        validFiles: inout [ScannedFile],
        ignoredFiles: inout [IgnoredFile]
    ) {
        let standardizedPath = itemURL.standardizedFileURL.path
        guard standardizedPath.hasPrefix(basePrefix) else { return }
        let relativePath = String(standardizedPath.dropFirst(basePrefix.count))
        guard !relativePath.isEmpty else { return }

        let components = relativePath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return }

        let fileName = components.last ?? ""
        let dirComponents = Array(components.dropLast())

        if checkDirectoryExclusion(
            dirComponents: dirComponents,
            itemURL: itemURL,
            path: relativePath,
            ignoredFiles: &ignoredFiles
        ) {
            return
        }

        let resourceValues = try? itemURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
        if resourceValues?.isDirectory == true {
            return
        }

        if checkFileExclusion(
            fileName: fileName,
            itemURL: itemURL,
            resourceValues: resourceValues,
            path: relativePath,
            ignoredFiles: &ignoredFiles
        ) {
            return
        }

        let fileSize = Int64(resourceValues?.fileSize ?? 0)
        let kind = Self.classify(relativePath: relativePath)
        validFiles.append(ScannedFile(relativePath: relativePath, url: itemURL, kind: kind, size: fileSize))
    }

    private func checkDirectoryExclusion(
        dirComponents: [String],
        itemURL: URL,
        path: String,
        ignoredFiles: inout [IgnoredFile]
    ) -> Bool {
        if dirComponents.contains(where: { ignoredDirectoryNames.contains($0.lowercased()) }) {
            let isRegular = (try? itemURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            if isRegular {
                ignoredFiles.append(IgnoredFile(relativePath: path, reason: .ignoredDirectory))
            }
            return true
        }

        if dirComponents.contains(where: { $0.hasPrefix(".") }) {
            let isRegular = (try? itemURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            if isRegular {
                ignoredFiles.append(IgnoredFile(relativePath: path, reason: .hidden))
            }
            return true
        }

        return false
    }

    private func checkFileExclusion(
        fileName: String,
        itemURL: URL,
        resourceValues: URLResourceValues?,
        path: String,
        ignoredFiles: inout [IgnoredFile]
    ) -> Bool {
        if fileName.hasPrefix(".") {
            ignoredFiles.append(IgnoredFile(relativePath: path, reason: .hidden))
            return true
        }

        let ext = itemURL.pathExtension.lowercased()
        guard validExtensions.contains(ext) else {
            ignoredFiles.append(IgnoredFile(relativePath: path, reason: .binary))
            return true
        }

        let fileSize = Int64(resourceValues?.fileSize ?? 0)
        if fileSize > maxFileSizeBytes {
            ignoredFiles.append(IgnoredFile(relativePath: path, reason: .tooLarge))
            return true
        }

        do {
            let data = try Data(contentsOf: itemURL)
            guard String(data: data, encoding: .utf8) != nil else {
                ignoredFiles.append(IgnoredFile(relativePath: path, reason: .binary))
                return true
            }
        } catch {
            ignoredFiles.append(IgnoredFile(relativePath: path, reason: .binary))
            return true
        }

        return false
    }

    private func applyCeiling(validFiles: [ScannedFile]) -> ([ScannedFile], [IgnoredFile]) {
        if validFiles.count > maxValidFilesCount {
            let finalValid = Array(validFiles.prefix(maxValidFilesCount))
            let overflow = validFiles.dropFirst(maxValidFilesCount)
            let ignored = overflow.map { IgnoredFile(relativePath: $0.relativePath, reason: .limitExceeded) }
            return (finalValid, ignored)
        } else {
            return (validFiles, [])
        }
    }

    /// Classifica o caminho relativo conforme as regras do PRD/ARCHITECTURE.
    static func classify(relativePath: String) -> IndexedChunk.Kind {
        let normalized = relativePath
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let lower = normalized.lowercased()
        let lastComponent = (normalized as NSString).lastPathComponent

        if lower.hasPrefix("qa/") {
            return .qa
        }
        if lastComponent.lowercased().hasPrefix("readme") || lower.hasPrefix("docs/") {
            return .document
        }
        return .code
    }
}
