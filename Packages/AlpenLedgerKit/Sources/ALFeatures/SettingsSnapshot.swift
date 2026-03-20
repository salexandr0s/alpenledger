import Foundation
import ALDomain

public struct SettingsSnapshot: Sendable {
    public struct WorkspaceDetails: Sendable {
        public let name: String
        public let type: String
        public let location: String
        public let encryptionStatus: String
        public let createdAt: String

        public init(name: String, type: String, location: String, encryptionStatus: String, createdAt: String) {
            self.name = name
            self.type = type
            self.location = location
            self.encryptionStatus = encryptionStatus
            self.createdAt = createdAt
        }
    }

    public let workspace: WorkspaceDetails
    public let entities: [EntityRowModel]

    public init(workspace: WorkspaceDetails, entities: [EntityRowModel]) {
        self.workspace = workspace
        self.entities = entities
    }
}

public struct EntityRowModel: Identifiable, Sendable {
    public let id: LegalEntityID
    public let name: String
    public let kindLabel: String
    public let detail: String
    public let canRemove: Bool
    public let removalHint: String?

    public init(
        id: LegalEntityID,
        name: String,
        kindLabel: String,
        detail: String,
        canRemove: Bool,
        removalHint: String?
    ) {
        self.id = id
        self.name = name
        self.kindLabel = kindLabel
        self.detail = detail
        self.canRemove = canRemove
        self.removalHint = removalHint
    }
}
