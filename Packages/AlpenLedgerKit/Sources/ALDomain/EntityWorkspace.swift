import Foundation

public struct EntityWorkspace: Hashable, Codable, Sendable {
    public let id: EntityWorkspaceID
    public let workspaceId: WorkspaceID
    public let entityId: LegalEntityID
    public var displayName: String
    public var isDefault: Bool
    public var lastAccessedAt: Date
    public let createdAt: Date

    public init(
        id: EntityWorkspaceID = EntityWorkspaceID(),
        workspaceId: WorkspaceID,
        entityId: LegalEntityID,
        displayName: String,
        isDefault: Bool = false,
        lastAccessedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.entityId = entityId
        self.displayName = displayName
        self.isDefault = isDefault
        self.lastAccessedAt = lastAccessedAt
        self.createdAt = createdAt
    }
}
