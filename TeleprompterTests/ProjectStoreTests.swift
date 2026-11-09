import Foundation
import XCTest
@testable import Teleprompter

final class ProjectStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    private func makeSQLiteStore() throws -> SQLiteProjectStore {
        let dbURL = tempDirectory.appendingPathComponent("projects.sqlite")
        return try SQLiteProjectStore(databaseURL: dbURL)
    }

    // MARK: - SQLite Store Tests

    func testSQLiteDefaultProjectExistsOnInit() async throws {
        let store = try makeSQLiteStore()
        let list = try await store.list()

        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.first?.id, Project.defaultId)
        XCTAssertEqual(list.first?.name, "Padrão")
    }

    func testSQLiteCreateProjectSuccess() async throws {
        let store = try makeSQLiteStore()
        let created = try await store.create(name: "Projeto Beta")

        XCTAssertFalse(created.id.isEmpty)
        XCTAssertNotEqual(created.id, Project.defaultId)
        XCTAssertEqual(created.name, "Projeto Beta")

        let list = try await store.list()
        XCTAssertEqual(list.count, 2)
        XCTAssertTrue(list.contains(where: { $0.id == created.id }))
    }

    func testSQLiteCreateEmptyOrWhitespaceNameThrows() async throws {
        let store = try makeSQLiteStore()

        do {
            _ = try await store.create(name: "")
            XCTFail("Deveria falhar para nome vazio")
        } catch let err as ProjectStoreError {
            XCTAssertEqual(err, .emptyName)
        }

        do {
            _ = try await store.create(name: "   \n\t  ")
            XCTFail("Deveria falhar para nome com apenas espaços")
        } catch let err as ProjectStoreError {
            XCTAssertEqual(err, .emptyName)
        }
    }

    func testSQLiteCreateDuplicateNameCaseInsensitiveThrows() async throws {
        let store = try makeSQLiteStore()
        _ = try await store.create(name: "Meu App")

        do {
            _ = try await store.create(name: "meu app")
            XCTFail("Deveria falhar com nome duplicado")
        } catch let err as ProjectStoreError {
            XCTAssertEqual(err, .duplicateName)
        }

        do {
            _ = try await store.create(name: "padrão")
            XCTFail("Deveria falhar com nome duplicado do default")
        } catch let err as ProjectStoreError {
            XCTAssertEqual(err, .duplicateName)
        }
    }

    func testSQLiteRenameSuccess() async throws {
        let store = try makeSQLiteStore()
        let created = try await store.create(name: "Inicial")

        let renamed = try await store.rename(id: created.id, to: "Atualizado")
        XCTAssertEqual(renamed.name, "Atualizado")
        XCTAssertEqual(renamed.id, created.id)

        let list = try await store.list()
        XCTAssertTrue(list.contains(where: { $0.name == "Atualizado" }))
        XCTAssertFalse(list.contains(where: { $0.name == "Inicial" }))
    }

    func testSQLiteRenameDefaultProjectAllowed() async throws {
        let store = try makeSQLiteStore()
        let renamed = try await store.rename(id: Project.defaultId, to: "Teleprompter Meta")

        XCTAssertEqual(renamed.id, Project.defaultId)
        XCTAssertEqual(renamed.name, "Teleprompter Meta")

        let list = try await store.list()
        XCTAssertEqual(list.first(where: { $0.id == Project.defaultId })?.name, "Teleprompter Meta")
    }

    func testSQLiteRenameValidation() async throws {
        let store = try makeSQLiteStore()
        let projectOne = try await store.create(name: "Projeto 1")
        _ = try await store.create(name: "Projeto 2")

        do {
            _ = try await store.rename(id: projectOne.id, to: "   ")
            XCTFail("Deveria falhar com nome vazio")
        } catch let err as ProjectStoreError {
            XCTAssertEqual(err, .emptyName)
        }

        do {
            _ = try await store.rename(id: projectOne.id, to: "projeto 2")
            XCTFail("Deveria falhar com nome duplicado")
        } catch let err as ProjectStoreError {
            XCTAssertEqual(err, .duplicateName)
        }

        // Renomear para o mesmo nome ou variação de caixa do próprio id deve funcionar
        let selfRenamed = try await store.rename(id: projectOne.id, to: "PROJETO 1")
        XCTAssertEqual(selfRenamed.name, "PROJETO 1")
    }

    func testSQLiteDeleteProjectSuccess() async throws {
        let store = try makeSQLiteStore()
        let targetProject = try await store.create(name: "Para Excluir")

        try await store.delete(id: targetProject.id)

        let list = try await store.list()
        XCTAssertFalse(list.contains(where: { $0.id == targetProject.id }))
    }

    func testSQLiteDeleteDefaultProjectFails() async throws {
        let store = try makeSQLiteStore()

        do {
            try await store.delete(id: Project.defaultId)
            XCTFail("Deveria falhar ao tentar excluir o projeto padrão")
        } catch let err as ProjectStoreError {
            XCTAssertEqual(err, .cannotDeleteDefaultProject)
        }
    }

    // MARK: - InMemory Store Tests

    func testInMemoryStoreBehavior() async throws {
        let store = InMemoryProjectStore()

        let initialList = try await store.list()
        XCTAssertEqual(initialList.count, 1)
        XCTAssertEqual(initialList.first?.id, Project.defaultId)

        let created = try await store.create(name: "Projeto Memória")
        XCTAssertEqual(created.name, "Projeto Memória")

        do {
            _ = try await store.create(name: "projeto memória")
            XCTFail("Deveria falhar nome duplicado")
        } catch let err as ProjectStoreError {
            XCTAssertEqual(err, .duplicateName)
        }

        let renamed = try await store.rename(id: created.id, to: "Projeto Atualizado")
        XCTAssertEqual(renamed.name, "Projeto Atualizado")

        try await store.delete(id: created.id)
        let listAfterDelete = try await store.list()
        XCTAssertEqual(listAfterDelete.count, 1)

        do {
            try await store.delete(id: Project.defaultId)
            XCTFail("Não deve excluir projeto padrão")
        } catch let err as ProjectStoreError {
            XCTAssertEqual(err, .cannotDeleteDefaultProject)
        }
    }
}
