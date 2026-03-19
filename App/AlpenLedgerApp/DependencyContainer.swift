import Foundation
import ALWorkspace
import ALStorage

@MainActor
final class DependencyContainer {
    let workspaceService: WorkspaceService
    let nowProvider: @Sendable () -> Date

    init(
        workspaceService: WorkspaceService = WorkspaceService(),
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.workspaceService = workspaceService
        self.nowProvider = nowProvider
    }

    static func live() -> DependencyContainer {
        let runtime = AppRuntimeConfiguration.fromEnvironment()
        return DependencyContainer(
            workspaceService: runtime.makeWorkspaceService(),
            nowProvider: runtime.nowProvider
        )
    }
}
