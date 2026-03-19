import Foundation
import ALWorkspace
import ALStorage

@MainActor
final class DependencyContainer {
    let workspaceService: WorkspaceService

    init(workspaceService: WorkspaceService = WorkspaceService()) {
        self.workspaceService = workspaceService
    }
}
