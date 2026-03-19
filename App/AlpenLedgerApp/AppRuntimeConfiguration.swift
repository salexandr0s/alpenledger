import Foundation
import ALDomain
import ALStorage
import ALWorkspace

struct AppRuntimeConfiguration {
    let workspacesRootURL: URL?
    let secretStore: any SecretStore
    let recentDefaults: UserDefaults
    let uiDefaults: UserDefaults
    let nowProvider: @Sendable () -> Date

    static func fromEnvironment() -> AppRuntimeConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let workspacesRootURL = environment["ALPENLEDGER_WORKSPACES_ROOT"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        let secretStore: any SecretStore
        if let secretRoot = environment["ALPENLEDGER_SECRET_STORE_ROOT"] {
            secretStore = FileSecretStore(directoryURL: URL(fileURLWithPath: secretRoot, isDirectory: true))
        } else {
            secretStore = KeychainSecretStore()
        }

        let recentDefaults: UserDefaults
        let uiDefaults: UserDefaults
        if let suiteName = environment["ALPENLEDGER_DEFAULTS_SUITE"], let defaults = UserDefaults(suiteName: suiteName) {
            recentDefaults = defaults
            uiDefaults = defaults
        } else {
            recentDefaults = .standard
            uiDefaults = .standard
        }

        let nowProvider: @Sendable () -> Date
        if let fixedNow = environment["ALPENLEDGER_FIXED_NOW"],
           let parsedDate = ISO8601DateFormatter().date(from: fixedNow) {
            nowProvider = { parsedDate }
        } else {
            nowProvider = { .now }
        }

        return AppRuntimeConfiguration(
            workspacesRootURL: workspacesRootURL,
            secretStore: secretStore,
            recentDefaults: recentDefaults,
            uiDefaults: uiDefaults,
            nowProvider: nowProvider
        )
    }

    func makeWorkspaceService() -> WorkspaceService {
        let storageManager = WorkspaceStorageManager(
            secretStore: secretStore,
            workspacesRootURL: workspacesRootURL
        )
        let recentStore = RecentWorkspacesStore(defaults: recentDefaults)
        return WorkspaceService(
            storageManager: storageManager,
            recentStore: recentStore,
            nowProvider: nowProvider
        )
    }

    func makeUIPreferencesStore() -> WorkspaceUIPreferencesStore {
        WorkspaceUIPreferencesStore(defaults: uiDefaults)
    }
}

final class WorkspaceUIPreferencesStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func inspectorVisible(workspaceId: WorkspaceID, section: AppSection) -> Bool {
        defaults.object(forKey: key(for: workspaceId, section: section)) as? Bool ?? true
    }

    func setInspectorVisible(_ isVisible: Bool, workspaceId: WorkspaceID, section: AppSection) {
        defaults.set(isVisible, forKey: key(for: workspaceId, section: section))
    }

    private func key(for workspaceId: WorkspaceID, section: AppSection) -> String {
        "workspace-ui.\(workspaceId.description).\(section.rawValue).inspectorVisible"
    }
}
