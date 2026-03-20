import Foundation
import GRDB
import ALDomain

public protocol LegalEntityRepository: Sendable {
    func fetchLegalEntities(workspaceId: WorkspaceID) throws -> [LegalEntity]
    func saveLegalEntity(_ entity: LegalEntity) throws
    func deleteLegalEntity(_ entityId: LegalEntityID) throws
}

public final class GRDBLegalEntityRepository: LegalEntityRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchLegalEntities(workspaceId: WorkspaceID) throws -> [LegalEntity] {
        try dbPool.read { db in
            try LegalEntity
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("displayName"))
                .fetchAll(db)
        }
    }

    public func saveLegalEntity(_ entity: LegalEntity) throws {
        try dbPool.write { db in
            try entity.save(db)
        }
    }

    public func deleteLegalEntity(_ entityId: LegalEntityID) throws {
        try dbPool.write { db in
            _ = try LegalEntity.deleteOne(db, key: entityId)
        }
    }
}
