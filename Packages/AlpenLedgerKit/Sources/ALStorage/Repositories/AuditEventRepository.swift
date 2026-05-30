import Foundation
import GRDB
import ALDomain

public protocol AuditEventRepository: Sendable {
    func fetchAuditEvents(workspaceId: WorkspaceID, objectRef: ObjectRef?) throws -> [AuditEvent]
    func fetchAuditEvent(id: AuditEventID) throws -> AuditEvent?
    func saveAuditEvent(_ event: AuditEvent) throws
}

public final class GRDBAuditEventRepository: AuditEventRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchAuditEvents(workspaceId: WorkspaceID, objectRef: ObjectRef? = nil) throws -> [AuditEvent] {
        try dbPool.read { db in
            var request = AuditEvent
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("occurredAt").desc)

            if let objectRef {
                request = request.filter(Column("objectRef") == objectRef)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchAuditEvent(id: AuditEventID) throws -> AuditEvent? {
        try dbPool.read { db in
            try AuditEvent
                .filter(Column("id") == id)
                .fetchOne(db)
        }
    }

    public func saveAuditEvent(_ event: AuditEvent) throws {
        try dbPool.write { db in
            try event.save(db)
        }
    }
}
