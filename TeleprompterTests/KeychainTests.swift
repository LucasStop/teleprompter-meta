import Security
import XCTest
@testable import Teleprompter

final class KeychainTests: XCTestCase {
    func testInMemorySecretStoreCRUD() throws {
        let store = InMemorySecretStore()
        XCTAssertNil(try store.get(key: "api_key"))

        try store.set(key: "api_key", value: "sk-secret-123")
        XCTAssertEqual(try store.get(key: "api_key"), "sk-secret-123")

        try store.set(key: "api_key", value: "sk-secret-456")
        XCTAssertEqual(try store.get(key: "api_key"), "sk-secret-456")

        try store.delete(key: "api_key")
        XCTAssertNil(try store.get(key: "api_key"))
    }

    func testKeychainStoreCRUDOnSimulator() throws {
        let testService = "br.com.lucasstop.teleprompter.test.\(UUID().uuidString)"
        let store = KeychainStore(service: testService)
        let key = "llm_key"

        try? store.delete(key: key)
        defer {
            try? store.delete(key: key)
        }

        XCTAssertNil(try store.get(key: key))

        try store.set(key: key, value: "secret-token-one")
        XCTAssertEqual(try store.get(key: key), "secret-token-one")

        try store.set(key: key, value: "secret-token-updated")
        XCTAssertEqual(try store.get(key: key), "secret-token-updated")

        try store.delete(key: key)
        XCTAssertNil(try store.get(key: key))
    }
}
