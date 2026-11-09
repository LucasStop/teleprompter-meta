import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Modelo de Domínio

/// Representa um projeto isolado com pasta de material e conversas próprias (PRD US-15 e ADR-0010).
struct Project: Identifiable, Sendable, Codable, Equatable {
    static let defaultId = "default"
    static let defaultName = "Padrão"

    let id: String
    var name: String
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    /// Cria o projeto inicial padrão protegido.
    static var `default`: Project {
        Project(id: defaultId, name: defaultName, createdAt: Date(timeIntervalSince1970: 0))
    }
}

// MARK: - Erros

enum ProjectStoreError: Error, LocalizedError, Sendable, Equatable {
    case emptyName
    case duplicateName
    case projectNotFound
    case cannotDeleteDefaultProject
    case databaseOpenFailed(Int32)
    case databaseExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "O nome do projeto não pode ser vazio."
        case .duplicateName:
            return "Já existe um projeto com este nome."
        case .projectNotFound:
            return "Projeto não encontrado."
        case .cannotDeleteDefaultProject:
            return "O projeto padrão não pode ser excluído."
        case .databaseOpenFailed(let code):
            return "Falha ao abrir banco de dados de projetos (código: \(code))."
        case .databaseExecutionFailed(let message):
            return "Erro ao executar operação no SQLite: \(message)."
        }
    }
}

// MARK: - Protocolo

protocol ProjectStore: Sendable {
    func list() async throws -> [Project]
    func create(name: String) async throws -> Project
    func rename(id: String, to newName: String) async throws -> Project
    func delete(id: String) async throws
    func project(id: String) async throws -> Project?
}

// MARK: - SQLite Project Store

final class SQLiteProjectStore: ProjectStore, @unchecked Sendable {
    private let database: OpaquePointer
    private let queue = DispatchQueue(label: "br.com.lucasstop.teleprompter.storage.projects")

    init(databaseURL: URL) throws {
        let directoryURL = databaseURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        var dbPointer: OpaquePointer?
        let openResult = sqlite3_open(databaseURL.path, &dbPointer)
        guard openResult == SQLITE_OK, let dbPointer else {
            throw ProjectStoreError.databaseOpenFailed(openResult)
        }
        self.database = dbPointer
        try configureDatabase()
        try ensureDefaultProject()
    }

    deinit {
        sqlite3_close(database)
    }

    private func configureDatabase() throws {
        let sql = """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        CREATE TABLE IF NOT EXISTS projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_projects_created_at ON projects(created_at ASC);
        """
        try executeSQL(sql)
    }

    private func ensureDefaultProject() throws {
        let checkSQL = "SELECT COUNT(*) FROM projects WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, checkSQL, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, Project.defaultId, -1, sqliteTransient)

        var exists = false
        if sqlite3_step(stmt) == SQLITE_ROW {
            exists = sqlite3_column_int(stmt, 0) > 0
        }

        if !exists {
            let insertSQL = "INSERT INTO projects (id, name, created_at) VALUES (?, ?, ?);"
            var insertStmt: OpaquePointer?
            guard sqlite3_prepare_v2(database, insertSQL, -1, &insertStmt, nil) == SQLITE_OK, let insertStmt else {
                throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
            }
            defer { sqlite3_finalize(insertStmt) }
            sqlite3_bind_text(insertStmt, 1, Project.defaultId, -1, sqliteTransient)
            sqlite3_bind_text(insertStmt, 2, Project.defaultName, -1, sqliteTransient)
            sqlite3_bind_double(insertStmt, 3, Date().timeIntervalSince1970)
            guard sqlite3_step(insertStmt) == SQLITE_DONE else {
                throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
            }
        }
    }

    func list() async throws -> [Project] {
        try await runOnQueue { try self.performList() }
    }

    func create(name: String) async throws -> Project {
        try await runOnQueue { try self.performCreate(name: name) }
    }

    func rename(id: String, to newName: String) async throws -> Project {
        try await runOnQueue { try self.performRename(id: id, to: newName) }
    }

    func delete(id: String) async throws {
        try await runOnQueue { try self.performDelete(id: id) }
    }

    func project(id: String) async throws -> Project? {
        try await runOnQueue { try self.performFind(id: id) }
    }

