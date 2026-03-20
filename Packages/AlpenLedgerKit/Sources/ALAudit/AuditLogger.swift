import Foundation
import ALDomain
import ALStorage

public protocol AuditEventWriter: Sendable {
    func write(_ event: AuditEvent) throws
}

public final class AuditLogger: AuditEventWriter, Sendable {
    private let repository: any AuditEventRepository
    private let workspaceId: WorkspaceID

    public init(storage: WorkspaceStorage) {
        self.repository = storage.auditEventRepository
        self.workspaceId = storage.manifest.workspace.id
    }

    public func write(_ event: AuditEvent) throws {
        try repository.saveAuditEvent(event)
    }

    public func log(
        actorType: AuditActorType = .system,
        actorId: String = "system",
        eventType: AuditEventType,
        objectRef: ObjectRef,
        payload: String? = nil
    ) throws {
        let event = AuditEvent(
            workspaceId: workspaceId,
            actorType: actorType,
            actorId: actorId,
            eventType: eventType,
            objectRef: objectRef,
            payload: payload
        )
        try write(event)
    }
}
