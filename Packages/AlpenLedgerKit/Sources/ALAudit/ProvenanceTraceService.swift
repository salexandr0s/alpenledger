import Foundation
import ALDomain
import ALStorage

public final class ProvenanceTraceService: @unchecked Sendable {
    private let repository: any AuditEventRepository
    private let workspaceId: WorkspaceID

    public init(storage: WorkspaceStorage) {
        self.repository = storage.auditEventRepository
        self.workspaceId = storage.manifest.workspace.id
    }

    public func events(for objectRef: ObjectRef) throws -> [AuditEvent] {
        try repository.fetchAuditEvents(workspaceId: workspaceId, objectRef: objectRef)
    }

    public func allEvents() throws -> [AuditEvent] {
        try repository.fetchAuditEvents(workspaceId: workspaceId, objectRef: nil)
    }
}