    // MARK: - Operações Internas

    private func performList() throws -> [Project] {
        let sql = "SELECT id, name, created_at FROM projects ORDER BY created_at ASC;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }

        var projects: [Project] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let nameStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }) else { continue }
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
            projects.append(Project(id: idStr, name: nameStr, createdAt: createdAt))
        }
        return projects
    }

    private func performCreate(name: String) throws -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectStoreError.emptyName
        }

        let existing = try performList()
        if existing.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ProjectStoreError.duplicateName
        }

        let newProject = Project(id: UUID().uuidString, name: trimmed, createdAt: Date())
        let insertSQL = "INSERT INTO projects (id, name, created_at) VALUES (?, ?, ?);"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, insertSQL, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, newProject.id, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 2, newProject.name, -1, sqliteTransient)
        sqlite3_bind_double(stmt, 3, newProject.createdAt.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        return newProject
    }

    private func performRename(id: String, to newName: String) throws -> Project {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectStoreError.emptyName
        }

        let existing = try performList()
        guard let current = existing.first(where: { $0.id == id }) else {
            throw ProjectStoreError.projectNotFound
        }

        if existing.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ProjectStoreError.duplicateName
        }

        let updateSQL = "UPDATE projects SET name = ? WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, updateSQL, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, trimmed, -1, sqliteTransient)
        sqlite3_bind_text(stmt, 2, id, -1, sqliteTransient)

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        return Project(id: id, name: trimmed, createdAt: current.createdAt)
    }

    private func performDelete(id: String) throws {
        guard id != Project.defaultId else {
            throw ProjectStoreError.cannotDeleteDefaultProject
        }
        let deleteSQL = "DELETE FROM projects WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, deleteSQL, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, sqliteTransient)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
    }

    private func performFind(id: String) throws -> Project? {
        let sql = "SELECT id, name, created_at FROM projects WHERE id = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ProjectStoreError.databaseExecutionFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, id, -1, sqliteTransient)
        if sqlite3_step(stmt) == SQLITE_ROW {
            guard let idStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let nameStr = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }) else { return nil }
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
            return Project(id: idStr, name: nameStr, createdAt: createdAt)
        }
        return nil
    }

    private func executeSQL(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Erro desconhecido"
            sqlite3_free(errorMessage)
            throw ProjectStoreError.databaseExecutionFailed(message)
        }
    }

    private func runOnQueue<T: Sendable>(_ block: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try block())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - InMemory Project Store

actor InMemoryProjectStore: ProjectStore {
    private var projects: [String: Project] = [:]

    init(initialProjects: [Project] = []) {
        if initialProjects.isEmpty {
            projects[Project.defaultId] = Project(
                id: Project.defaultId,
                name: Project.defaultName,
                createdAt: Date(timeIntervalSince1970: 0)
            )
        } else {
            for project in initialProjects {
                projects[project.id] = project
            }
            if projects[Project.defaultId] == nil {
                projects[Project.defaultId] = Project(
                    id: Project.defaultId,
                    name: Project.defaultName,
                    createdAt: Date(timeIntervalSince1970: 0)
                )
            }
        }
    }

    func list() async throws -> [Project] {
        projects.values.sorted { $0.createdAt < $1.createdAt }
    }

    func create(name: String) async throws -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectStoreError.emptyName
        }
        if projects.values.contains(where: { $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ProjectStoreError.duplicateName
        }
        let project = Project(id: UUID().uuidString, name: trimmed, createdAt: Date())
        projects[project.id] = project
        return project
    }

    func rename(id: String, to newName: String) async throws -> Project {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectStoreError.emptyName
        }
        guard var current = projects[id] else {
            throw ProjectStoreError.projectNotFound
        }
        if projects.values.contains(where: {
            $0.id != id && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            throw ProjectStoreError.duplicateName
        }
        current.name = trimmed
        projects[id] = current
        return current
    }

    func delete(id: String) async throws {
        guard id != Project.defaultId else {
            throw ProjectStoreError.cannotDeleteDefaultProject
        }
        projects.removeValue(forKey: id)
    }

    func project(id: String) async throws -> Project? {
        projects[id]
    }
}
