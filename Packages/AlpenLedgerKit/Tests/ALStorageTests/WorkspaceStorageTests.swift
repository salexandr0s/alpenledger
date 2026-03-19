import Foundation
import Testing
@testable import ALWorkspace
@testable import ALStorage

@Test
func workspaceServiceCreatesEncryptedWorkspaceInTempDirectory() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)

    let storage = try workspaceService.createWorkspace(named: "Spec Workspace")

    #expect(FileManager.default.fileExists(atPath: storage.paths.databaseURL.path))
    #expect(FileManager.default.fileExists(atPath: storage.paths.manifestURL.path))
    #expect(try storage.workspaceRepository.fetchWorkspace()?.name == "Spec Workspace")
    #expect((try storage.auditEventRepository.fetchAuditEvents(workspaceId: storage.manifest.workspace.id, objectRef: nil)).isEmpty == false)
}
