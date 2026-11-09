import Foundation
import XCTest
@testable import Teleprompter

final class SettingsStoreTests: XCTestCase {
    func testUserDefaultsSettingsStoreRoundTripWithTemporarySuite() {
        let suiteName = "br.com.lucasstop.teleprompter.tests.settings.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Falha ao instanciar UserDefaults para a suite temporária.")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store1 = UserDefaultsSettingsStore(suiteName: suiteName)
        XCTAssertEqual(store1.load(), Settings.default)

        let customSettings = Settings(
            format: .keywords,
            qaThreshold: 0.65,
            chunkThreshold: 0.35,
            topK: 6,
            silenceThreshold: 2.5,
            qaNotesEnabled: false,
            documentsEnabled: true,
            codeEnabled: false,
            appearance: .dark
        )
        store1.save(customSettings)

        let store2 = UserDefaultsSettingsStore(suiteName: suiteName)
        let loaded = store2.load()
        XCTAssertEqual(loaded, customSettings)
        XCTAssertEqual(loaded.format, .keywords)
        XCTAssertEqual(loaded.qaThreshold, 0.65)
        XCTAssertEqual(loaded.chunkThreshold, 0.35)
        XCTAssertEqual(loaded.topK, 6)
        XCTAssertEqual(loaded.silenceThreshold, 2.5)
        XCTAssertFalse(loaded.qaNotesEnabled)
        XCTAssertTrue(loaded.documentsEnabled)
        XCTAssertFalse(loaded.codeEnabled)
        XCTAssertEqual(loaded.appearance, .dark)
    }

    func testUserDefaultsNeverStoresApiKeyOrSecretData() {
        let suiteName = "br.com.lucasstop.teleprompter.tests.settings.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Falha ao instanciar UserDefaults para a suite temporária.")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = UserDefaultsSettingsStore(suiteName: suiteName)
        store.save(Settings.default)

        let dictionary = defaults.dictionaryRepresentation()
        let forbiddenPatterns = ["apiKey", "api_key", "sk-", "secret", "llm.apiKey"]

        for (key, value) in dictionary {
            for pattern in forbiddenPatterns {
                XCTAssertFalse(
                    key.localizedCaseInsensitiveContains(pattern),
                    "UserDefaults não pode conter chave sensível: \(key)"
                )
                if let stringVal = value as? String {
                    XCTAssertFalse(
                        stringVal.localizedCaseInsensitiveContains(pattern),
                        "UserDefaults não pode conter valor sensível para chave \(key): \(stringVal)"
                    )
                }
            }
        }
    }

    func testSettingsResetToDefaults() {
        let suiteName = "br.com.lucasstop.teleprompter.tests.settings.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Falha ao instanciar UserDefaults para a suite temporária.")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = UserDefaultsSettingsStore(suiteName: suiteName)
        let modified = Settings(
            format: .fullText,
            qaThreshold: 0.90,
            chunkThreshold: 0.80,
            topK: 10,
            silenceThreshold: 4.0,
            qaNotesEnabled: false,
            documentsEnabled: false,
            codeEnabled: false,
            appearance: .light
        )
        store.save(modified)
        XCTAssertEqual(store.load(), modified)

        let resetResult = store.resetToDefaults()
        XCTAssertEqual(resetResult, Settings.default)
        XCTAssertEqual(store.load(), Settings.default)
    }

    func testClampingInvalidThresholds() {
        let outOfBounds = Settings(
            format: .bullets,
            qaThreshold: 2.5,
            chunkThreshold: -0.8,
            topK: 50,
            silenceThreshold: 15.0,
            qaNotesEnabled: true,
            documentsEnabled: true,
            codeEnabled: true,
            appearance: .system
        )
        let clamped = outOfBounds.clamped()
        XCTAssertEqual(clamped.qaThreshold, 1.0)
        XCTAssertEqual(clamped.chunkThreshold, 0.0)
        XCTAssertEqual(clamped.topK, 10)
        XCTAssertEqual(clamped.silenceThreshold, 5.0)

        let negativeBounds = Settings(
            format: .bullets,
            qaThreshold: -1.0,
            chunkThreshold: -0.1,
            topK: -5,
            silenceThreshold: 0.1
        ).clamped()
        XCTAssertEqual(negativeBounds.qaThreshold, 0.0)
        XCTAssertEqual(negativeBounds.chunkThreshold, 0.0)
        XCTAssertEqual(negativeBounds.topK, 1)
        XCTAssertEqual(negativeBounds.silenceThreshold, 0.5)
    }

    func testInMemorySettingsStoreRoundTrip() {
        let store = InMemorySettingsStore()
        XCTAssertEqual(store.load(), Settings.default)

        var newSettings = Settings.default
        newSettings.format = .keywords
        store.save(newSettings)
        XCTAssertEqual(store.load().format, .keywords)

        store.resetToDefaults()
        XCTAssertEqual(store.load(), Settings.default)
    }
}
