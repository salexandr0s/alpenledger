import Foundation
import ALDomain
import ALStorage
import ALAudit

public final class WorkspaceService: Sendable {
    private let storageManager: WorkspaceStorageManager
    private let recentStore: RecentWorkspacesStore
    private let nowProvider: @Sendable () -> Date

    public init(
        storageManager: WorkspaceStorageManager = WorkspaceStorageManager(),
        recentStore: RecentWorkspacesStore = RecentWorkspacesStore(),
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.storageManager = storageManager
        self.recentStore = recentStore
        self.nowProvider = nowProvider
    }

    public func createWorkspace(named name: String) throws -> WorkspaceStorage {
        let storage = try storageManager.createWorkspace(named: name)
        let logger = AuditLogger(storage: storage)

        try storage.workspaceRepository.saveWorkspace(storage.manifest.workspace)
        try logger.log(
            eventType: .workspaceCreated,
            objectRef: ObjectRef(kind: .workspace, id: storage.manifest.workspace.id.rawValue)
        )

        let entityService = LegalEntityService(storage: storage, auditLogger: logger, nowProvider: nowProvider)
        _ = try entityService.createDefaultNaturalPerson()

        recentStore.upsert(recentReference(for: storage))
        return storage
    }

    public func openWorkspace(at url: URL) throws -> WorkspaceStorage {
        let storage = try storageManager.openWorkspace(at: url)
        let logger = AuditLogger(storage: storage)
        try logger.log(
            eventType: .workspaceOpened,
            objectRef: ObjectRef(kind: .workspace, id: storage.manifest.workspace.id.rawValue)
        )
        recentStore.upsert(recentReference(for: storage))
        return storage
    }

    public func recentWorkspaces() -> [RecentWorkspaceReference] {
        recentStore.load()
    }

    public func renameWorkspace(_ storage: WorkspaceStorage, name: String) throws -> WorkspaceStorage {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            throw DomainError.invalidWorkspaceName
        }

        var workspace = storage.manifest.workspace
        workspace.name = trimmedName
        try storage.workspaceRepository.saveWorkspace(workspace)

        let updatedManifest = WorkspaceManifest(
            workspace: workspace,
            rootPath: storage.manifest.rootPath,
            encryptionSalt: storage.manifest.encryptionSalt
        )
        try JSONEncoder.alpenLedger.encode(updatedManifest).write(to: storage.paths.manifestURL, options: .atomic)

        let logger = AuditLogger(storage: storage)
        try logger.log(
            actorType: .user,
            actorId: "user",
            eventType: .workspaceRenamed,
            objectRef: ObjectRef(kind: .workspace, id: workspace.id.rawValue),
            payload: trimmedName
        )

        let reopenedStorage = try storageManager.openWorkspace(at: storage.paths.rootURL)
        recentStore.upsert(recentReference(for: reopenedStorage))
        return reopenedStorage
    }

    private func recentReference(for storage: WorkspaceStorage) -> RecentWorkspaceReference {
        RecentWorkspaceReference(
            workspaceId: storage.manifest.workspace.id,
            name: storage.manifest.workspace.name,
            path: storage.paths.rootURL.path,
            lastOpenedAt: nowProvider()
        )
    }
}
