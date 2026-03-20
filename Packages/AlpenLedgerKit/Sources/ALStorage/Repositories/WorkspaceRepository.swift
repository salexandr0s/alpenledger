import Foundation
import GRDB
import ALDomain

public protocol WorkspaceRepository: Sendable {
    func fetchWorkspace() throws -> Workspace?
    func saveWorkspace(_ workspace: Workspace) throws
}

public final class GRDBWorkspaceRepository: WorkspaceRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchWorkspace() throws -> Workspace? {
        try dbPool.read { db in
            try Workspace.fetchOne(db, sql: "SELECT * FROM workspaces LIMIT 1")
        }
    }

    public func saveWorkspace(_ workspace: Workspace) throws {
        try dbPool.write { db in
            try workspace.save(db)
        }
    }
}
