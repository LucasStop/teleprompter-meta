import Foundation
import Speech

protocol SpeechAssetManager: Sendable {
    func isSupported(for locale: Locale) async -> Bool
    func isInstalled(for locale: Locale) async -> Bool
    func install(for locale: Locale, progress: (@Sendable (Progress) -> Void)?) async throws
}

extension SpeechAssetManager {
    func isSupported(for locale: Locale) async -> Bool {
        true
    }

    func install(for locale: Locale) async throws {
        try await install(for: locale, progress: nil)
    }

    func install(for locale: Locale) -> AsyncStream<Progress> {
        AsyncStream { continuation in
            Task {
                do {
                    try await install(for: locale) { progress in
                        continuation.yield(progress)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }
}

final class SystemSpeechAssetManager: SpeechAssetManager, Sendable {
    func isSupported(for locale: Locale) async -> Bool {
        guard #available(iOS 26, *) else { return false }
        return await Speech.SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil
    }

    func isInstalled(for locale: Locale) async -> Bool {
        guard #available(iOS 26, *) else { return false }
        guard let resolvedLocale = await Speech.SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            return false
        }
        let installedLocales = await Speech.SpeechTranscriber.installedLocales
        if installedLocales.contains(where: { $0 == resolvedLocale || $0.identifier == resolvedLocale.identifier }) {
            return true
        }
        let module = Speech.SpeechTranscriber(locale: resolvedLocale, preset: .progressiveTranscription)
        let status = await Speech.AssetInventory.status(forModules: [module])
        return status == .installed
    }

    func install(for locale: Locale, progress: (@Sendable (Progress) -> Void)?) async throws {
        guard #available(iOS 26, *) else {
            throw STTError.unavailable
        }
        guard let resolvedLocale = await Speech.SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw STTError.unsupportedLocale(locale)
        }
        let module = Speech.SpeechTranscriber(locale: resolvedLocale, preset: .progressiveTranscription)
        let status = await Speech.AssetInventory.status(forModules: [module])
        if status == .installed {
            return
        }

        guard let request = try await Speech.AssetInventory.assetInstallationRequest(supporting: [module]) else {
            return
        }

        var observation: NSKeyValueObservation?
        if let progress = progress {
            progress(request.progress)
            observation = request.progress.observe(\.fractionCompleted) { progressItem, _ in
                progress(progressItem)
            }
        }
        defer {
            observation?.invalidate()
        }

        try await request.downloadAndInstall()
    }
}
