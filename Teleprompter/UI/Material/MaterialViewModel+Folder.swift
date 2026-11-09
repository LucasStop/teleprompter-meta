import Foundation

extension MaterialViewModel {
    // MARK: - Ações de Importação de Pasta

    func selectFolder(url: URL) async {
        lastAttempt = { [weak self] in
            await self?.selectFolder(url: url)
        }
        dismissError()

        do {
            let scan = try scanner.scan(url: url)
            updateFolderState(activeState: .pastaConfirmar, scanResult: scan)
        } catch {
            let folderName = url.lastPathComponent
            let err = (
                title: "Não consegui ler a pasta \"\(folderName)\".",
                message: "Sem permissão de leitura. Escolha a pasta de novo."
            )
            updateFolderState(activeState: .pastaErro, error: err)
        }
    }

    func confirmFolderImport() async {
        guard let scan = currentScanResult else { return }

        let totalFiles = scan.validFiles.count
        let initialProgress = MaterialScreenState.FolderProgressState(
            folderName: scan.folderName,
            current: 0,
            total: totalFiles,
            currentFileName: scan.validFiles.first?.relativePath ?? "",
            progress: totalFiles > 0 ? 0.05 : 1.0
        )
        updateFolderState(activeState: .pastaIndexando, progress: initialProgress)

        cleanupOldFolderFiles(currentPaths: Set(scan.validFiles.map(\.relativePath)))

        let (stats, newlyIndexed) = await indexScannedFiles(scan: scan)
        indexedFolderFilePaths = newlyIndexed

        let newFolderSources = makeFolderSources(scan: scan, stats: stats)
        replaceFolderSources(with: newFolderSources)

        finalizeFolderImport(scan: scan, stats: stats)
    }

    func chooseAnotherFolder() {
        resetFolderState()
        isPickingFolder = true
    }

    func dismissFolderState() {
        resetFolderState()
    }

    // MARK: - Auxiliares Privados de Indexação de Pasta

    private struct IndexingStats {
        var qaChunks = 0
        var docChunks = 0
        var codeChunks = 0
        var additionalIgnored = 0
    }

    private func cleanupOldFolderFiles(currentPaths: Set<String>) {
        let removedPaths = indexedFolderFilePaths.subtracting(currentPaths)
        for oldPath in removedPaths {
            try? indexable.removeSource(oldPath)
        }
    }

    private func indexScannedFiles(scan: FolderScanResult) async -> (IndexingStats, Set<String>) {
        var stats = IndexingStats()
        var newlyIndexed: Set<String> = []
        let total = scan.validFiles.count

        for (index, file) in scan.validFiles.enumerated() {
            let currentProg = MaterialScreenState.FolderProgressState(
                folderName: scan.folderName,
                current: index + 1,
                total: total,
                currentFileName: file.relativePath,
                progress: Double(index + 1) / Double(max(1, total))
            )
            updateFolderState(activeState: .pastaIndexando, progress: currentProg)

            do {
                let chunks = try indexSingleFile(file: file)
                newlyIndexed.insert(file.relativePath)
                accumulateStats(&stats, for: file.kind, count: chunks.count)
            } catch {
                stats.additionalIgnored += 1
            }

            await Task.yield()
        }

        return (stats, newlyIndexed)
    }

    private func indexSingleFile(file: ScannedFile) throws -> [IndexedChunk] {
        let contentText = try readFileText(from: file.url, relativePath: file.relativePath)
        let chunks = try importer.parse(content: contentText, sourceName: file.relativePath, kind: file.kind)
        guard !chunks.isEmpty else {
            throw MaterialImporterError.emptyFile(file.relativePath)
        }

        try indexable.removeSource(file.relativePath)
        try indexable.index(chunks)
        return chunks
    }

    private func readFileText(from url: URL, relativePath: String) throws -> String {
        if let content = try? fileSource.read(from: url) {
            return content.text
        }
        let data = try Data(contentsOf: url)
        guard let str = String(data: data, encoding: .utf8) else {
            throw MaterialImporterError.unreadableFile(relativePath, reason: "Codificação incompatível.")
        }
        return str
    }

    private func accumulateStats(_ stats: inout IndexingStats, for kind: IndexedChunk.Kind, count: Int) {
        switch kind {
        case .qa:
            stats.qaChunks += count
        case .document:
            stats.docChunks += count
        case .code:
            stats.codeChunks += count
        }
    }

    private func makeFolderSources(scan: FolderScanResult, stats: IndexingStats) -> [MaterialSource] {
        var sources: [MaterialSource] = []
        if scan.qaCount > 0 {
            sources.append(MaterialSource(
                name: "Notas de Q&A",
                path: "folder:qa",
                kind: .qa,
                chunkCount: stats.qaChunks,
                subtitle: "\(scan.qaCount) \(scan.qaCount == 1 ? "arquivo" : "arquivos")",
                importedAt: Date()
            ))
        }
        if scan.documentCount > 0 {
            sources.append(MaterialSource(
                name: "Documentos",
                path: "folder:docs",
                kind: .document,
                chunkCount: stats.docChunks,
                subtitle: "\(scan.documentCount) \(scan.documentCount == 1 ? "arquivo" : "arquivos")",
                importedAt: Date()
            ))
        }
        if scan.codeCount > 0 {
            sources.append(MaterialSource(
                name: "Código",
                path: "folder:code",
                kind: .code,
                chunkCount: stats.codeChunks,
                subtitle: "\(scan.codeCount) \(scan.codeCount == 1 ? "arquivo" : "arquivos")",
                importedAt: Date()
            ))
        }
        return sources
    }

    private func finalizeFolderImport(scan: FolderScanResult, stats: IndexingStats) {
        let totalChunks = stats.qaChunks + stats.docChunks + stats.codeChunks
        let indexedFiles = scan.validFiles.count - stats.additionalIgnored
        let totalIgnored = scan.ignoredFiles.count + stats.additionalIgnored

        let filesStr = "\(formatNumber(indexedFiles)) \(indexedFiles == 1 ? "arquivo indexado" : "arquivos indexados")"
        let chunksStr = "\(formatNumber(totalChunks)) \(totalChunks == 1 ? "trecho" : "trechos")"
        let badge = "\(filesStr), \(chunksStr)"

        var banner: MaterialScreenState.FolderResultBanner?
        if totalIgnored > 0 {
            banner = MaterialScreenState.FolderResultBanner(
                ignoredCount: totalIgnored,
                message: "Pastas de build, arquivos grandes e binários. Reimportar a pasta substitui os trechos, sem duplicar."
            )
        }

        updateFolderState(
            activeState: .pastaConcluido,
            banner: banner,
            badgeTitle: badge
        )
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
