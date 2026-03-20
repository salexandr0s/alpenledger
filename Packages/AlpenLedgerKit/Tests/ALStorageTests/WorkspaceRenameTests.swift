import Foundation
import Testing
@testable import ALDomain
@testable import ALStorage
@testable import ALWorkspace

@Test
func workspaceRenameUpdatesManifestDatabaseAndRecentWorkspaces() throws {
    let fixedNow = try #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let defaults = UserDefaults(suiteName: "WorkspaceRenameTests.\(UUID().uuidString)")!
    let recentStore = RecentWorkspacesStore(defaults: defaults)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: recentStore,
        nowProvider: { fixedNow }
    )

    let storage = try workspaceService.createWorkspace(named: "Original Workspace")
    let renamedStorage = try workspaceService.renameWorkspace(storage, name: "Renamed Workspace")

    #expect(renamedStorage.manifest.workspace.name == "Renamed Workspace")
    #expect(try renamedStorage.workspaceRepository.fetchWorkspace()?.name == "Renamed Workspace")

    let manifestData = try Data(contentsOf: renamedStorage.paths.manifestURL)
    let manifest = try JSONDecoder.alpenLedger.decode(WorkspaceManifest.self, from: manifestData)
    #expect(manifest.workspace.name == "Renamed Workspace")

    let recent = try #require(recentStore.load().first)
    #expect(recent.name == "Renamed Workspace")
    #expect(recent.workspaceId == renamedStorage.manifest.workspace.id)

    let auditEvents = try renamedStorage.auditEventRepository.fetchAuditEvents(
        workspaceId: renamedStorage.manifest.workspace.id,
        objectRef: nil
    )
    #expect(auditEvents.contains(where: { $0.eventType == .workspaceRenamed && $0.payload == "Renamed Workspace" }))
}
