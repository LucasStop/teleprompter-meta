import Foundation

struct WERSamplePair: Sendable, Equatable {
    let datasetName: String
    let sampleName: String
    let wavURL: URL
    let txtURL: URL
}

struct WERDataset: Sendable, Equatable {
    let name: String
    let pairs: [WERSamplePair]
}

struct WERSampleEvaluation: Sendable, Equatable {
    let pair: WERSamplePair
    let reference: String
    let hypothesis: String
    let wer: Double
}

struct WERDatasetEvaluation: Sendable, Equatable {
    let datasetName: String
    let evaluations: [WERSampleEvaluation]
    let averageWER: Double
    let worstEvaluation: WERSampleEvaluation?

    init(datasetName: String, evaluations: [WERSampleEvaluation]) {
        self.datasetName = datasetName
        self.evaluations = evaluations
        if evaluations.isEmpty {
            self.averageWER = 0.0
            self.worstEvaluation = nil
        } else {
            let total = evaluations.reduce(0.0) { $0 + $1.wer }
            self.averageWER = total / Double(evaluations.count)
            self.worstEvaluation = evaluations.max { $0.wer < $1.wer }
        }
    }

    var formattedSummary: String {
        let avgString = String(format: "%.2f%%", averageWER * 100)
        var lines: [String] = [
            "--------------------------------------------------",
            "Relatório de WER: conjunto [\(datasetName)] (\(evaluations.count) amostras)",
            "WER médio: \(avgString)"
        ]
        if let worst = worstEvaluation {
            let worstPercent = String(format: "%.2f%%", worst.wer * 100)
            lines.append("Pior pergunta: \(worst.pair.sampleName) (WER: \(worstPercent))")
            lines.append("  Ref: \"\(worst.reference.trimmingCharacters(in: .whitespacesAndNewlines))\"")
            lines.append("  Hip: \"\(worst.hypothesis.trimmingCharacters(in: .whitespacesAndNewlines))\"")
        }
        lines.append("--------------------------------------------------")
        return lines.joined(separator: "\n")
    }
}

enum WERDatasetDiscovery {
    static func discoverDatasets(in rootDirectory: URL) -> [WERDataset] {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: rootDirectory.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        guard let contents = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let subdirectories = contents.filter { url in
            var subIsDir: ObjCBool = false
            return fileManager.fileExists(atPath: url.path, isDirectory: &subIsDir) && subIsDir.boolValue
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        var datasets: [WERDataset] = []

        for subDir in subdirectories {
            let datasetName = subDir.lastPathComponent
            let pairs = discoverPairs(in: subDir, parentDirectory: rootDirectory, datasetName: datasetName)
            if !pairs.isEmpty {
                datasets.append(WERDataset(name: datasetName, pairs: pairs))
            }
        }

        let rootPairs = discoverPairs(in: rootDirectory, parentDirectory: rootDirectory, datasetName: "padrao")
        if !rootPairs.isEmpty {
            datasets.append(WERDataset(name: "padrao", pairs: rootPairs))
        }

        return datasets
    }

    private static func discoverPairs(
        in directory: URL,
        parentDirectory: URL,
        datasetName: String
    ) -> [WERSamplePair] {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let wavFiles = files
            .filter { $0.pathExtension.lowercased() == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var pairs: [WERSamplePair] = []

        for wavURL in wavFiles {
            let sampleName = wavURL.deletingPathExtension().lastPathComponent
            let localTxtURL = directory.appendingPathComponent("\(sampleName).txt")
            let parentTxtURL = parentDirectory.appendingPathComponent("\(sampleName).txt")

            let resolvedTxtURL: URL?
            if fileManager.fileExists(atPath: localTxtURL.path) {
                resolvedTxtURL = localTxtURL
            } else if fileManager.fileExists(atPath: parentTxtURL.path) {
                resolvedTxtURL = parentTxtURL
            } else {
                resolvedTxtURL = nil
            }

            if let txtURL = resolvedTxtURL {
                pairs.append(WERSamplePair(
                    datasetName: datasetName,
                    sampleName: sampleName,
                    wavURL: wavURL,
                    txtURL: txtURL
                ))
            }
        }

        return pairs
    }
}
