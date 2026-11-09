import Foundation
import Observation

/// Raiz de composição da aplicação Teleprompter (T02).
/// Fabrica a versão de produção com hardware real e SQLite persistente,
/// ou a versão de preview/teste com doubles em memória.
@MainActor
@Observable
final class AppEnvironment {
    let lens: SimulatedLens
    let conversationViewModel: ConversationViewModel
    let conversationStore: any ConversationStore
    let conversationsViewModel: ConversationsViewModel
    let projectStore: any ProjectStore
    let projectsViewModel: ProjectsViewModel
    let settingsStore: any SettingsStore
    let secretStore: any SecretStore
    let settingsViewModel: SettingsViewModel
    let materialViewModel: MaterialViewModel
    let ensaioViewModel: EnsaioViewModel
    let retriever: any Retriever

    init(
        lens: SimulatedLens = SimulatedLens(),
        conversationViewModel: ConversationViewModel? = nil,
        conversationStore: (any ConversationStore)? = nil,
        conversationsViewModel: ConversationsViewModel? = nil,
        projectStore: (any ProjectStore)? = nil,
        projectsViewModel: ProjectsViewModel? = nil,
        settingsStore: (any SettingsStore)? = nil,
        secretStore: (any SecretStore)? = nil,
        settingsViewModel: SettingsViewModel? = nil,
        materialViewModel: MaterialViewModel? = nil,
        ensaioViewModel: EnsaioViewModel? = nil,
        retriever: (any Retriever)? = nil
    ) {
        self.lens = lens
        let effectiveSettingsStore = settingsStore ?? UserDefaultsSettingsStore()
        let effectiveSecretStore = secretStore ?? KeychainStore()
        self.settingsStore = effectiveSettingsStore
        self.secretStore = effectiveSecretStore

        let appSupportDir = Self.applicationSupportDirectoryURL()
        let resolvedProjectStore = projectStore ?? Self.defaultProjectStore()
        self.projectStore = resolvedProjectStore

        let store = conversationStore ?? Self.defaultConversationStore(settingsStore: effectiveSettingsStore)
        self.conversationStore = store
        Self.configureStoreActiveProject(store, settingsStore: effectiveSettingsStore)

        self.conversationsViewModel = conversationsViewModel ?? ConversationsViewModel(store: store)
        self.settingsViewModel = settingsViewModel ?? SettingsViewModel(
            settingsStore: effectiveSettingsStore,
            secretStore: effectiveSecretStore
        )

        let resolvedRetriever = retriever ?? ProductionAppRetriever(
            directoryURL: appSupportDir,
            settingsStore: effectiveSettingsStore
        )
        self.retriever = resolvedRetriever

        let matIndexable = (resolvedRetriever as? (any MaterialIndexable))
            ?? ProductionAppRetriever(directoryURL: appSupportDir, settingsStore: effectiveSettingsStore)
        let resolvedMaterialVM = materialViewModel ?? MaterialViewModel(indexable: matIndexable)
        self.materialViewModel = resolvedMaterialVM

        self.ensaioViewModel = ensaioViewModel ?? Self.makeDefaultEnsaioViewModel(
            retriever: resolvedRetriever,
            lens: lens,
            settingsStore: effectiveSettingsStore,
            secretStore: effectiveSecretStore
        )

        let resolvedConversationVM = conversationViewModel ?? Self.makeDefaultConversationViewModel(
            retriever: resolvedRetriever,
            lens: lens,
            settingsStore: effectiveSettingsStore,
            secretStore: effectiveSecretStore,
            store: store
        )
        self.conversationViewModel = resolvedConversationVM

        let pvm = projectsViewModel ?? ProjectsViewModel(
            projectStore: resolvedProjectStore,
            settingsStore: effectiveSettingsStore,
            conversationStore: store,
            retriever: resolvedRetriever
        )
        self.projectsViewModel = pvm
        Self.bindProjectChanges(pvm: pvm, convVM: resolvedConversationVM, matVM: resolvedMaterialVM, store: store)
    }

    private static func configureStoreActiveProject(_ store: any ConversationStore, settingsStore: any SettingsStore) {
        if let sqlStore = store as? SQLiteConversationStore {
            sqlStore.setActiveProjectIdProvider { settingsStore.load().activeProjectId }
        } else if let memStore = store as? InMemoryConversationStore {
            Task {
                await memStore.setActiveProjectIdProvider { settingsStore.load().activeProjectId }
            }
        }
    }

    private static func bindProjectChanges(
        pvm: ProjectsViewModel,
        convVM: ConversationViewModel,
        matVM: MaterialViewModel,
        store: any ConversationStore
    ) {
        pvm.onProjectChanged = { [weak convVM, weak matVM] newProjectId in
            guard let convVM, let matVM else { return }
            Task { @MainActor in
                await convVM.switchProject(to: newProjectId)
                if let sqlStore = store as? SQLiteConversationStore {
                    sqlStore.setActiveProjectIdProvider { newProjectId }
                }
                matVM.reloadForActiveProject()
            }
        }
    }

