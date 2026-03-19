import Foundation
import ALWorkspace

@MainActor
final class DependencyContainer {
    let workspaceService: WorkspaceService
    let uiPreferencesStore: WorkspaceUIPreferencesStore
    let nowProvider: @Sendable () -> Date

    init(
        workspaceService: WorkspaceService = WorkspaceService(),
        uiPreferencesStore: WorkspaceUIPreferencesStore = WorkspaceUIPreferencesStore(),
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.workspaceService = workspaceService
        self.uiPreferencesStore = uiPreferencesStore
        self.nowProvider = nowProvider
    }

    static func live() -> DependencyContainer {
        let runtime = AppRuntimeConfiguration.fromEnvironment()
        return DependencyContainer(
            workspaceService: runtime.makeWorkspaceService(),
            uiPreferencesStore: runtime.makeUIPreferencesStore(),
            nowProvider: runtime.nowProvider
        )
    }
}
