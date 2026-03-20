import Foundation

public enum AuditActorType: String, Codable, CaseIterable, Sendable {
    case system
    case user
}

public enum AuditEventType: String, Codable, CaseIterable, Sendable {
    case workspaceCreated
    case workspaceOpened
    case workspaceRenamed
    case legalEntityCreated
    case legalEntityUpdated
    case legalEntityRemoved
    case ledgerSeeded
    case financialAccountCreated
    case importJobCreated
    case importJobCompleted
    case documentImported
    case statementImported
    case evidenceLinked
    case proposalCreated
    case proposalResolved
    case proposalRejected
    case issueOpened
    case issueResolved
    case issueDismissed
}

public struct AuditEvent: Hashable, Codable, Sendable {
    public let id: AuditEventID
    public let workspaceId: WorkspaceID
    public let actorType: AuditActorType
    public let actorId: String
    public var eventType: AuditEventType
    public var objectRef: ObjectRef
    public var payload: String?
    public var occurredAt: Date

    public init(
        id: AuditEventID = AuditEventID(),
        workspaceId: WorkspaceID,
        actorType: AuditActorType,
        actorId: String,
        eventType: AuditEventType,
        objectRef: ObjectRef,
        payload: String? = nil,
        occurredAt: Date = .now
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.actorType = actorType
        self.actorId = actorId
        self.eventType = eventType
        self.objectRef = objectRef
        self.payload = payload
        self.occurredAt = occurredAt
    }
}
