import Foundation
import ALDomain
import ALWorkspace

@MainActor
final class DependencyContainer {
    let workspaceService: WorkspaceService
    let uiPreferencesStore: WorkspaceUIPreferencesStore
    let nowProvider: @Sendable () -> Date
    let featureFlags: AppFeatureFlags
    let privacyMode: AppPrivacyMode
    let modelProviderConsent: ModelProviderConsent
    let modelProviderRegistry: ModelProviderRegistry
    let modelProviderActivityLog: ModelProviderActivityLog
    let backupPanelClient: BackupPanelClient
    let workspaceLockAuthenticationClient: WorkspaceLockAuthenticationClient

    init(
        workspaceService: WorkspaceService = WorkspaceService(),
        uiPreferencesStore: WorkspaceUIPreferencesStore = WorkspaceUIPreferencesStore(),
        nowProvider: @escaping @Sendable () -> Date = { .now },
        featureFlags: AppFeatureFlags = .production,
        privacyMode: AppPrivacyMode = .localOnly,
        modelProviderConsent: ModelProviderConsent = .none,
        modelProviderRegistry: ModelProviderRegistry = .productionDefaults,
        modelProviderActivityLog: ModelProviderActivityLog = ModelProviderActivityLog(),
        backupPanelClient: BackupPanelClient = .live,
        workspaceLockAuthenticationClient: WorkspaceLockAuthenticationClient = .live
    ) {
        self.workspaceService = workspaceService
        self.uiPreferencesStore = uiPreferencesStore
        self.nowProvider = nowProvider
        self.featureFlags = featureFlags
        self.privacyMode = privacyMode
        self.modelProviderConsent = privacyMode == .localOnly ? .none : modelProviderConsent
        self.modelProviderRegistry = modelProviderRegistry
        self.modelProviderActivityLog = modelProviderActivityLog
        self.backupPanelClient = backupPanelClient
        self.workspaceLockAuthenticationClient = workspaceLockAuthenticationClient
    }

    static func live() -> DependencyContainer {
        let runtime = AppRuntimeConfiguration.fromEnvironment()
        return DependencyContainer(
            workspaceService: runtime.makeWorkspaceService(),
            uiPreferencesStore: runtime.makeUIPreferencesStore(),
            nowProvider: runtime.nowProvider,
            featureFlags: runtime.featureFlags,
            privacyMode: runtime.privacyMode,
            modelProviderConsent: runtime.modelProviderConsent,
            modelProviderRegistry: runtime.modelProviderRegistry,
            backupPanelClient: runtime.backupPanelClient,
            workspaceLockAuthenticationClient: runtime.workspaceLockAuthenticationClient
        )
    }
}
