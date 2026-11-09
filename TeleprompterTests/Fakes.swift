import Foundation
@testable import Teleprompter

struct FakeRetriever: Retriever {
    var result: Retrieval
    func retrieve(_ question: String) async throws -> Retrieval { result }
}

final class FakeGenerator: AnswerGenerator, @unchecked Sendable {
    private(set) var calls = 0
    var pieces = ["resposta ", "gerada"]
    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        calls += 1
        let pieces = pieces
        return AsyncStream { stream in pieces.forEach { stream.yield($0) }; stream.finish() }
    }
}

struct PassthroughFormatter: ResponseFormatter {
    func format(_ text: String, as format: AnswerFormat) -> String { text }
}

actor RecordingLens: Lens {
    private(set) var shown: LensContent?
    func show(_ content: LensContent) { shown = content }
    func clear() { shown = nil }
}

final class FakeSpeechAssetManager: SpeechAssetManager, @unchecked Sendable {
    private let lock = NSLock()
    private var supported: Set<String>
    private var installed: Set<String>
    private var steps: [Double]
    private var error: Error?
    private var _installCalls = 0
    private var _isInstalledCalls = 0
    private var _isSupportedCalls = 0

    var installCallCount: Int {
        lock.withLock { _installCalls }
    }

    var isInstalledCallCount: Int {
        lock.withLock { _isInstalledCalls }
    }

    var isSupportedCallCount: Int {
        lock.withLock { _isSupportedCalls }
    }

    init(
        supportedLocales: Set<String> = ["pt-BR", "en-US"],
        installedLocales: Set<String> = [],
        simulatedProgressSteps: [Double] = [0.25, 0.5, 0.75, 1.0],
        installError: Error? = nil
    ) {
        self.supported = supportedLocales
        self.installed = installedLocales
        self.steps = simulatedProgressSteps
        self.error = installError
    }

    func isSupported(for locale: Locale) async -> Bool {
        lock.withLock {
            _isSupportedCalls += 1
            return supported.contains(locale.identifier)
        }
    }

    func isInstalled(for locale: Locale) async -> Bool {
        lock.withLock {
            _isInstalledCalls += 1
            return installed.contains(locale.identifier)
        }
    }

    func install(for locale: Locale, progress: (@Sendable (Progress) -> Void)?) async throws {
        let (err, isSupp) = lock.withLock { () -> (Error?, Bool) in
            _installCalls += 1
            return (error, supported.contains(locale.identifier))
        }

        guard isSupp else {
            throw STTError.unsupportedLocale(locale)
        }

        if let err = err {
            throw err
        }

        let stepsToReport = lock.withLock { steps }
        for step in stepsToReport {
            let progressItem = Progress(totalUnitCount: 100)
            progressItem.completedUnitCount = Int64(step * 100)
            progress?(progressItem)
        }

        lock.withLock {
            _ = installed.insert(locale.identifier)
        }
    }
}
