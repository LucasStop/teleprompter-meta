import Foundation

extension MaterialViewModel {
    // MARK: - Ações de Importação de Arquivo Único

    func importFile(from url: URL) async {
        lastAttempt = { [weak self] in
            await self?.importFile(from: url)
        }
        errorMessage = nil
        resetFolderState()

        let fileName = url.lastPathComponent
        loadingState = MaterialScreenState.LoadingState(
            sourceName: fileName,
            current: 0,
            total: 1,
            progress: 0.1
        )

        do {
            let fileContent = try fileSource.read(from: url)
            await processContent(name: fileContent.name, content: fileContent.text)
        } catch let error as MaterialImporterError {
            setImportError(for: fileName, error: error)
        } catch {
            errorMessage = (
                title: "Não consegui ler \"\(fileName)\".",
                message: error.localizedDescription
            )
            loadingState = nil
        }
    }

    func importContent(name: String, content: String) async {
        lastAttempt = { [weak self] in
            await self?.importContent(name: name, content: content)
        }
        errorMessage = nil
        resetFolderState()

        loadingState = MaterialScreenState.LoadingState(
            sourceName: name,
            current: 0,
            total: 1,
            progress: 0.1
        )

        await processContent(name: name, content: content)
    }

    private func processContent(name: String, content: String) async {
        do {
            let chunks = try importer.parse(content: content, sourceName: name)
            guard !chunks.isEmpty else {
                throw MaterialImporterError.emptyFile(name)
            }

            loadingState = MaterialScreenState.LoadingState(
                sourceName: name,
                current: chunks.count / 2,
                total: chunks.count,
                progress: 0.5
            )

            try indexable.removeSource(name)
            try indexable.index(chunks)

            loadingState = MaterialScreenState.LoadingState(
                sourceName: name,
                current: chunks.count,
                total: chunks.count,
                progress: 1.0
            )

            let kind = chunks.first?.kind ?? .document
            let subtitle = makeSubtitle(kind: kind, count: chunks.count)
            let newSource = MaterialSource(
                name: name,
                path: name,
                kind: kind,
                chunkCount: chunks.count,
                subtitle: subtitle,
                importedAt: Date()
            )

            upsertSource(newSource)
            lastUpdated = Date()
            errorMessage = nil
            loadingState = nil
        } catch let error as MaterialImporterError {
            setImportError(for: name, error: error)
        } catch {
            errorMessage = (
                title: "Não consegui ler \"\(name)\".",
                message: error.localizedDescription
            )
            loadingState = nil
        }
    }

    private func upsertSource(_ newSource: MaterialSource) {
        if let existingIndex = sources.firstIndex(where: { $0.path == newSource.path }) {
            sources[existingIndex] = newSource
        } else {
            sources.append(newSource)
        }
    }

    private func setImportError(for name: String, error: MaterialImporterError) {
        switch error {
        case .emptyFile(let fileName):
            errorMessage = (
                title: "Não consegui indexar \"\(fileName)\".",
                message: error.localizedDescription
            )
        case .unreadableFile(let fileName, _):
            errorMessage = (
                title: "Não consegui ler \"\(fileName)\".",
                message: error.localizedDescription
            )
        }
        loadingState = nil
    }

    private func makeSubtitle(kind: IndexedChunk.Kind, count: Int) -> String {
        switch kind {
        case .qa:
            return "\(count) \(count == 1 ? "pergunta" : "perguntas")"
        case .document, .code:
            return "Importado hoje"
        }
    }
}
