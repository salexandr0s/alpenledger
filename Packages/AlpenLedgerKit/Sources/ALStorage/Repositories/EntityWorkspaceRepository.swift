import Foundation
import GRDB
import ALDomain

public protocol EntityWorkspaceRepository: Sendable {
    func fetchEntityWorkspaces(workspaceId: WorkspaceID) throws -> [EntityWorkspace]
    func fetchEntityWorkspace(id: EntityWorkspaceID) throws -> EntityWorkspace?
    func fetchEntityWorkspace(workspaceId: WorkspaceID, entityId: LegalEntityID) throws -> EntityWorkspace?
    func saveEntityWorkspace(_ entityWorkspace: EntityWorkspace) throws
    func deleteEntityWorkspace(id: EntityWorkspaceID) throws
}

public final class GRDBEntityWorkspaceRepository: EntityWorkspaceRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchEntityWorkspaces(workspaceId: WorkspaceID) throws -> [EntityWorkspace] {
        try dbPool.read { db in
            try EntityWorkspace
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("lastAccessedAt").desc)
                .fetchAll(db)
        }
    }

    public func fetchEntityWorkspace(id: EntityWorkspaceID) throws -> EntityWorkspace? {
        try dbPool.read { db in
            try EntityWorkspace.fetchOne(db, key: id)
        }
    }

    public func fetchEntityWorkspace(workspaceId: WorkspaceID, entityId: LegalEntityID) throws -> EntityWorkspace? {
        try dbPool.read { db in
            try EntityWorkspace
                .filter(Column("workspaceId") == workspaceId && Column("entityId") == entityId)
                .fetchOne(db)
        }
    }

    public func saveEntityWorkspace(_ entityWorkspace: EntityWorkspace) throws {
        try dbPool.write { db in
            try entityWorkspace.save(db)
        }
    }

    public func deleteEntityWorkspace(id: EntityWorkspaceID) throws {
        try dbPool.write { db in
            _ = try EntityWorkspace.deleteOne(db, key: id)
        }
    }
}
