import Foundation
import ALDomain
import ALStorage
import ALAudit

public final class WorkspaceService: @unchecked Sendable {
    private let storageManager: WorkspaceStorageManager
    private let recentStore: RecentWorkspacesStore

    public init(
        storageManager: WorkspaceStorageManager = WorkspaceStorageManager(),
        recentStore: RecentWorkspacesStore = RecentWorkspacesStore()
    ) {
        self.storageManager = storageManager
        self.recentStore = recentStore
    }

    public func createWorkspace(named name: String) throws -> WorkspaceStorage {
        let storage = try storageManager.createWorkspace(named: name)
        let logger = AuditLogger(storage: storage)

        try storage.workspaceRepository.saveWorkspace(storage.manifest.workspace)
        try logger.log(
            eventType: .workspaceCreated,
            objectRef: ObjectRef(kind: .workspace, id: storage.manifest.workspace.id.rawValue)
        )

        let entityService = LegalEntityService(storage: storage, auditLogger: logger)
        _ = try entityService.createDefaultNaturalPerson()

        recentStore.add(
            RecentWorkspaceReference(
                workspaceId: storage.manifest.workspace.id,
                name: storage.manifest.workspace.name,
                path: storage.paths.rootURL.path
            )
        )
        return storage
    }

    public func openWorkspace(at url: URL) throws -> WorkspaceStorage {
        let storage = try storageManager.openWorkspace(at: url)
        let logger = AuditLogger(storage: storage)
        try logger.log(
            eventType: .workspaceOpened,
            objectRef: ObjectRef(kind: .workspace, id: storage.manifest.workspace.id.rawValue)
        )
        recentStore.add(
            RecentWorkspaceReference(
                workspaceId: storage.manifest.workspace.id,
                name: storage.manifest.workspace.name,
                path: storage.paths.rootURL.path
            )
        )
        return storage
    }

    public func recentWorkspaces() -> [RecentWorkspaceReference] {
        recentStore.load()
    }
}
