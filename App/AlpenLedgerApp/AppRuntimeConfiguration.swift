import Foundation
import LocalAuthentication
import ALDomain
import ALStorage
import ALWorkspace

struct AppRuntimeConfiguration {
    let workspacesRootURL: URL?
    let secretStore: any SecretStore
    let recentDefaults: UserDefaults
    let uiDefaults: UserDefaults
    let nowProvider: @Sendable () -> Date
    let featureFlags: AppFeatureFlags
    let privacyMode: AppPrivacyMode
    let modelProviderConsent: ModelProviderConsent
    let modelProviderRegistry: ModelProviderRegistry
    let backupPanelClient: BackupPanelClient
    let workspaceLockAuthenticationClient: WorkspaceLockAuthenticationClient

    static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> AppRuntimeConfiguration {
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

        let privacyMode = AppPrivacyMode.fromEnvironment(environment)

        return AppRuntimeConfiguration(
            workspacesRootURL: workspacesRootURL,
            secretStore: secretStore,
            recentDefaults: recentDefaults,
            uiDefaults: uiDefaults,
            nowProvider: nowProvider,
            featureFlags: AppFeatureFlags.fromEnvironment(environment),
            privacyMode: privacyMode,
            modelProviderConsent: AppModelProviderConsent.fromEnvironment(environment, privacyMode: privacyMode),
            modelProviderRegistry: .productionDefaults,
            backupPanelClient: backupPanelClient(from: environment),
            workspaceLockAuthenticationClient: .live
        )
    }

    private static func backupPanelClient(from environment: [String: String]) -> BackupPanelClient {
#if DEBUG
        BackupPanelClient.debugAutomation(from: environment) ?? .live
#else
        .live
#endif
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

struct AppFeatureFlags: Equatable, Sendable {
    var qaValidationFixtures: Bool

    static let production = AppFeatureFlags(qaValidationFixtures: false)

    static func fromEnvironment(_ environment: [String: String]) -> AppFeatureFlags {
        var flags = AppFeatureFlags.production

        let enabledFlags = environment["ALPENLEDGER_FEATURE_FLAGS"]
            .map(parseFeatureList(_:)) ?? []
        if enabledFlags.contains("all") || enabledFlags.contains("qa-validation-fixtures") {
            flags.qaValidationFixtures = true
        }

        if let explicitValue = environment["ALPENLEDGER_ENABLE_QA_VALIDATION_FIXTURES"]
            .flatMap(parseBoolean(_:)) {
            flags.qaValidationFixtures = explicitValue
        }

        return flags
    }

    private static func parseFeatureList(_ rawValue: String) -> Set<String> {
        Set(
            rawValue
                .split(separator: ",")
                .map { normalizeFeatureName(String($0)) }
                .filter { $0.isEmpty == false }
        )
    }

    private static func normalizeFeatureName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.reduce(into: "") { result, character in
            if character == "_" || character == " " {
                result.append("-")
            } else if character.isUppercase {
                if result.isEmpty == false, result.last != "-" {
                    result.append("-")
                }
                result.append(contentsOf: character.lowercased())
            } else {
                result.append(character.lowercased())
            }
        }
    }

    private static func parseBoolean(_ rawValue: String) -> Bool? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            true
        case "0", "false", "no", "n", "off":
            false
        default:
            nil
        }
    }
}

enum AppPrivacyMode: String, Equatable, Sendable {
    case localOnly = "local-only"
    case hybrid
    case externalAssistant = "external-assistant"

    static func fromEnvironment(_ environment: [String: String]) -> AppPrivacyMode {
        guard let rawValue = environment["ALPENLEDGER_PRIVACY_MODE"] else {
            return .localOnly
        }

        switch normalize(rawValue) {
        case "", "local", "local-only", "localonly", "offline":
            return .localOnly
        case "hybrid", "mixed":
            return .hybrid
        case "external", "external-assistant", "externalassistant", "codex", "mcp":
            return .externalAssistant
        default:
            return .localOnly
        }
    }

    var allowsNetworkRuntime: Bool {
        switch self {
        case .localOnly:
            false
        case .hybrid, .externalAssistant:
            true
        }
    }

    var allowsCloudInference: Bool {
        switch self {
        case .localOnly:
            false
        case .hybrid, .externalAssistant:
            true
        }
    }

    var modelProviderPrivacyMode: ModelProviderPrivacyMode {
        switch self {
        case .localOnly:
            .airGapped
        case .hybrid:
            .hybrid
        case .externalAssistant:
            .externalAssistant
        }
    }

    var workspaceTypeLabel: String {
        switch self {
        case .localOnly:
            "Local-only encrypted workspace"
        case .hybrid:
            "Encrypted workspace with approved AI providers"
        case .externalAssistant:
            "Encrypted workspace with external assistant bridge"
        }
    }