    private static func applicationSupportDirectoryURL() -> URL {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let appSupportDir = supportDir.appendingPathComponent("Teleprompter", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appSupportDir.path) {
            try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
        return appSupportDir
    }

    private static func applicationSupportURL(for filename: String) -> URL {
        applicationSupportDirectoryURL().appendingPathComponent(filename)
    }

    private static func defaultProjectStore() -> any ProjectStore {
        let dbURL = applicationSupportURL(for: "projects.sqlite")
        return (try? SQLiteProjectStore(databaseURL: dbURL)) ?? InMemoryProjectStore()
    }

    private static func defaultConversationStore(settingsStore: any SettingsStore) -> any ConversationStore {
        let dbURL = applicationSupportURL(for: "conversations.sqlite")
        return (try? SQLiteConversationStore(
            databaseURL: dbURL,
            activeProjectIdProvider: { settingsStore.load().activeProjectId }
        )) ?? InMemoryConversationStore()
    }

    private static func makeDefaultEnsaioViewModel(
        retriever: any Retriever,
        lens: SimulatedLens,
        settingsStore: any SettingsStore,
        secretStore: any SecretStore
    ) -> EnsaioViewModel {
        let assetManager = SystemSpeechAssetManager()
        let generator = makeGenerator(settings: settingsStore.load(), secretStore: secretStore)
        let runner = EnsaioRunner(
            transcriber: SpeechAnalyzerTranscriber(locale: Locale(identifier: "pt-BR"), assetManager: assetManager),
            retriever: generator == nil ? QANoteOnlyRetriever(underlying: retriever) : retriever,
            generator: generator ?? InMemoryAppGenerator(),
            lens: lens,
            speechAssetManager: assetManager
        )
        return EnsaioViewModel(runner: runner)
    }

    private static func makeDefaultConversationViewModel(
        retriever: any Retriever,
        lens: SimulatedLens,
        settingsStore: any SettingsStore,
        secretStore: any SecretStore,
        store: any ConversationStore
    ) -> ConversationViewModel {
        let assetManager = SystemSpeechAssetManager()
        let transcriber = SpeechAnalyzerTranscriber(
            locale: Locale(identifier: "pt-BR"),
            assetManager: assetManager
        )
        let audioSource = MicrophoneAudioSource()
        let settings = settingsStore.load()
        let initialGenerator = makeGenerator(settings: settings, secretStore: secretStore)

        return ConversationViewModel(
            retriever: retriever,
            generator: initialGenerator ?? InMemoryAppGenerator(),
            formatter: LensFormatter(),
            lens: lens,
            transcriber: transcriber,
            detector: PauseQuestionDetector(silenceThreshold: settings.silenceThreshold),
            format: settings.format,
            settingsStore: settingsStore,
            secretStore: secretStore,
            conversationStore: store,
            audioSource: audioSource,
            speechAssetManager: assetManager
        )
    }

    static func production() -> AppEnvironment {
        AppEnvironment()
    }

    static func preview() -> AppEnvironment {
        let lens = SimulatedLens()
        var initialSettings = Settings.default
        initialSettings.activeProjectId = "cursos"
        let settingsStore = InMemorySettingsStore(initial: initialSettings)
        let secretStore = InMemorySecretStore()

        let projectStore = InMemoryProjectStore(initialProjects: [
            Project(id: "cursos", name: "Plataforma de cursos"),
            Project(id: Project.defaultId, name: "Teleprompter Meta")
        ])

        let convStore = InMemoryConversationStore(
            initialConversations: [],
            activeProjectIdProvider: { settingsStore.load().activeProjectId }
        )

        let retriever = InMemoryAppRetriever(settingsStore: settingsStore)
        let conversationVM = ConversationViewModel(
            retriever: retriever,
            generator: InMemoryAppGenerator(),
            formatter: LensFormatter(),
            lens: lens,
            transcriber: InMemoryAppTranscriber(),
            detector: PauseQuestionDetector(silenceThreshold: 1.2),
            format: .bullets,
            settingsStore: settingsStore,
            secretStore: secretStore,
            conversationStore: convStore
        )
        let materialVM = MaterialViewModel(indexable: retriever)
        let settingsVM = SettingsViewModel(settingsStore: settingsStore, secretStore: secretStore)
        let conversationsVM = ConversationsViewModel(store: convStore)

        let projectsVM = ProjectsViewModel(
            projectStore: projectStore,
            settingsStore: settingsStore,
            conversationStore: convStore,
            retriever: retriever
        )

        return AppEnvironment(
            lens: lens,
            conversationViewModel: conversationVM,
            conversationStore: convStore,
            conversationsViewModel: conversationsVM,
            projectStore: projectStore,
            projectsViewModel: projectsVM,
            settingsStore: settingsStore,
            secretStore: secretStore,
            settingsViewModel: settingsVM,
            materialViewModel: materialVM,
            retriever: retriever
        )
    }

    static func test() -> AppEnvironment {
        preview()
    }
}

// MARK: - InMemory Doubles

final class InMemoryAppGenerator: AnswerGenerator, @unchecked Sendable {
    func generate(question: String, context: [Chunk]) -> AsyncStream<String> {
        let text = context.map(\.text).joined(separator: "\n")
        let content = text.isEmpty ? "Resposta gerada a partir do contexto." : text

        return AsyncStream { continuation in
            let words = content.components(separatedBy: " ")
            for (index, word) in words.enumerated() {
                let suffix = index == words.count - 1 ? "" : " "
                continuation.yield(word + suffix)
            }
            continuation.finish()
        }
    }
}

final class InMemoryAppTranscriber: SpeechTranscriber, @unchecked Sendable {
    func transcribe(_ audio: AsyncStream<AudioBuffer>) -> AsyncStream<Transcript> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
