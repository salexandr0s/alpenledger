import Foundation
import ALDomain
import ALStorage
import ALAudit

public final class EntityWorkspaceService: Sendable {
    private let storage: WorkspaceStorage
    private let auditLogger: AuditLogger
    private let nowProvider: @Sendable () -> Date

    public init(
        storage: WorkspaceStorage,
        auditLogger: AuditLogger,
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.storage = storage
        self.auditLogger = auditLogger
        self.nowProvider = nowProvider
    }

    public func listEntityWorkspaces() throws -> [EntityWorkspace] {
        try storage.entityWorkspaceRepository.fetchEntityWorkspaces(workspaceId: storage.manifest.workspace.id)
    }

    public func activeEntityWorkspace() throws -> EntityWorkspace? {
        let workspaces = try listEntityWorkspaces()
        return workspaces.first(where: \.isDefault) ?? workspaces.first
    }

    public func setActiveEntityWorkspace(_ id: EntityWorkspaceID) throws {
        guard var workspace = try storage.entityWorkspaceRepository.fetchEntityWorkspace(id: id) else {
            return
        }
        workspace.lastAccessedAt = nowProvider()
        try storage.entityWorkspaceRepository.saveEntityWorkspace(workspace)
    }

    @discardableResult
    public func createEntityWorkspace(
        for entityId: LegalEntityID,
        displayName: String,
        isDefault: Bool = false
    ) throws -> EntityWorkspace {
        let entityWorkspace = EntityWorkspace(
            workspaceId: storage.manifest.workspace.id,
            entityId: entityId,
            displayName: displayName,
            isDefault: isDefault,
            lastAccessedAt: nowProvider(),
            createdAt: nowProvider()
        )
        try storage.entityWorkspaceRepository.saveEntityWorkspace(entityWorkspace)
        try auditLogger.log(
            eventType: .entityWorkspaceCreated,
            objectRef: ObjectRef(kind: .entityWorkspace, id: entityWorkspace.id.rawValue)
        )
        return entityWorkspace
    }

    public func deleteEntityWorkspace(_ id: EntityWorkspaceID) throws {
        try storage.entityWorkspaceRepository.deleteEntityWorkspace(id: id)
        try auditLogger.log(
            eventType: .entityWorkspaceDeleted,
            objectRef: ObjectRef(kind: .entityWorkspace, id: id.rawValue)
        )
    }
}
