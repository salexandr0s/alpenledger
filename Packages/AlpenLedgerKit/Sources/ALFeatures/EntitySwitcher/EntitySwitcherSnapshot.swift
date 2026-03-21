import Foundation
import ALDomain

public struct EntitySwitcherSnapshot: Sendable {
    public struct EntityItem: Identifiable, Sendable {
        public let id: EntityWorkspaceID
        public let entityId: LegalEntityID
        public let displayName: String
        public let isActive: Bool
        public let lastAccessedText: String

        public init(
            id: EntityWorkspaceID,
            entityId: LegalEntityID,
            displayName: String,
            isActive: Bool,
            lastAccessedText: String
        ) {
            self.id = id
            self.entityId = entityId
            self.displayName = displayName
            self.isActive = isActive
            self.lastAccessedText = lastAccessedText
        }
    }

    public let activeEntityName: String
    public let entities: [EntityItem]

    public init(activeEntityName: String, entities: [EntityItem]) {
        self.activeEntityName = activeEntityName
        self.entities = entities
    }
}
