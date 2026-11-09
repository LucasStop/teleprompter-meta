import Foundation

/// Representação do conteúdo lido de um arquivo de material.
struct MaterialFileContent: Sendable, Equatable {
    let name: String
    let text: String
}

/// Protocolo para leitura de arquivos de material (isolamento para testes com fakes).
protocol MaterialFileSource: Sendable {
    func read(from url: URL) throws -> MaterialFileContent
}

/// Leitor padrão de arquivos usando sandbox e security-scoped URLs do iOS.
struct DefaultMaterialFileSource: MaterialFileSource {
    func read(from url: URL) throws -> MaterialFileContent {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let name = url.lastPathComponent
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw MaterialImporterError.unreadableFile(name, reason: "Arquivo sem permissão de leitura.")
        }

        guard !data.isEmpty else {
            throw MaterialImporterError.emptyFile(name)
        }

        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? String(data: data, encoding: .ascii) else {
            throw MaterialImporterError.unreadableFile(name, reason: "Codificação incompatível.")
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MaterialImporterError.emptyFile(name)
        }

        return MaterialFileContent(name: name, text: text)
    }
}