    var privacyStatusLabel: String {
        switch self {
        case .localOnly:
            "Encrypted locally; cloud and network providers disabled"
        case .hybrid:
            "Encrypted locally; approved providers require consent and redaction"
        case .externalAssistant:
            "Encrypted locally; external assistant access is scoped and approval-gated"
        }
    }

    var aiPrivacyModeTitle: String {
        switch self {
        case .localOnly:
            "Air-gapped local AI"
        case .hybrid:
            "Hybrid AI with consent"
        case .externalAssistant:
            "External assistant with scoped access"
        }
    }

    var aiPrivacyModeDetail: String {
        switch self {
        case .localOnly:
            "Only in-process local providers are available; cloud and network model providers are disabled."
        case .hybrid:
            "Local providers remain available, and approved off-device providers can run only after explicit consent and redaction limits are satisfied."
        case .externalAssistant:
            "External assistant providers require approved scopes, explicit consent, and redacted inputs before any workspace data can leave the device."
        }
    }

    var networkActivityLabel: String {
        switch self {
        case .localOnly:
            "Disabled for model providers"
        case .hybrid:
            "Allowed only for approved providers"
        case .externalAssistant:
            "Allowed only through scoped assistant providers"
        }
    }

    var cloudInferenceLabel: String {
        switch self {
        case .localOnly:
            "Disabled"
        case .hybrid:
            "Consent-gated"
        case .externalAssistant:
            "Scoped and consent-gated"
        }
    }

    fileprivate static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }
}

enum AppModelProviderConsent {
    static func fromEnvironment(
        _ environment: [String: String],
        privacyMode: AppPrivacyMode
    ) -> ModelProviderConsent {
        guard privacyMode != .localOnly else {
            return .none
        }

        return ModelProviderConsent(
            allowsNetworkAccess: parseBoolean(environment["ALPENLEDGER_AI_ALLOW_NETWORK"]) ?? false,
            allowsOffDeviceData: parseBoolean(environment["ALPENLEDGER_AI_ALLOW_OFF_DEVICE"]) ?? false,
            approvedProviderIDs: parseProviderIDs(environment["ALPENLEDGER_AI_APPROVED_PROVIDERS"]),
            redactionPolicy: parseRedactionPolicy(environment["ALPENLEDGER_AI_REDACTION_POLICY"]) ?? .metadataOnly
        )
    }

    private static func parseBoolean(_ rawValue: String?) -> Bool? {
        guard let rawValue else { return nil }
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return nil
        }
    }

    private static func parseProviderIDs(_ rawValue: String?) -> Set<String> {
        guard let rawValue else { return [] }
        return Set(
            rawValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
        )
    }

    private static func parseRedactionPolicy(_ rawValue: String?) -> ModelProviderRedactionPolicy? {
        guard let rawValue else { return nil }
        switch AppPrivacyMode.normalize(rawValue) {
        case "metadata", "metadata-only", "metadataonly":
            return .metadataOnly
        case "redacted", "redacted-snippets", "redactedsnippets", "snippets":
            return .redactedSnippets
        default:
            return nil
        }
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

    func preferredStatementImportAccountId(workspaceId: WorkspaceID) -> FinancialAccountID? {
        guard let rawValue = defaults.string(forKey: importAccountKey(for: workspaceId)),
              let uuid = UUID(uuidString: rawValue)
        else {
            return nil
        }
        return FinancialAccountID(rawValue: uuid)
    }

    func setPreferredStatementImportAccountId(_ accountId: FinancialAccountID?, workspaceId: WorkspaceID) {
        let key = importAccountKey(for: workspaceId)
        if let accountId {
            defaults.set(accountId.rawValue.uuidString, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func workspaceLockEnabled(workspaceId: WorkspaceID) -> Bool {
        defaults.object(forKey: workspaceLockKey(for: workspaceId)) as? Bool ?? false
    }

    func setWorkspaceLockEnabled(_ isEnabled: Bool, workspaceId: WorkspaceID) {
        let key = workspaceLockKey(for: workspaceId)
        if isEnabled {
            defaults.set(true, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func key(for workspaceId: WorkspaceID, section: AppSection) -> String {
        "workspace-ui.\(workspaceId.description).\(section.rawValue).inspectorVisible"
    }

    private func importAccountKey(for workspaceId: WorkspaceID) -> String {
        "workspace-ui.\(workspaceId.description).statementImport.defaultAccountId"
    }

    private func workspaceLockKey(for workspaceId: WorkspaceID) -> String {
        "workspace-ui.\(workspaceId.description).lock.enabled"
    }
}

struct WorkspaceLockAuthenticationClient {
    let authenticate: @MainActor (_ reason: String, _ completion: @escaping @MainActor (Bool) -> Void) -> Void

    static let live = WorkspaceLockAuthenticationClient { reason, completion in
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(false)
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            Task { @MainActor in
                completion(success)
            }
        }
    }

    static let approving = WorkspaceLockAuthenticationClient { _, completion in
        completion(true)
    }

    static let rejecting = WorkspaceLockAuthenticationClient { _, completion in
        completion(false)
    }
}
