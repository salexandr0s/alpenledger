import XCTest
import SwiftUI
import ALDesignSystem
import ALDomain
import ALEvidence
import ALFeatures
import ALImports
import ALStorage
import ALTaxCore
import ALWorkspace
@testable import AlpenLedgerApp

final class AlpenLedgerAppTests: XCTestCase {
    func testSmoke() {
        XCTAssertTrue(true)
    }

    @MainActor
    func testAppShellAndDesignSystemContractsExposeNativeMacPatterns() {
        let model = WorkspaceAppModel(container: DependencyContainer())

        XCTAssertEqual(AppSection.Group.allCases.map(\.title), ["Home", "Records", "Filing", "Utility"])
        XCTAssertEqual(AppSection.Group.home.sections, [.overview, .inbox, .copilot])
        XCTAssertEqual(AppSection.Group.records.sections, [.ledger, .documents])
        XCTAssertEqual(AppSection.Group.filing.sections, [.taxStudio])
        XCTAssertEqual(AppSection.Group.utility.sections, [.settings])
        XCTAssertEqual(AppSection.allCases.map(\.title), [
            "Overview",
            "Inbox",
            "Ledger",
            "Documents",
            "Tax Studio",
            "Settings",
            "Copilot",
        ])
        XCTAssertTrue(AppSection.allCases.allSatisfy { $0.subtitle.isEmpty == false })
        XCTAssertTrue(AppSection.allCases.allSatisfy { $0.systemImage.isEmpty == false })

        model.selectedSection = .ledger
        XCTAssertEqual(model.shellToolbarConfiguration.inspectorControl?.title, "Hide Inspector")
        XCTAssertEqual(
            model.shellToolbarConfiguration.inspectorControl?.accessibilityIdentifier,
            "toolbar.ledger.toggleInspector"
        )

        model.selectedSection = .documents
        XCTAssertEqual(model.shellToolbarConfiguration.inspectorControl?.title, "Hide Inspector")
        XCTAssertEqual(
            model.shellToolbarConfiguration.inspectorControl?.accessibilityIdentifier,
            "toolbar.documents.toggleInspector"
        )

        model.selectedSection = .overview
        XCTAssertNil(model.shellToolbarConfiguration.inspectorControl)

        XCTAssertEqual(AppTheme.cornerRadius, 8)
        XCTAssertLessThanOrEqual(AppTheme.largeCornerRadius, 10)
        XCTAssertEqual(AppTheme.sidebarIdealWidth, 230)
        XCTAssertEqual(AppTheme.inspectorIdealWidth, 280)
        XCTAssertGreaterThan(AppTheme.documentsFilenameMinWidth, 0)
        XCTAssertGreaterThan(AppTheme.ledgerAmountColumnWidth, 0)

        let tones: Set<StatusBadge.Tone> = [.neutral, .info, .success, .warning, .critical]
        XCTAssertEqual(tones.count, 5)
        XCTAssertEqual(DesignSystemPreviewCatalog.cases.map(\.id), [
            "status-badges",
            "summary-tiles",
            "work-item-rows",
            "document-reference-rows",
            "inspector-pane",
            "empty-states",
            "document-preview",
        ])

        let primitives: [Any] = [
            StatusBadge("Ready", tone: .success),
            PaneEmptyState("No documents", subtitle: "Import files to begin.", systemImage: "doc.text"),
            SummaryTile("Open Issues", value: "0", subtitle: "Clear", tone: .success, systemImage: "checkmark.circle"),
            InspectorPane("Review", subtitle: "Evidence") {
                Text("Source-backed")
            },
            DocumentPreviewHost(fileURL: nil, mediaType: "application/pdf"),
        ]
        XCTAssertEqual(primitives.count, 5)

        let demoGallery = DesignSystemDemoGallery()
        XCTAssertNotNil(demoGallery)
    }

    func testWorkspaceUIPreferencesStoreDefaultsToVisible() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = WorkspaceUIPreferencesStore(defaults: defaults)
        let workspaceId = WorkspaceID()

        XCTAssertTrue(store.inspectorVisible(workspaceId: workspaceId, section: .ledger))
        XCTAssertTrue(store.inspectorVisible(workspaceId: workspaceId, section: .documents))
    }

    func testWorkspaceUIPreferencesStorePersistsPerWorkspaceAndSection() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = WorkspaceUIPreferencesStore(defaults: defaults)
        let firstWorkspace = WorkspaceID()
        let secondWorkspace = WorkspaceID()

        store.setInspectorVisible(false, workspaceId: firstWorkspace, section: .ledger)
        store.setInspectorVisible(true, workspaceId: firstWorkspace, section: .documents)
        store.setInspectorVisible(false, workspaceId: secondWorkspace, section: .documents)

        XCTAssertFalse(store.inspectorVisible(workspaceId: firstWorkspace, section: .ledger))
        XCTAssertTrue(store.inspectorVisible(workspaceId: firstWorkspace, section: .documents))
        XCTAssertTrue(store.inspectorVisible(workspaceId: secondWorkspace, section: .ledger))
        XCTAssertFalse(store.inspectorVisible(workspaceId: secondWorkspace, section: .documents))
    }

    func testWorkspaceUIPreferencesStorePersistsStatementImportDefaultPerWorkspace() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = WorkspaceUIPreferencesStore(defaults: defaults)
        let firstWorkspace = WorkspaceID()
        let secondWorkspace = WorkspaceID()
        let firstAccount = FinancialAccountID()
        let secondAccount = FinancialAccountID()

        XCTAssertNil(store.preferredStatementImportAccountId(workspaceId: firstWorkspace))

        store.setPreferredStatementImportAccountId(firstAccount, workspaceId: firstWorkspace)
        store.setPreferredStatementImportAccountId(secondAccount, workspaceId: secondWorkspace)

        XCTAssertEqual(store.preferredStatementImportAccountId(workspaceId: firstWorkspace), firstAccount)
        XCTAssertEqual(store.preferredStatementImportAccountId(workspaceId: secondWorkspace), secondAccount)

        store.setPreferredStatementImportAccountId(nil, workspaceId: firstWorkspace)

        XCTAssertNil(store.preferredStatementImportAccountId(workspaceId: firstWorkspace))
        XCTAssertEqual(store.preferredStatementImportAccountId(workspaceId: secondWorkspace), secondAccount)
    }

    func testWorkspaceUIPreferencesStorePersistsWorkspaceLockPerWorkspace() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = WorkspaceUIPreferencesStore(defaults: defaults)
        let firstWorkspace = WorkspaceID()
        let secondWorkspace = WorkspaceID()

        XCTAssertFalse(store.workspaceLockEnabled(workspaceId: firstWorkspace))
        XCTAssertFalse(store.workspaceLockEnabled(workspaceId: secondWorkspace))

        store.setWorkspaceLockEnabled(true, workspaceId: firstWorkspace)

        XCTAssertTrue(store.workspaceLockEnabled(workspaceId: firstWorkspace))
        XCTAssertFalse(store.workspaceLockEnabled(workspaceId: secondWorkspace))

        store.setWorkspaceLockEnabled(false, workspaceId: firstWorkspace)

        XCTAssertFalse(store.workspaceLockEnabled(workspaceId: firstWorkspace))
    }

    func testFeatureFlagsDefaultToProductionSafe() {
        let flags = AppFeatureFlags.fromEnvironment([:])

        XCTAssertFalse(flags.qaValidationFixtures)
    }

    func testFeatureFlagsParseEnvironmentAndExplicitOverrides() {
        XCTAssertTrue(
            AppFeatureFlags.fromEnvironment([
                "ALPENLEDGER_FEATURE_FLAGS": "qaValidationFixtures"
            ]).qaValidationFixtures
        )
        XCTAssertTrue(
            AppFeatureFlags.fromEnvironment([
                "ALPENLEDGER_FEATURE_FLAGS": "qa-validation-fixtures,unknown"
            ]).qaValidationFixtures
        )
        XCTAssertTrue(
            AppFeatureFlags.fromEnvironment([
                "ALPENLEDGER_ENABLE_QA_VALIDATION_FIXTURES": "yes"
            ]).qaValidationFixtures
        )
        XCTAssertFalse(
            AppFeatureFlags.fromEnvironment([
                "ALPENLEDGER_FEATURE_FLAGS": "qa-validation-fixtures",
                "ALPENLEDGER_ENABLE_QA_VALIDATION_FIXTURES": "false"
            ]).qaValidationFixtures
        )
    }

    func testPrivacyModeDefaultsToLocalOnlyAndRejectsCloudRuntime() {
        let defaultConfiguration = AppRuntimeConfiguration.fromEnvironment([:])
        XCTAssertEqual(defaultConfiguration.privacyMode, .localOnly)
        XCTAssertFalse(defaultConfiguration.privacyMode.allowsNetworkRuntime)
        XCTAssertFalse(defaultConfiguration.privacyMode.allowsCloudInference)
        XCTAssertEqual(defaultConfiguration.privacyMode.modelProviderPrivacyMode, .airGapped)
        XCTAssertEqual(defaultConfiguration.modelProviderRegistry.providers, [.localRules])

        XCTAssertEqual(
            AppRuntimeConfiguration.fromEnvironment([
                "ALPENLEDGER_PRIVACY_MODE": "offline"
            ]).privacyMode,
            .localOnly
        )
        XCTAssertEqual(
            AppRuntimeConfiguration.fromEnvironment([
                "ALPENLEDGER_PRIVACY_MODE": "cloud"
            ]).privacyMode,
            .localOnly
        )

        let hybridConfiguration = AppRuntimeConfiguration.fromEnvironment([
            "ALPENLEDGER_PRIVACY_MODE": "hybrid",
            "ALPENLEDGER_AI_ALLOW_NETWORK": "yes",
            "ALPENLEDGER_AI_ALLOW_OFF_DEVICE": "true",
            "ALPENLEDGER_AI_APPROVED_PROVIDERS": "cloud.reasoning",
            "ALPENLEDGER_AI_REDACTION_POLICY": "redacted-snippets"
        ])
        XCTAssertEqual(hybridConfiguration.privacyMode, .hybrid)
        XCTAssertTrue(hybridConfiguration.privacyMode.allowsNetworkRuntime)
        XCTAssertTrue(hybridConfiguration.privacyMode.allowsCloudInference)
        XCTAssertEqual(hybridConfiguration.privacyMode.modelProviderPrivacyMode, .hybrid)
        XCTAssertTrue(hybridConfiguration.modelProviderConsent.allowsNetworkAccess)
        XCTAssertTrue(hybridConfiguration.modelProviderConsent.allowsOffDeviceData)
        XCTAssertEqual(hybridConfiguration.modelProviderConsent.approvedProviderIDs, ["cloud.reasoning"])
        XCTAssertEqual(hybridConfiguration.modelProviderConsent.redactionPolicy, .redactedSnippets)

        let localOnlyConfiguration = AppRuntimeConfiguration.fromEnvironment([
            "ALPENLEDGER_PRIVACY_MODE": "local-only",
            "ALPENLEDGER_AI_ALLOW_NETWORK": "yes",
            "ALPENLEDGER_AI_ALLOW_OFF_DEVICE": "true",
            "ALPENLEDGER_AI_APPROVED_PROVIDERS": "cloud.reasoning",
            "ALPENLEDGER_AI_REDACTION_POLICY": "redacted-snippets"
        ])
        XCTAssertEqual(localOnlyConfiguration.privacyMode, .localOnly)
        XCTAssertEqual(localOnlyConfiguration.modelProviderConsent, .none)
    }

    @MainActor
    func testRuntimeConfigurationCanProvideDeterministicBackupPanelSelectionsForUITests() {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let createURL = rootURL.appendingPathComponent("workspace-backup", isDirectory: true)
        let expectedBackupURL = createURL.appendingPathExtension("alpenledgerbackup")
        let configuration = AppRuntimeConfiguration.fromEnvironment([
            "ALPENLEDGER_UI_TEST_CREATE_BACKUP_URL": createURL.path,
            "ALPENLEDGER_UI_TEST_VALIDATE_BACKUP_URL": expectedBackupURL.path,
            "ALPENLEDGER_UI_TEST_RESTORE_BACKUP_URL": expectedBackupURL.path,
        ])

        XCTAssertEqual(
            configuration.backupPanelClient.createBackupDestination("ignored.alpenledgerbackup")?.standardizedFileURL.path,
            createURL.standardizedFileURL.path
        )
        XCTAssertEqual(
            configuration.backupPanelClient.backupValidationSource()?.standardizedFileURL.path,
            expectedBackupURL.standardizedFileURL.path
        )
        XCTAssertEqual(
            configuration.backupPanelClient.backupRestoreSource()?.standardizedFileURL.path,
            expectedBackupURL.standardizedFileURL.path
        )
    }

    @MainActor
    func testHelpCenterAndFirstRunOnboardingAreAvailableWithoutWorkspace() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppHelpCenter.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults)
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults)
            )
        )

        XCTAssertFalse(model.hasWorkspace)
        XCTAssertTrue(model.workspaceChooserSnapshot.recentWorkspaces.isEmpty)
        XCTAssertEqual(
            model.workspaceChooserSnapshot.onboardingItems.map(\.id),
            ["demo", "local-workspace", "backup"]
        )

        let helpSnapshot = model.helpCenterSnapshot
        XCTAssertEqual(helpSnapshot.sections.map(\.id), ["first-run", "evidence", "tax-readiness", "support"])
        XCTAssertTrue(helpSnapshot.privacyNotice.contains("local by default"))
        XCTAssertTrue(helpSnapshot.sections.allSatisfy { $0.items.isEmpty == false })

        XCTAssertFalse(model.isShowingHelpCenter)
        model.presentHelpCenter()
        XCTAssertTrue(model.isShowingHelpCenter)
        model.dismissHelpCenter()
        XCTAssertFalse(model.isShowingHelpCenter)
        XCTAssertFalse(model.hasWorkspace)
    }

    @MainActor
    func testSettingsSnapshotSurfacesLocalOnlyPrivacyMode() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppPrivacyMode.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults)
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                privacyMode: .localOnly
            )
        )

        model.newWorkspaceName = "Privacy Mode Workspace"
        model.createWorkspace()

        XCTAssertEqual(model.settingsSnapshot.workspace.type, "Local-only encrypted workspace")
        XCTAssertEqual(
            model.settingsSnapshot.workspace.encryptionStatus,
            "Encrypted locally; cloud and network providers disabled"
        )
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.modeTitle, "Air-gapped local AI")
        XCTAssertEqual(
            model.settingsSnapshot.aiPrivacy.modeDetail,
            "Only in-process local providers are available; cloud and network model providers are disabled."
        )
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.networkStatus, "Disabled for model providers")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.cloudStatus, "Disabled")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.activity.title, "Idle")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.activity.networkStatus, "Network idle")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.controls.map(\.id), [
            "network-consent",
            "off-device-consent",
            "redaction-policy",
            "approved-providers",
        ])
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.controls.first?.value, "Disabled")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.providers.map(\.id), ["local.rules"])
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.providers.first?.status, "Available")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.providers.first?.tone, .success)
    }

    @MainActor
    func testWorkspaceLockGateRequiresAuthenticationBeforeReopening() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppWorkspaceLock.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults)
        )
        var rejectedAuthenticationAttempts = 0
        let rejectingAuthenticationClient = WorkspaceLockAuthenticationClient { reason, completion in
            rejectedAuthenticationAttempts += 1
            XCTAssertTrue(reason.contains("Locked Workspace"))
            completion(false)
        }
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                workspaceLockAuthenticationClient: rejectingAuthenticationClient
            )
        )

        model.newWorkspaceName = "Locked Workspace"
        model.createWorkspace()

        let reference = try XCTUnwrap(model.recentWorkspaces.first)
        XCTAssertFalse(model.settingsSnapshot.workspaceLock.isEnabled)
        XCTAssertFalse(model.canLockCurrentWorkspace)

        model.setWorkspaceLockEnabled(true)

        XCTAssertTrue(model.settingsSnapshot.workspaceLock.isEnabled)
        XCTAssertTrue(model.canLockCurrentWorkspace)
        XCTAssertTrue(model.settingsSnapshot.workspaceLock.status.contains("enabled"))

        model.lockCurrentWorkspace()

        XCTAssertFalse(model.hasWorkspace)
        XCTAssertEqual(model.recentWorkspaces.first?.workspaceId, reference.workspaceId)

        model.openWorkspace(reference)

        XCTAssertEqual(rejectedAuthenticationAttempts, 1)
        XCTAssertFalse(model.hasWorkspace)
        XCTAssertEqual(model.errorTitle, "Workspace locked")

        var approvedAuthenticationAttempts = 0
        let approvingAuthenticationClient = WorkspaceLockAuthenticationClient { reason, completion in
            approvedAuthenticationAttempts += 1
            XCTAssertTrue(reason.contains("Locked Workspace"))
            completion(true)
        }
        let reopeningModel = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                workspaceLockAuthenticationClient: approvingAuthenticationClient
            )
        )

        reopeningModel.openWorkspace(reference)

        XCTAssertEqual(approvedAuthenticationAttempts, 1)
        XCTAssertTrue(reopeningModel.hasWorkspace)
        XCTAssertTrue(reopeningModel.settingsSnapshot.workspaceLock.isEnabled)
    }

    @MainActor
    func testSettingsSnapshotSurfacesHybridConsentAndRedactionControls() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppHybridPrivacyMode.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults)
        )
        let activityLog = ModelProviderActivityLog()
        activityLog.record(
            ModelProviderActivitySnapshot(
                providerID: "cloud.reasoning",
                providerName: "Cloud reasoning provider",
                capability: .taxExplanation,
                inputScope: .redactedSnippets,
                privacyMode: .hybrid,
                phase: .running,
                requiresNetworkAccess: true,
                sendsDataOffDevice: true,
                startedAt: Date(timeIntervalSince1970: 1_767_184_000)
            )
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                privacyMode: .hybrid,
                modelProviderConsent: ModelProviderConsent(
                    allowsNetworkAccess: true,
                    allowsOffDeviceData: true,
                    approvedProviderIDs: ["cloud.reasoning"],
                    redactionPolicy: .redactedSnippets
                ),
                modelProviderRegistry: ModelProviderRegistry(
                    providers: [.localRules, appTestCloudProvider]
                ),
                modelProviderActivityLog: activityLog
            )
        )

        model.newWorkspaceName = "Hybrid Privacy Workspace"
        model.createWorkspace()

        XCTAssertEqual(model.settingsSnapshot.workspace.type, "Encrypted workspace with approved AI providers")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.modeTitle, "Hybrid AI with consent")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.networkStatus, "Allowed only for approved providers")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.cloudStatus, "Consent-gated")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.activity.title, "Provider running")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.activity.networkStatus, "Network active")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.activity.offDeviceStatus, "Off-device request in progress")
        XCTAssertEqual(model.settingsSnapshot.aiPrivacy.activity.tone, .warning)

        let controls = Dictionary(uniqueKeysWithValues: model.settingsSnapshot.aiPrivacy.controls.map { ($0.id, $0) })
        XCTAssertEqual(controls["network-consent"]?.value, "Allowed")
        XCTAssertEqual(controls["off-device-consent"]?.value, "Allowed")
        XCTAssertEqual(controls["redaction-policy"]?.value, "Redacted snippets")
        XCTAssertEqual(controls["approved-providers"]?.value, "1 approved")

        let providers = Dictionary(uniqueKeysWithValues: model.settingsSnapshot.aiPrivacy.providers.map { ($0.id, $0) })
        XCTAssertEqual(providers["local.rules"]?.status, "Available")
        XCTAssertEqual(providers["cloud.reasoning"]?.status, "Available")
        XCTAssertEqual(providers["cloud.reasoning"]?.tone, .success)
    }

    @MainActor
    func testLocalOnlyOfflineSmokeCoversCoreWorkspaceWorkflow() throws {
        let fileManager = FileManager.default
        let tempRootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspacesRootURL = tempRootURL.appendingPathComponent("workspaces", isDirectory: true)
        let secretRootURL = tempRootURL.appendingPathComponent("secrets", isDirectory: true)
        let exportRootURL = tempRootURL.appendingPathComponent("exports", isDirectory: true)
        let defaultsSuiteName = "AppOfflineSmoke.\(UUID().uuidString)"
        let fixedNowRawValue = "2026-03-19T12:00:00Z"
        let fixedNow = try appTestDate(fixedNowRawValue)
        let runtime = AppRuntimeConfiguration.fromEnvironment([
            "ALPENLEDGER_WORKSPACES_ROOT": workspacesRootURL.path,
            "ALPENLEDGER_SECRET_STORE_ROOT": secretRootURL.path,
            "ALPENLEDGER_DEFAULTS_SUITE": defaultsSuiteName,
            "ALPENLEDGER_FIXED_NOW": fixedNowRawValue,
            "ALPENLEDGER_PRIVACY_MODE": "cloud"
        ])
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: runtime.makeWorkspaceService(),
                uiPreferencesStore: runtime.makeUIPreferencesStore(),
                nowProvider: runtime.nowProvider,
                privacyMode: runtime.privacyMode
            )
        )

        XCTAssertEqual(runtime.privacyMode, .localOnly)
        XCTAssertFalse(runtime.privacyMode.allowsNetworkRuntime)
        XCTAssertFalse(runtime.privacyMode.allowsCloudInference)
        XCTAssertNotNil(Bundle.main.url(forResource: "sample-bank-statement", withExtension: "csv"))
        XCTAssertNotNil(Bundle.main.url(forResource: "sample-receipt", withExtension: "pdf"))

        model.newWorkspaceName = "Offline Smoke Workspace"
        model.createWorkspace()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertTrue(model.hasWorkspace)
        XCTAssertEqual(model.workspaceName, "Offline Smoke Workspace")
        XCTAssertEqual(model.settingsSnapshot.workspace.type, "Local-only encrypted workspace")
        XCTAssertEqual(
            model.settingsSnapshot.workspace.encryptionStatus,
            "Encrypted locally; cloud and network providers disabled"
        )
        XCTAssertTrue(fileManager.fileExists(atPath: workspacesRootURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: secretRootURL.path))

        model.newSolePropName = "Offline Smoke Business"
        model.createSoleProp()
        let businessWorkspace = try XCTUnwrap(
            model.entityWorkspaces.first { $0.displayName == "Offline Smoke Business" }
        )
        model.switchEntity(to: businessWorkspace.id)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.activeEntityId, businessWorkspace.entityId)
        XCTAssertFalse(model.financialAccounts.isEmpty)
        let operatingAccount = try XCTUnwrap(model.financialAccounts.first)
        model.selectAccount(operatingAccount.id)

        model.importSampleData()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.transactions.count, 3)
        XCTAssertEqual(model.documents.count, 1)
        XCTAssertEqual(model.documents.first?.metadataStatus, .proposed)
        XCTAssertEqual(model.documentBrowserItems.first?.statusText, "Proposed")
        XCTAssertGreaterThanOrEqual(model.importJobs.count, 2)
        XCTAssertTrue(model.importJobs.contains { $0.kind == .documentIntake && $0.warningCount == 1 })
        XCTAssertTrue(model.importDiagnosticsByJobId.values.flatMap(\.self).contains {
            $0.code == "document.low_confidence_metadata"
        })
        XCTAssertGreaterThanOrEqual(model.openIssueCount, 1)
        let importHealth = try XCTUnwrap(model.session?.storage.databaseHealthReport())
        XCTAssertTrue(
            importHealth.isHealthy,
            "Database health issues after sample import: \(importHealth.issues), database: \(model.session?.storage.paths.databaseURL.path ?? "missing")"
        )

        model.globalSearchQuery = "Coffee"
        model.refreshGlobalSearchResults()
        let coffeeHit = try XCTUnwrap(
            model.globalSearchResults.first { $0.objectKind == .transaction }
        )
        model.openGlobalSearchHit(coffeeHit)

        XCTAssertEqual(model.selectedSection, .ledger)
        XCTAssertNotNil(model.selectedTransactionId)

        let diagnosticsURL = exportRootURL.appendingPathComponent("offline-diagnostics")
        let supportBundleURL = exportRootURL.appendingPathComponent("offline-support-bundle")
        let backupURL = exportRootURL.appendingPathComponent("offline-backup", isDirectory: true)
        let expectedBackupURL = backupURL.appendingPathExtension("alpenledgerbackup")

        model.exportDiagnostics(to: diagnosticsURL)
        model.exportSupportBundle(to: supportBundleURL)
        model.createBackup(at: backupURL)
        model.validateBackup(at: expectedBackupURL)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.latestDiagnosticsReport?.generatedAt, fixedNow)
        XCTAssertEqual(model.latestSupportBundle?.generatedAt, fixedNow)
        XCTAssertTrue(
            model.latestDiagnosticsReport?.databaseHealth.isHealthy == true,
            "Database health issues: \(model.latestDiagnosticsReport?.databaseHealth.issues ?? []), database: \(model.session?.storage.paths.databaseURL.path ?? "missing")"
        )
        XCTAssertFalse(model.latestSupportBundle?.privacy.includesWorkspaceName ?? true)
        XCTAssertEqual(model.settingsSnapshot.backup.integrity?.title, "Backup can be restored")
        XCTAssertTrue(fileManager.fileExists(atPath: diagnosticsURL.appendingPathExtension("json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: supportBundleURL.appendingPathExtension("json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBackupURL.appendingPathComponent("backup.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBackupURL.appendingPathComponent("workspace.key").path))

        model.restoreBackup(from: expectedBackupURL)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.workspaceName, "Offline Smoke Workspace")
        XCTAssertEqual(model.transactions.count, 3)
        XCTAssertEqual(model.documents.count, 1)
        XCTAssertEqual(model.settingsSnapshot.workspace.type, "Local-only encrypted workspace")
    }

    @MainActor
    func testCreateDemoWorkspaceBuildsLocalSampleWorkspace() throws {
        let fileManager = FileManager.default
        let tempRootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspacesRootURL = tempRootURL.appendingPathComponent("workspaces", isDirectory: true)
        let secretRootURL = tempRootURL.appendingPathComponent("secrets", isDirectory: true)
        let defaultsSuiteName = "AppDemoWorkspace.\(UUID().uuidString)"
        let fixedNowRawValue = "2026-04-05T10:00:00Z"
        let runtime = AppRuntimeConfiguration.fromEnvironment([
            "ALPENLEDGER_WORKSPACES_ROOT": workspacesRootURL.path,
            "ALPENLEDGER_SECRET_STORE_ROOT": secretRootURL.path,
            "ALPENLEDGER_DEFAULTS_SUITE": defaultsSuiteName,
            "ALPENLEDGER_FIXED_NOW": fixedNowRawValue
        ])
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: runtime.makeWorkspaceService(),
                uiPreferencesStore: runtime.makeUIPreferencesStore(),
                nowProvider: runtime.nowProvider,
                privacyMode: runtime.privacyMode
            )
        )

        model.createDemoWorkspace()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertTrue(model.hasWorkspace)
        XCTAssertTrue(model.workspaceName.hasPrefix("AlpenLedger Demo "))
        XCTAssertEqual(model.selectedSection, .overview)
        XCTAssertEqual(model.transactions.count, 3)
        XCTAssertEqual(model.documents.count, 1)
        XCTAssertGreaterThanOrEqual(model.importJobs.count, 2)
        XCTAssertGreaterThanOrEqual(model.openIssueCount, 1)
        XCTAssertEqual(model.workspaceChooserSnapshot.recentWorkspaces.first?.title, model.workspaceName)
        XCTAssertTrue(fileManager.fileExists(atPath: workspacesRootURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: secretRootURL.path))

        model.globalSearchQuery = "Coffee"
        model.refreshGlobalSearchResults()

        XCTAssertTrue(model.globalSearchResults.contains { $0.objectKind == .transaction })
    }

    @MainActor
    func testDomainErrorsProduceActionableAlertPresentation() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppErrorPresentation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults)
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults)
            )
        )

        model.newWorkspaceName = "   "
        model.createWorkspace()

        XCTAssertTrue(model.isShowingErrorAlert)
        XCTAssertEqual(model.errorTitle, DomainError.invalidWorkspaceName.userFacingTitle)
        XCTAssertEqual(model.errorMessage, DomainError.invalidWorkspaceName.localizedDescription)
        XCTAssertEqual(model.errorRecoverySuggestion, DomainError.invalidWorkspaceName.recoverySuggestion)
        XCTAssertTrue(model.errorAlertBody.contains(DomainError.invalidWorkspaceName.localizedDescription))
        XCTAssertTrue(model.errorAlertBody.contains(DomainError.invalidWorkspaceName.recoverySuggestion ?? ""))

        model.dismissErrorAlert()

        XCTAssertFalse(model.isShowingErrorAlert)
        XCTAssertNil(model.errorMessage)
        XCTAssertNil(model.errorRecoverySuggestion)
    }

#if DEBUG
    @MainActor
    func testQAValidationFixturesRequireFeatureFlagAndWorkspace() throws {
        let disabledModel = WorkspaceAppModel(container: DependencyContainer())
        XCTAssertFalse(disabledModel.shouldShowQAValidationFixturesCommand)
        XCTAssertFalse(disabledModel.canImportQAValidationFixtures)

        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppFeatureFlags.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults)
        )
        let enabledModel = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                featureFlags: AppFeatureFlags(qaValidationFixtures: true)
            )
        )

        XCTAssertTrue(enabledModel.shouldShowQAValidationFixturesCommand)
        XCTAssertFalse(enabledModel.canImportQAValidationFixtures)

        enabledModel.newWorkspaceName = "Flagged Fixture Workspace"
        enabledModel.createWorkspace()

        XCTAssertTrue(enabledModel.canImportQAValidationFixtures)
    }
#endif

    @MainActor
    func testSelectionCommandsFollowActiveSection() {
        let model = WorkspaceAppModel(container: DependencyContainer())

        XCTAssertFalse(model.canLinkSelectedDocument)
        XCTAssertFalse(model.canLinkSelectedTransaction)
        XCTAssertFalse(model.canToggleActiveInspector)

        model.selectedSection = .ledger
        model.selectedTransactionId = TransactionID()

        XCTAssertTrue(model.canLinkSelectedDocument)
        XCTAssertFalse(model.canLinkSelectedTransaction)
        XCTAssertFalse(model.canToggleActiveInspector)

        let document = Document(
            workspaceId: WorkspaceID(),
            blobHash: "selection-command-document",
            originalFilename: "selection-command.pdf",
            mediaType: "application/pdf"
        )
        model.seedUIStateForTesting(documents: [document])
        model.selectedSection = .documents
        model.selectedDocumentId = document.id

        XCTAssertFalse(model.canLinkSelectedDocument)
        XCTAssertTrue(model.canLinkSelectedTransaction)
        XCTAssertFalse(model.canToggleActiveInspector)
    }

    @MainActor
    func testToggleInspectorForActiveSectionRoutesToVisibleSectionOnly() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        model.isLedgerInspectorVisible = true
        model.isDocumentsInspectorVisible = true

        model.selectedSection = .ledger
        model.toggleInspectorForActiveSection()
        XCTAssertFalse(model.isLedgerInspectorVisible)
        XCTAssertTrue(model.isDocumentsInspectorVisible)

        model.selectedSection = .documents
        model.toggleInspectorForActiveSection()
        XCTAssertFalse(model.isDocumentsInspectorVisible)

        model.selectedSection = .overview
        model.toggleInspectorForActiveSection()
        XCTAssertFalse(model.isLedgerInspectorVisible)
        XCTAssertFalse(model.isDocumentsInspectorVisible)
    }

    @MainActor
    func testOverviewPrimaryActionPrioritizesOpenIssues() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let workspaceId = WorkspaceID()
        let issue = Issue(
            fingerprint: "issue-1",
            workspaceId: workspaceId,
            issueCode: .missingExpenseEvidence,
            severity: .blocking,
            status: .open,
            summary: "Receipt missing for office supplies",
            objectRef: ObjectRef(kind: .transaction, id: UUID())
        )
        let proposal = AgentProposal(
            fingerprint: "proposal-1",
            workspaceId: workspaceId,
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: ObjectRef(kind: .document, id: UUID()),
            summary: "Link receipt to coffee transaction",
            rationale: "Amounts and dates line up",
            confidence: 0.86
        )
        let requirement = Requirement(
            fingerprint: "requirement-1",
            entityId: LegalEntityID(),
            taxYearId: TaxYearID(),
            requirementCode: .expenseEvidence,
            subjectRef: ObjectRef(kind: .document, id: UUID()),
            summary: "Upload health insurance certificate",
            status: .pending
        )

        model.seedUIStateForTesting(
            issues: [issue],
            agentProposals: [proposal],
            taxRequirements: [requirement],
            taxReadinessSummary: TaxReadinessSummary(
                state: .needsAttention,
                openIssueCount: 1,
                pendingRequirementCount: 1,
                currentFactCount: 0,
                missingConceptCodes: []
            )
        )

        XCTAssertEqual(
            model.overviewSnapshot.priorityAction?.action,
            .openInbox(selection: InboxSelection.issue(issue.id))
        )
    }

    @MainActor
    func testPerformOverviewActionDeepLinksToTargetSelection() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let entityId = LegalEntityID()
        let taxYearId = TaxYearID()
        let account = FinancialAccount(
            entityId: entityId,
            accountType: .bank,
            institutionName: "Personal Bank",
            displayName: "Personal Bank",
            ledgerControlAccountId: LedgerAccountID()
        )
        let transaction = Transaction(
            accountId: account.id,
            sourceLineRef: "row-1",
            bookingDate: .now,
            amountMinor: -4250,
            currency: .chf,
            counterpartyName: "Coffee Bar Zurich",
            memo: "Team coffee"
        )
        let document = Document(
            workspaceId: WorkspaceID(),
            blobHash: "hash",
            originalFilename: "sample-receipt.pdf",
            mediaType: "application/pdf"
        )
        let taxFact = TaxFact(
            fingerprint: "fact-1",
            entityId: entityId,
            taxYearId: taxYearId,
            jurisdictionCode: "ch-zh",
            conceptCode: "personal.income.salary_gross",
            valueType: .money,
            moneyMinor: 9800000,
            status: .observed,
            rulesetVersion: "zh-personal-2026-v1"
        )

        model.seedUIStateForTesting(
            financialAccounts: [account],
            transactions: [transaction],
            documents: [document],
            taxFacts: [taxFact],
            selectedTaxEntityId: entityId,
            selectedTaxYearId: taxYearId,
            taxReadinessSummary: TaxReadinessSummary(
                state: .needsAttention,
                openIssueCount: 0,
                pendingRequirementCount: 0,
                currentFactCount: 1,
                missingConceptCodes: []
            )
        )

        model.performOverviewAction(.openLedger(accountId: account.id, transactionId: transaction.id))
        XCTAssertEqual(model.selectedSection, .ledger)
        XCTAssertEqual(model.selectedAccountId, account.id)
        XCTAssertEqual(model.selectedTransactionId, transaction.id)

        model.performOverviewAction(.openDocuments(documentId: document.id))
        XCTAssertEqual(model.selectedSection, .documents)
        XCTAssertEqual(model.selectedDocumentId, document.id)

        model.performOverviewAction(
            .openTaxStudio(entityId: entityId, taxYearId: taxYearId, factId: taxFact.id)
        )
        XCTAssertEqual(model.selectedSection, .taxStudio)
        XCTAssertEqual(model.selectedTaxEntityId, entityId)
        XCTAssertEqual(model.selectedTaxYearId, taxYearId)
        XCTAssertEqual(model.selectedTaxFactId, taxFact.id)
        XCTAssertEqual(model.selectedTaxStudioSelection, .fact(taxFact.id))
    }

    @MainActor
    func testCopilotSnapshotSurfacesSourceBackedAnswersAndContext() throws {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let workspaceId = WorkspaceID()
        let entityId = LegalEntityID()
        let taxYearId = TaxYearID()
        let satisfiedStatementImportId = StatementImportID()
        let account = FinancialAccount(
            entityId: entityId,
            accountType: .bank,
            institutionName: "Business Bank",
            displayName: "Business Bank",
            ledgerControlAccountId: LedgerAccountID()
        )
        let transaction = Transaction(
            accountId: account.id,
            statementImportId: satisfiedStatementImportId,
            sourceLineRef: "row-1",
            bookingDate: try appTestDate("2026-04-15T00:00:00Z"),
            amountMinor: -12_500,
            currency: .chf,
            counterpartyName: "Office Supplier",
            memo: "Printer paper"
        )
        let entity = LegalEntity(
            id: entityId,
            workspaceId: workspaceId,
            kind: .soleProprietor,
            legalName: "Pilot Consulting",
            displayName: "Pilot Consulting",
            canton: .zh
        )
        let taxYear = TaxYear(
            id: taxYearId,
            entityId: entityId,
            year: 2026,
            periodStart: try appTestDate("2026-01-01T00:00:00Z"),
            periodEnd: try appTestDate("2026-12-31T23:59:59Z"),
            canton: .zh,
            rulesetVersion: "zh-personal-2026-v1"
        )
        let issue = Issue(
            fingerprint: "expense-evidence-1",
            workspaceId: workspaceId,
            entityId: entityId,
            taxYearId: taxYearId,
            issueCode: .missingExpenseEvidence,
            severity: .blocking,
            status: .open,
            summary: "Receipt missing for office supplies",
            objectRef: ObjectRef(kind: .transaction, id: transaction.id.rawValue)
        )
        let requirement = Requirement(
            fingerprint: "tax-requirement-1",
            entityId: entityId,
            taxYearId: taxYearId,
            requirementCode: .expenseEvidence,
            subjectRef: ObjectRef(kind: .transaction, id: transaction.id.rawValue),
            summary: "Upload evidence for business expense",
            status: .pending
        )
        let statementRequirement = Requirement(
            fingerprint: "statement-coverage-jan",
            entityId: entityId,
            taxYearId: taxYearId,
            requirementCode: .statementCoverage,
            subjectRef: ObjectRef(kind: .financialAccount, id: account.id.rawValue),
            summary: "Statement coverage for Jan 2026",
            coverageStart: try appTestDate("2026-01-01T00:00:00Z"),
            coverageEnd: try appTestDate("2026-01-31T23:59:59Z"),
            status: .pending
        )
        let satisfiedStatementRequirement = Requirement(
            fingerprint: "statement-coverage-feb",
            entityId: entityId,
            taxYearId: taxYearId,
            requirementCode: .statementCoverage,
            subjectRef: ObjectRef(kind: .financialAccount, id: account.id.rawValue),
            summary: "Statement coverage for Feb 2026",
            coverageStart: try appTestDate("2026-02-01T00:00:00Z"),
            coverageEnd: try appTestDate("2026-02-28T23:59:59Z"),
            status: .satisfied,
            satisfiedByRef: ObjectRef(kind: .statementImport, id: satisfiedStatementImportId.rawValue)
        )
        let statementIssue = Issue(
            fingerprint: "statement-coverage-jan",
            workspaceId: workspaceId,
            entityId: entityId,
            taxYearId: taxYearId,
            issueCode: .missingStatementCoverage,
            severity: .blocking,
            status: .open,
            summary: "Missing monthly statement for Business Bank in Jan 2026",
            objectRef: ObjectRef(kind: .financialAccount, id: account.id.rawValue),
            relatedRef: ObjectRef(kind: .requirement, id: statementRequirement.id.rawValue)
        )
        let vatPeriod = VATPeriod(
            entityId: entityId,
            periodStart: try appTestDate("2026-04-01T00:00:00Z"),
            periodEnd: try appTestDate("2026-06-30T23:59:59Z"),
            currency: .chf
        )
        let vatReport = VATReconciliationReport(
            period: vatPeriod,
            jurisdictionCode: "ch-zh",
            rulesetVersion: "ch-vat-2026-v1",
            lines: [
                VATReconciliationLine(
                    transactionId: transaction.id,
                    taxCode: "VAT81",
                    treatment: .outputTax,
                    sourceAmountMinor: 10_810,
                    taxableBaseMinor: 10_000,
                    vatAmountMinor: 810,
                    currency: .chf
                ),
            ],
            issues: [
                VATReconciliationIssue(
                    severity: .warning,
                    code: "vat.review",
                    message: "Review VAT treatment",
                    sourceRef: ObjectRef(kind: .transaction, id: transaction.id.rawValue)
                ),
            ],
            outputTaxMinor: 810,
            inputTaxMinor: 0,
            netTaxPayableMinor: 810
        )

        model.seedUIStateForTesting(
            entities: [entity],
            financialAccounts: [account],
            transactions: [transaction],
            issues: [issue, statementIssue],
            taxYears: [taxYear],
            taxRequirements: [requirement, statementRequirement, satisfiedStatementRequirement],
            vatPeriodReports: [vatReport],
            selectedTaxEntityId: entityId,
            selectedTaxYearId: taxYearId,
            taxReadinessSummary: TaxReadinessSummary(
                state: .needsAttention,
                openIssueCount: 2,
                pendingRequirementCount: 2,
                currentFactCount: 1,
                missingConceptCodes: ["personal.self_employment.net_profit"]
            )
        )

        let snapshot = model.copilotSnapshot
        XCTAssertEqual(snapshot.title, "Copilot")
        XCTAssertTrue(snapshot.subtitle.contains("Pilot Consulting"))
        XCTAssertTrue(snapshot.subtitle.contains("2026"))
        XCTAssertTrue(snapshot.subtitle.contains("ZH"))
        XCTAssertEqual(snapshot.prompts.map(\.id), [
            "missing-tax-evidence",
            "expenses-without-invoices",
            "missing-monthly-extracts",
            "vat-due-high",
            "business-tax-export",
        ])

        let taxAnswer = try XCTUnwrap(snapshot.answers.first { $0.id == "missing-tax-evidence" })
        XCTAssertFalse(taxAnswer.sources.isEmpty)
        XCTAssertTrue(taxAnswer.sources.contains { $0.ref.kind == .taxYear })
        XCTAssertTrue(taxAnswer.sources.contains { $0.ref.kind == .requirement })
        XCTAssertTrue(taxAnswer.claims.allSatisfy { $0.sourceRefs.isEmpty == false })
        XCTAssertEqual(taxAnswer.followUpQuestions.map(\.id), [
            "satisfy-tax-requirement",
            "complete-missing-tax-facts",
        ])
        XCTAssertTrue(taxAnswer.followUpQuestions.allSatisfy { $0.sourceRefs.isEmpty == false })
        XCTAssertEqual(
            taxAnswer.followUpQuestions.first?.primaryAction,
            .openTaxStudio(entityId: entityId, taxYearId: taxYearId)
        )

        let expenseAnswer = try XCTUnwrap(snapshot.answers.first { $0.id == "expenses-without-invoices" })
        XCTAssertEqual(expenseAnswer.statusText, "1 open")
        XCTAssertTrue(expenseAnswer.sources.contains { $0.ref.kind == .issue })
        XCTAssertTrue(expenseAnswer.sources.contains { $0.ref.kind == .transaction })
        XCTAssertEqual(expenseAnswer.followUpQuestions.first?.id, "attach-expense-evidence")
        XCTAssertEqual(
            expenseAnswer.followUpQuestions.first?.primaryAction,
            .openInbox(selection: .issue(issue.id))
        )

        let statementAnswer = try XCTUnwrap(snapshot.answers.first { $0.id == "missing-monthly-extracts" })
        XCTAssertEqual(statementAnswer.statusText, "1 missing")
        XCTAssertTrue(statementAnswer.sources.contains { $0.ref.kind == .financialAccount })
        XCTAssertTrue(statementAnswer.sources.contains { $0.ref.kind == .requirement })
        XCTAssertTrue(statementAnswer.sources.contains { $0.ref.kind == .issue })
        XCTAssertTrue(statementAnswer.sources.contains { $0.ref.kind == .statementImport })
        XCTAssertTrue(statementAnswer.claims.allSatisfy { $0.sourceRefs.isEmpty == false })
        XCTAssertEqual(statementAnswer.followUpQuestions.first?.id, "import-missing-statement")
        XCTAssertEqual(
            statementAnswer.followUpQuestions.first?.primaryAction,
            .openInbox(selection: .issue(statementIssue.id))
        )

        let vatAnswer = try XCTUnwrap(snapshot.answers.first { $0.id == "vat-due-high" })
        XCTAssertEqual(vatAnswer.statusText, "8.10 CHF")
        XCTAssertTrue(vatAnswer.sources.contains { $0.ref.kind == .vatPeriod })
        XCTAssertEqual(vatAnswer.followUpQuestions.first?.id, "review-vat-issue")
        XCTAssertEqual(
            vatAnswer.followUpQuestions.first?.primaryAction,
            .openTaxStudio(entityId: entityId, taxYearId: taxYearId)
        )
    }

    @MainActor
    func testPerformCopilotActionDeepLinksToSourceObjects() throws {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let workspaceId = WorkspaceID()
        let entityId = LegalEntityID()
        let taxYearId = TaxYearID()
        let statementImportId = StatementImportID()
        let account = FinancialAccount(
            entityId: entityId,
            accountType: .bank,
            institutionName: "Business Bank",
            displayName: "Business Bank",
            ledgerControlAccountId: LedgerAccountID()
        )
        let transaction = Transaction(
            accountId: account.id,
            statementImportId: statementImportId,
            sourceLineRef: "row-1",
            bookingDate: try appTestDate("2026-04-15T00:00:00Z"),
            amountMinor: -12_500,
            currency: .chf,
            counterpartyName: "Office Supplier",
            memo: "Printer paper"
        )
        let document = Document(
            workspaceId: workspaceId,
            blobHash: "document-hash",
            originalFilename: "office-supplier.pdf",
            mediaType: "application/pdf"
        )
        let taxYear = TaxYear(
            id: taxYearId,
            entityId: entityId,
            year: 2026,
            periodStart: try appTestDate("2026-01-01T00:00:00Z"),
            periodEnd: try appTestDate("2026-12-31T23:59:59Z"),
            canton: .zh,
            rulesetVersion: "zh-personal-2026-v1"
        )
        let issue = Issue(
            fingerprint: "expense-evidence-1",
            workspaceId: workspaceId,
            entityId: entityId,
            taxYearId: taxYearId,
            issueCode: .missingExpenseEvidence,
            severity: .blocking,
            status: .open,
            summary: "Receipt missing for office supplies",
            objectRef: ObjectRef(kind: .transaction, id: transaction.id.rawValue)
        )
        let requirement = Requirement(
            fingerprint: "tax-requirement-1",
            entityId: entityId,
            taxYearId: taxYearId,
            requirementCode: .expenseEvidence,
            subjectRef: ObjectRef(kind: .transaction, id: transaction.id.rawValue),
            summary: "Upload evidence for business expense",
            status: .pending
        )
        let vatPeriod = VATPeriod(
            entityId: entityId,
            periodStart: try appTestDate("2026-04-01T00:00:00Z"),
            periodEnd: try appTestDate("2026-06-30T23:59:59Z"),
            currency: .chf
        )

        model.seedUIStateForTesting(
            financialAccounts: [account],
            transactions: [transaction],
            documents: [document],
            issues: [issue],
            taxYears: [taxYear],
            taxRequirements: [requirement],
            selectedTaxEntityId: entityId,
            selectedTaxYearId: taxYearId
        )

        model.performCopilotAction(.openSource(ObjectRef(kind: .issue, id: issue.id.rawValue)))
        XCTAssertEqual(model.selectedSection, .inbox)
        XCTAssertEqual(model.selectedInboxSelection, .issue(issue.id))

        model.performCopilotAction(.openSource(ObjectRef(kind: .transaction, id: transaction.id.rawValue)))
        XCTAssertEqual(model.selectedSection, .ledger)
        XCTAssertEqual(model.selectedAccountId, account.id)
        XCTAssertEqual(model.selectedTransactionId, transaction.id)

        model.performCopilotAction(.openSource(ObjectRef(kind: .financialAccount, id: account.id.rawValue)))
        XCTAssertEqual(model.selectedSection, .ledger)
        XCTAssertEqual(model.selectedAccountId, account.id)
        XCTAssertNil(model.selectedTransactionId)

        model.performCopilotAction(.openSource(ObjectRef(kind: .statementImport, id: statementImportId.rawValue)))
        XCTAssertEqual(model.selectedSection, .ledger)
        XCTAssertEqual(model.selectedAccountId, account.id)
        XCTAssertEqual(model.selectedTransactionId, transaction.id)

        model.performCopilotAction(.openSource(ObjectRef(kind: .document, id: document.id.rawValue)))
        XCTAssertEqual(model.selectedSection, .documents)
        XCTAssertEqual(model.selectedDocumentId, document.id)

        model.performCopilotAction(.openSource(ObjectRef(kind: .requirement, id: requirement.id.rawValue)))
        XCTAssertEqual(model.selectedSection, .taxStudio)
        XCTAssertEqual(model.selectedTaxStudioSelection, .requirement(requirement.id))

        model.performCopilotAction(.openSource(ObjectRef(kind: .vatPeriod, id: vatPeriod.id.rawValue)))
        XCTAssertEqual(model.selectedSection, .taxStudio)
        XCTAssertEqual(model.selectedTaxStudioSelection, .vatPeriod(vatPeriod.id))
    }

    @MainActor
    func testCopilotAnswerCanCreateInboxTask() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppCopilotTask.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = try appTestDate("2026-05-30T08:00:00Z")
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        model.newWorkspaceName = "Copilot Task Workspace"
        model.createWorkspace()
        let workspaceRef = ObjectRef(
            kind: .workspace,
            id: try XCTUnwrap(model.session?.storage.manifest.workspace.id.rawValue)
        )

        let answer = try XCTUnwrap(model.copilotSnapshot.answers.first { $0.id == "missing-tax-evidence" })
        guard case let .createTaskFromAnswer(taskDraft)? = answer.secondaryAction else {
            return XCTFail("Expected a Copilot task action")
        }

        XCTAssertEqual(taskDraft.answerId, "missing-tax-evidence")
        model.performCopilotAction(.createTaskFromAnswer(taskDraft))

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.selectedSection, .inbox)
        guard case let .issue(issueId)? = model.selectedInboxSelection else {
            return XCTFail("Expected Copilot task to select an inbox issue")
        }
        let task = try XCTUnwrap(model.issues.first { $0.id == issueId })
        XCTAssertEqual(task.issueCode, .copilotTask)
        XCTAssertEqual(task.status, .open)
        XCTAssertEqual(task.severity, .warning)
        XCTAssertEqual(task.summary, "Review Copilot answer: What is missing for this return?")
        XCTAssertEqual(task.objectRef, taskDraft.sourceRef ?? workspaceRef)
        XCTAssertEqual(model.inboxSnapshot.inspector?.title, "Copilot task")

        let auditEvents = try XCTUnwrap(model.session?.storage.auditEventRepository.fetchAuditEvents(
            workspaceId: try XCTUnwrap(model.session?.storage.manifest.workspace.id),
            objectRef: ObjectRef(kind: .issue, id: task.id.rawValue)
        ))
        XCTAssertTrue(
            auditEvents.contains { event in
                event.eventType == .issueOpened &&
                    event.actorType == .system &&
                    event.actorId == "system" &&
                    event.payload == task.summary
            },
            "Expected Copilot task creation to leave an audited issueOpened event"
        )

        let workspaceAuditEvents = try XCTUnwrap(model.session?.storage.auditEventRepository.fetchAuditEvents(
            workspaceId: try XCTUnwrap(model.session?.storage.manifest.workspace.id),
            objectRef: workspaceRef
        ))
        let agentToolPayloads: [AgentToolAuditPayload] = try workspaceAuditEvents
            .filter { $0.eventType == .agentToolExecuted }
            .map { event in
                let payload = try XCTUnwrap(event.payload)
                return try JSONDecoder.alpenLedger.decode(
                    AgentToolAuditPayload.self,
                    from: Data(payload.utf8)
                )
            }
        let taskToolPayload = try XCTUnwrap(
            agentToolPayloads.first { $0.toolName == "issues.open_or_update" }
        )
        XCTAssertEqual(taskToolPayload.sideEffect, .issueUpdate)
        XCTAssertEqual(Set(taskToolPayload.requiredScopes), [.issuesWrite])
        XCTAssertEqual(Set(taskToolPayload.grantedScopes), [.issuesWrite])
        XCTAssertFalse(taskToolPayload.confirmationProvided)
        XCTAssertTrue(taskToolPayload.provenanceRefs.contains(ObjectRef(kind: .issue, id: task.id.rawValue)))
    }

    @MainActor
    func testLedgerAccountSummaryShowsUnavailableWithoutRunningBalance() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let account = FinancialAccount(
            entityId: LegalEntityID(),
            accountType: .bank,
            institutionName: "Personal Bank",
            displayName: "Personal Bank",
            ledgerControlAccountId: LedgerAccountID()
        )

        model.seedUIStateForTesting(financialAccounts: [account])
        XCTAssertEqual(model.ledgerAccountSummaries.first?.balanceText, "Balance unavailable")

        var openingBalanceAccount = account
        openingBalanceAccount.openingBalanceMinor = 10_000
        model.seedUIStateForTesting(financialAccounts: [openingBalanceAccount], transactions: [
            Transaction(
                accountId: openingBalanceAccount.id,
                sourceLineRef: "row-opening-1",
                bookingDate: .now,
                amountMinor: -750,
                currency: .chf,
                counterpartyName: "Supplier",
                memo: "Office supplies"
            )
        ])
        XCTAssertEqual(model.ledgerAccountSummaries.first?.balanceText, "92.50 CHF")

        let transaction = Transaction(
            accountId: account.id,
            sourceLineRef: "row-1",
            bookingDate: .now,
            amountMinor: 1250,
            currency: .chf,
            counterpartyName: "Client",
            memo: "Transfer",
            balanceAfterMinor: 9250
        )
        model.seedUIStateForTesting(financialAccounts: [account], transactions: [transaction])
        XCTAssertEqual(model.ledgerAccountSummaries.first?.balanceText, "92.50 CHF")
    }

    @MainActor
    func testInboxSnapshotUsesShortIssueTitles() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let issue = Issue(
            fingerprint: "issue-short-title",
            workspaceId: WorkspaceID(),
            issueCode: .missingStatementCoverage,
            severity: .blocking,
            status: .open,
            summary: "Missing monthly statement for January 2026",
            objectRef: ObjectRef(kind: .financialAccount, id: UUID())
        )

        model.seedUIStateForTesting(issues: [issue])

        XCTAssertEqual(model.inboxSnapshot.rows.first?.title, "Statement missing")
    }

    @MainActor
    func testInboxProposalInspectorShowsDecisionMetadata() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let proposal = AgentProposal(
            fingerprint: "proposal-decision",
            workspaceId: WorkspaceID(),
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: ObjectRef(kind: .document, id: UUID()),
            summary: "Review receipt link",
            rationale: "The imported receipt has no confirmed transaction link.",
            confidence: 0.42,
            status: .rejected,
            decidedAt: Date(timeIntervalSince1970: 100),
            decidedBy: "reviewer",
            decisionReason: "Receipt belongs to another entity."
        )

        model.seedUIStateForTesting(agentProposals: [proposal])
        model.selectedInboxSelection = .proposal(proposal.id)

        let inspector = model.inboxSnapshot.inspector
        XCTAssertEqual(inspector?.statusText, "Rejected")
        let details = Dictionary(uniqueKeysWithValues: inspector?.details.map { ($0.id, $0.value) } ?? [])
        XCTAssertEqual(details["status"], "Rejected")
        XCTAssertEqual(details["decidedBy"], "reviewer")
        XCTAssertEqual(details["decisionReason"], "Receipt belongs to another entity.")
    }

    @MainActor
    func testInboxProposalConfidenceBandsAreVisibleInRowsAndInspector() {
        let workspaceId = WorkspaceID()
        let lowConfidence = AgentProposal(
            fingerprint: "proposal-low-confidence",
            workspaceId: workspaceId,
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: ObjectRef(kind: .document, id: UUID()),
            summary: "Review ambiguous receipt",
            rationale: "The date is close, but the amount differs.",
            confidence: 0.42,
            status: .pending
        )
        let mediumConfidence = AgentProposal(
            fingerprint: "proposal-medium-confidence",
            workspaceId: workspaceId,
            agentKind: .systemHeuristics,
            proposalType: .transactionMappingReview,
            targetRef: ObjectRef(kind: .transaction, id: UUID()),
            summary: "Review category suggestion",
            rationale: "The counterparty matches a prior expense.",
            confidence: 0.72,
            status: .pending
        )
        let highConfidence = AgentProposal(
            fingerprint: "proposal-high-confidence",
            workspaceId: workspaceId,
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: ObjectRef(kind: .document, id: UUID()),
            summary: "Review clear receipt match",
            rationale: "The amount, date, and reference match.",
            confidence: 0.91,
            status: .pending
        )
        let model = WorkspaceAppModel(container: DependencyContainer())

        model.seedUIStateForTesting(agentProposals: [lowConfidence, mediumConfidence, highConfidence])

        let proposalRows = Dictionary(
            uniqueKeysWithValues: model.inboxSnapshot.rows
                .filter { $0.tab == .proposals }
                .map { ($0.title, $0) }
        )
        XCTAssertEqual(proposalRows["Review ambiguous receipt"]?.statusText, "Low confidence (42%)")
        XCTAssertEqual(proposalRows["Review ambiguous receipt"]?.tone, .critical)
        XCTAssertEqual(proposalRows["Review category suggestion"]?.statusText, "Medium confidence (72%)")
        XCTAssertEqual(proposalRows["Review category suggestion"]?.tone, .warning)
        XCTAssertEqual(proposalRows["Review clear receipt match"]?.statusText, "High confidence (91%)")
        XCTAssertEqual(proposalRows["Review clear receipt match"]?.tone, .success)

        model.selectedInboxSelection = .proposal(lowConfidence.id)
        let details = Dictionary(uniqueKeysWithValues: model.inboxSnapshot.inspector?.details.map { ($0.id, $0.value) } ?? [])
        XCTAssertEqual(details["confidence"], "Low confidence (42%)")
        XCTAssertEqual(details["reviewPath"], "Manual review required before approval")
    }

    @MainActor
    func testInboxProposalInspectorOffersApprovalForDocumentMatch() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let documentRef = ObjectRef(kind: .document, id: UUID())
        let transactionRef = ObjectRef(kind: .transaction, id: UUID())
        let proposal = AgentProposal(
            fingerprint: "proposal-approval",
            workspaceId: WorkspaceID(),
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: documentRef,
            relatedRef: transactionRef,
            summary: "Review receipt match",
            rationale: "The receipt amount and date match the transaction.",
            confidence: 0.91,
            status: .pending
        )

        model.seedUIStateForTesting(agentProposals: [proposal])
        model.selectedInboxSelection = .proposal(proposal.id)

        let inspector = model.inboxSnapshot.inspector
        let actions = inspector?.actions ?? []
        let details = Dictionary(uniqueKeysWithValues: inspector?.details.map { ($0.id, $0.value) } ?? [])
        let evidence = inspector?.evidence ?? []
        XCTAssertEqual(details["related"], transactionRef.stringValue)
        XCTAssertEqual(evidence.map(\.id), [
            ObjectRef(kind: .agentProposal, id: proposal.id.rawValue).stringValue,
            documentRef.stringValue,
            transactionRef.stringValue,
        ])
        XCTAssertEqual(evidence.map(\.title), [
            "Agent proposal",
            "Source document",
            "Linked transaction",
        ])
        XCTAssertTrue(actions.contains { $0.action == .approveProposal(proposal.id) && $0.role == .primary })
        XCTAssertTrue(actions.contains { $0.action == .rejectProposal(proposal.id) && $0.role == .destructive })
    }

    @MainActor
    func testLowConfidenceDocumentMatchDoesNotOfferDirectApproval() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let documentId = DocumentID()
        let documentRef = ObjectRef(kind: .document, id: documentId.rawValue)
        let transactionRef = ObjectRef(kind: .transaction, id: UUID())
        let proposal = AgentProposal(
            fingerprint: "proposal-low-confidence-approval",
            workspaceId: WorkspaceID(),
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: documentRef,
            relatedRef: transactionRef,
            summary: "Review uncertain receipt match",
            rationale: "The amount differs and the date is only nearby.",
            confidence: 0.42,
            status: .pending
        )

        model.seedUIStateForTesting(agentProposals: [proposal])
        model.selectedInboxSelection = .proposal(proposal.id)

        let actions = model.inboxSnapshot.inspector?.actions ?? []
        XCTAssertFalse(actions.contains { $0.action == .approveProposal(proposal.id) })
        XCTAssertTrue(actions.contains { $0.action == .openProposalTarget(documentRef) && $0.role == .primary })
        XCTAssertTrue(actions.contains { $0.action == .linkTransaction(documentId) && $0.role == .secondary })
        XCTAssertTrue(actions.contains { $0.action == .rejectProposal(proposal.id) && $0.role == .destructive })
    }

    @MainActor
    func testManualReviewProposalShowsQuestionAndBlocksDirectApproval() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let documentId = DocumentID()
        let documentRef = ObjectRef(kind: .document, id: documentId.rawValue)
        let transactionRef = ObjectRef(kind: .transaction, id: UUID())
        let proposal = AgentProposal(
            fingerprint: "proposal-manual-review-question",
            workspaceId: WorkspaceID(),
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: documentRef,
            relatedRef: transactionRef,
            summary: "Review receipt match with missing evidence",
            rationale: "The vendor matches, but the receipt total is unreadable.",
            confidence: 0.91,
            missingFields: ["receipt total", "payment reference"],
            question: "Can you confirm the total and reference on the receipt?",
            requiresManualReview: true,
            status: .pending
        )

        model.seedUIStateForTesting(agentProposals: [proposal])
        model.selectedInboxSelection = .proposal(proposal.id)

        let inspector = model.inboxSnapshot.inspector
        let details = Dictionary(uniqueKeysWithValues: inspector?.details.map { ($0.id, $0.value) } ?? [])
        let actions = inspector?.actions ?? []

        XCTAssertEqual(details["reviewPath"], "Manual review required before approval")
        XCTAssertEqual(details["missingFields"], "receipt total, payment reference")
        XCTAssertEqual(details["question"], "Can you confirm the total and reference on the receipt?")
        XCTAssertFalse(actions.contains { $0.action == .approveProposal(proposal.id) })
        XCTAssertTrue(actions.contains { $0.action == .openProposalTarget(documentRef) && $0.role == .primary })
    }

    @MainActor
    func testImportInspectorShowsStructuredParseDiagnostics() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let importJob = ImportJob(
            workspaceId: WorkspaceID(),
            kind: .bankStatementCSV,
            source: "statement.csv",
            parserKey: "csv.bankstatement",
            parserVersion: "1.1.0",
            status: .completed,
            warningCount: 1
        )
        let diagnostic = ImportDiagnostic(
            importJobId: importJob.id,
            severity: .warning,
            code: "csv.unparseable_amount",
            location: "csv:3",
            message: "Row 3: unparseable amount 'abc' - skipped"
        )

        model.seedUIStateForTesting(
            importJobs: [importJob],
            importDiagnosticsByJobId: [importJob.id: [diagnostic]]
        )
        model.selectedInboxSelection = .importJob(importJob.id)

        let rows = model.inboxSnapshot.rows.filter { $0.tab == .imports }
        let inspector = model.inboxSnapshot.inspector
        let details = Dictionary(uniqueKeysWithValues: inspector?.details.map { ($0.id, $0.value) } ?? [])

        XCTAssertEqual(rows.first?.subtitle, "1 warning")
        XCTAssertEqual(details["warnings"], "1")
        XCTAssertEqual(details["diagnostics"], "1 warning")
        XCTAssertEqual(details["diagnostic-\(diagnostic.id.rawValue.uuidString)"], diagnostic.message)
    }

    @MainActor
    func testImportInspectorOffersRetryForCancelledStatementImport() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let entityId = LegalEntityID()
        let account = FinancialAccount(
            entityId: entityId,
            accountType: .bank,
            institutionName: "Synthetic Bank",
            displayName: "Operating Account",
            ledgerControlAccountId: LedgerAccountID()
        )
        let importJob = ImportJob(
            workspaceId: WorkspaceID(),
            kind: .bankStatementCSV,
            source: "cancelled-statement.csv",
            sourceBlobHash: "stored-source-hash",
            parserKey: "csv.bankstatement",
            parserVersion: "1.1.0",
            status: .cancelled,
            completedAt: Date(timeIntervalSince1970: 1_767_184_000),
            warningCount: 1
        )
        let diagnostic = ImportDiagnostic(
            importJobId: importJob.id,
            severity: .warning,
            code: "import.cancelled",
            message: "Import was cancelled before completion."
        )

        model.seedUIStateForTesting(
            financialAccounts: [account],
            importJobs: [importJob],
            importDiagnosticsByJobId: [importJob.id: [diagnostic]]
        )
        model.selectedInboxSelection = .importJob(importJob.id)

        let inspector = model.inboxSnapshot.inspector
        let details = Dictionary(uniqueKeysWithValues: inspector?.details.map { ($0.id, $0.value) } ?? [])
        let actions = inspector?.actions ?? []

        XCTAssertEqual(details["status"], "Cancelled")
        XCTAssertEqual(details["sourceBlob"], "Available")
        XCTAssertEqual(details["retry"], "Available from stored source")
        XCTAssertTrue(inspector?.description.contains("retry it from the stored local source") == true)
        XCTAssertTrue(actions.contains { $0.action == .retryImport(importJob.id) && $0.role == .primary })
    }

    @MainActor
    func testInboxProposalInspectorOffersRevocationForApprovedDocumentMatch() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let documentRef = ObjectRef(kind: .document, id: UUID())
        let transactionRef = ObjectRef(kind: .transaction, id: UUID())
        let proposal = AgentProposal(
            fingerprint: "proposal-revocation",
            workspaceId: WorkspaceID(),
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: documentRef,
            relatedRef: transactionRef,
            summary: "Review receipt match",
            rationale: "The receipt amount and date match the transaction.",
            confidence: 0.91,
            status: .resolved
        )

        model.seedUIStateForTesting(agentProposals: [proposal])
        model.selectedInboxSelection = .proposal(proposal.id)

        let actions = model.inboxSnapshot.inspector?.actions ?? []
        XCTAssertTrue(actions.contains { $0.action == .revokeProposalApproval(proposal.id) && $0.role == .destructive })
        XCTAssertFalse(actions.contains { $0.action == .approveProposal(proposal.id) })
        XCTAssertFalse(actions.contains { $0.action == .rejectProposal(proposal.id) })
    }

    @MainActor
    func testTaxYearLockActionsUpdateTaxStudioSnapshotThroughWorkspaceAppModel() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppTaxYearLock.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        model.newWorkspaceName = "Period Lock Workspace"
        model.createWorkspace()
        let storage = try XCTUnwrap(model.session?.storage)
        let entityId = try XCTUnwrap(model.entities.first?.id)
        model.selectTaxEntity(entityId)
        let taxYearId = try XCTUnwrap(model.selectedTaxYearId)

        let openStatus = try XCTUnwrap(model.taxStudioSnapshot.periodStatus)
        XCTAssertEqual(openStatus.statusText, "Open")
        XCTAssertTrue(openStatus.canLock)
        XCTAssertFalse(openStatus.canUnlock)

        model.lockSelectedTaxYear()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.taxYears.first(where: { $0.id == taxYearId })?.status, .locked)
        let lockedStatus = try XCTUnwrap(model.taxStudioSnapshot.periodStatus)
        XCTAssertEqual(lockedStatus.statusText, "Locked")
        XCTAssertFalse(lockedStatus.canLock)
        XCTAssertTrue(lockedStatus.canUnlock)

        model.selectTaxYear(taxYearId)
        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")

        model.unlockSelectedTaxYear()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.taxYears.first(where: { $0.id == taxYearId })?.status, .open)
        let reopenedStatus = try XCTUnwrap(model.taxStudioSnapshot.periodStatus)
        XCTAssertEqual(reopenedStatus.statusText, "Open")
        XCTAssertTrue(reopenedStatus.canLock)
        XCTAssertFalse(reopenedStatus.canUnlock)

        let auditEvents = try storage.auditEventRepository.fetchAuditEvents(
            workspaceId: storage.manifest.workspace.id,
            objectRef: ObjectRef(kind: .taxYear, id: taxYearId.rawValue)
        )
        XCTAssertTrue(auditEvents.contains { $0.eventType == .taxYearLocked })
        XCTAssertTrue(auditEvents.contains { $0.eventType == .taxYearUnlocked })
        XCTAssertEqual(model.selectedTaxEntityId, entityId)
    }

    @MainActor
    func testTaxStudioSnapshotSurfacesPersistedVATReconciliationIssues() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppVATIssues.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        model.newWorkspaceName = "VAT Issue Workspace"
        model.createWorkspace()
        model.newSolePropName = "VAT Issue Business"
        model.createSoleProp()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        let storage = try XCTUnwrap(model.session?.storage)
        let businessEntity = try XCTUnwrap(model.entities.first { $0.displayName == "VAT Issue Business" })
        let businessAccount = try XCTUnwrap(
            try storage.financialAccountRepository.fetchFinancialAccounts(entityId: businessEntity.id).first
        )
        let period = VATPeriod(
            entityId: businessEntity.id,
            periodStart: try appTestDate("2026-04-01T00:00:00Z"),
            periodEnd: try appTestDate("2026-06-30T23:59:59Z"),
            currency: .chf
        )
        let transaction = Transaction(
            accountId: businessAccount.id,
            originKind: .manual,
            sourceLineRef: "vat-ui-missing-code",
            bookingDate: try appTestDate("2026-04-12T00:00:00Z"),
            amountMinor: 10_810,
            currency: .chf,
            counterpartyName: "Synthetic VAT Customer",
            memo: "Sale missing VAT code",
            taxCode: nil
        )
        try storage.vatPeriodRepository.saveVATPeriod(period)
        try storage.transactionRepository.saveTransactions([transaction])

        model.selectTaxEntity(businessEntity.id)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        let snapshot = model.taxStudioSnapshot
        let vatPeriod = try XCTUnwrap(snapshot.vatPeriods.first)
        XCTAssertEqual(vatPeriod.id, period.id)
        XCTAssertEqual(vatPeriod.statusText, "Blocked")
        XCTAssertEqual(vatPeriod.tone, .critical)
        XCTAssertEqual(vatPeriod.issueSummary, "1 blocker")
        XCTAssertEqual(vatPeriod.issues.first?.title, "Missing tax code")
        XCTAssertEqual(vatPeriod.issues.first?.statusText, "Blocking")
        XCTAssertTrue(snapshot.readinessSummary.contains("1 VAT issue"))
        XCTAssertTrue(snapshot.checklistItems.contains { $0.title == "Missing tax code" })

        model.selectTaxStudioSelection(vatPeriod.issues.first?.selection)

        let inspector = try XCTUnwrap(model.taxStudioSnapshot.inspector)
        let details = Dictionary(uniqueKeysWithValues: inspector.details.map { ($0.id, $0.value) })
        XCTAssertEqual(inspector.title, "Missing tax code")
        XCTAssertEqual(inspector.statusText, "Blocking")
        XCTAssertEqual(details["code"], "vat.missing_tax_code")
        XCTAssertEqual(details["source"], ObjectRef(kind: .transaction, id: transaction.id.rawValue).stringValue)
        XCTAssertEqual(inspector.evidence.first?.subtitle, ObjectRef(kind: .transaction, id: transaction.id.rawValue).stringValue)
    }

    @MainActor
    func testTaxStudioSnapshotSeparatesPreparedFilingPackagesFromFiledReturns() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppFilingPackageBoundary.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = try appTestDate("2026-03-19T12:00:00Z")
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        model.newWorkspaceName = "Filing Boundary Workspace"
        model.createWorkspace()
        model.newSolePropName = "Filing Boundary Business"
        model.createSoleProp()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        let storage = try XCTUnwrap(model.session?.storage)
        let businessEntity = try XCTUnwrap(model.entities.first { $0.displayName == "Filing Boundary Business" })
        let taxYear = try XCTUnwrap(try storage.taxYearRepository.fetchTaxYears(entityId: businessEntity.id).first)
        let generatedAt = try appTestDate("2026-04-15T10:00:00Z")
        let finalizedAt = try appTestDate("2026-04-16T11:30:00Z")
        let filingPackage = FilingPackage(
            entityId: businessEntity.id,
            taxYearId: taxYear.id,
            status: .finalized,
            generatedAt: generatedAt,
            finalizedAt: finalizedAt,
            finalizedBy: "reviewer",
            submittedAt: nil,
            snapshotHash: "sha256-review-snapshot",
            exportFormat: "eCH-0217",
            createdAt: generatedAt,
            updatedAt: finalizedAt
        )
        try storage.filingPackageRepository.saveFilingPackage(filingPackage)

        model.selectTaxEntity(businessEntity.id)

        let packageRow = try XCTUnwrap(model.taxStudioSnapshot.filingPackages.first)
        XCTAssertEqual(packageRow.id, filingPackage.id)
        XCTAssertEqual(packageRow.statusText, "Finalized, Not Filed")
        XCTAssertEqual(packageRow.tone, .warning)
        XCTAssertTrue(packageRow.subtitle.contains("not filed by AlpenLedger"))
        XCTAssertNotEqual(packageRow.generatedAtText, "n/a")
        XCTAssertTrue(packageRow.finalizationText.contains("reviewer"))
        XCTAssertEqual(packageRow.selection, .filingPackage(filingPackage.id))

        model.selectTaxStudioSelection(packageRow.selection)

        let inspector = try XCTUnwrap(model.taxStudioSnapshot.inspector)
        let details = Dictionary(uniqueKeysWithValues: inspector.details.map { ($0.id, $0.value) })
        XCTAssertEqual(inspector.title, "eCH-0217 package")
        XCTAssertEqual(inspector.statusText, "Finalized, Not Filed")
        XCTAssertEqual(details["boundary"], "Reviewer finalized this export; not filed by AlpenLedger.")
        XCTAssertEqual(details["submitted"], "n/a")
        XCTAssertEqual(details["snapshot"], "sha256-review-snapshot")
        XCTAssertEqual(
            inspector.evidence.first?.subtitle,
            ObjectRef(kind: .filingPackage, id: filingPackage.id.rawValue).stringValue
        )
    }

    @MainActor
    func testRecentWorkspaceReferenceReopensThroughWorkspaceAppModel() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let secretRootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppRecentWorkspace.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!

        let firstModel = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: WorkspaceService(
                    storageManager: WorkspaceStorageManager(
                        secretStore: FileSecretStore(directoryURL: secretRootURL),
                        workspacesRootURL: rootURL
                    ),
                    recentStore: RecentWorkspacesStore(defaults: defaults),
                    nowProvider: { fixedNow }
                ),
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        firstModel.newWorkspaceName = "Recent Workspace"
        firstModel.createWorkspace()

        XCTAssertFalse(firstModel.isShowingErrorAlert, firstModel.errorMessage ?? "")
        let recentReference = try XCTUnwrap(firstModel.recentWorkspaces.first)
        XCTAssertEqual(recentReference.name, "Recent Workspace")

        let reopenedModel = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: WorkspaceService(
                    storageManager: WorkspaceStorageManager(
                        secretStore: FileSecretStore(directoryURL: secretRootURL),
                        workspacesRootURL: rootURL
                    ),
                    recentStore: RecentWorkspacesStore(defaults: defaults),
                    nowProvider: { fixedNow }
                ),
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        XCTAssertEqual(reopenedModel.recentWorkspaces.first?.workspaceId, recentReference.workspaceId)

        reopenedModel.openWorkspace(recentReference)

        XCTAssertFalse(reopenedModel.isShowingErrorAlert, reopenedModel.errorMessage ?? "")
        XCTAssertEqual(reopenedModel.workspaceName, "Recent Workspace")
        XCTAssertTrue(reopenedModel.hasWorkspace)
        XCTAssertEqual(reopenedModel.selectedSection, .overview)
        XCTAssertFalse(reopenedModel.entities.isEmpty)
        XCTAssertFalse(reopenedModel.taxYears.isEmpty)
        XCTAssertFalse(reopenedModel.entityWorkspaces.isEmpty)
    }

    @MainActor
    func testCloseWorkspaceClearsSessionStateWithoutRemovingRecentReference() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let secretRootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppCloseWorkspace.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: WorkspaceService(
                    storageManager: WorkspaceStorageManager(
                        secretStore: FileSecretStore(directoryURL: secretRootURL),
                        workspacesRootURL: rootURL
                    ),
                    recentStore: RecentWorkspacesStore(defaults: defaults),
                    nowProvider: { fixedNow }
                ),
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        model.newWorkspaceName = "Close Workspace"
        model.createWorkspace()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        let recentReference = try XCTUnwrap(model.recentWorkspaces.first)
        let workspaceId = try XCTUnwrap(model.session?.storage.manifest.workspace.id)
        XCTAssertEqual(recentReference.workspaceId, workspaceId)
        XCTAssertTrue(model.hasWorkspace)
        XCTAssertTrue(model.canCloseCurrentWorkspace)
        XCTAssertFalse(model.entities.isEmpty)

        model.selectedSection = .documents
        model.globalSearchQuery = "sample"
        model.presentGlobalSearch()
        model.isShowingDocumentLinkSheet = true
        model.isShowingTransactionLinkSheet = true

        model.closeCurrentWorkspace()

        XCTAssertFalse(model.hasWorkspace)
        XCTAssertFalse(model.canCloseCurrentWorkspace)
        XCTAssertFalse(model.canUseGlobalSearch)
        XCTAssertNil(model.session)
        XCTAssertEqual(model.workspaceName, "AlpenLedger")
        XCTAssertEqual(model.selectedSection, .overview)
        XCTAssertTrue(model.entities.isEmpty)
        XCTAssertTrue(model.taxYears.isEmpty)
        XCTAssertTrue(model.financialAccounts.isEmpty)
        XCTAssertTrue(model.transactions.isEmpty)
        XCTAssertTrue(model.documents.isEmpty)
        XCTAssertTrue(model.archivedDocuments.isEmpty)
        XCTAssertNil(model.selectedAccountId)
        XCTAssertNil(model.selectedTransactionId)
        XCTAssertNil(model.selectedDocumentId)
        XCTAssertTrue(model.globalSearchQuery.isEmpty)
        XCTAssertTrue(model.globalSearchResults.isEmpty)
        XCTAssertFalse(model.isShowingGlobalSearch)
        XCTAssertFalse(model.isShowingDocumentLinkSheet)
        XCTAssertFalse(model.isShowingTransactionLinkSheet)
        XCTAssertEqual(model.recentWorkspaces.map(\.workspaceId), [workspaceId])
        XCTAssertEqual(model.workspaceChooserSnapshot.recentWorkspaces.first?.reference.workspaceId, workspaceId)
    }

    @MainActor
    func testOpeningWorkspaceRecoversInterruptedImportJobs() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppImportRecovery.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = try appTestDate("2026-05-30T09:30:00Z")
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let storage = try workspaceService.createWorkspace(named: "Import Recovery Workspace")
        let interruptedJob = ImportJob(
            workspaceId: storage.manifest.workspace.id,
            kind: .bankStatementCSV,
            source: "crashed-statement.csv",
            sourceBlobHash: "crashed-source",
            parserKey: "csv.bankstatement",
            parserVersion: "1.1.0",
            startedAt: fixedNow.addingTimeInterval(-600)
        )
        try storage.importJobRepository.saveImportJob(interruptedJob)

        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )
        let recentReference = try XCTUnwrap(model.recentWorkspaces.first)

        model.openWorkspace(recentReference)

        let recoveredJob = try XCTUnwrap(model.importJobs.first { $0.id == interruptedJob.id })
        let diagnostics = try XCTUnwrap(model.importDiagnosticsByJobId[interruptedJob.id])
        let reopenedStorage = try XCTUnwrap(model.session?.storage)
        let auditEvents = try reopenedStorage.auditEventRepository.fetchAuditEvents(
            workspaceId: storage.manifest.workspace.id,
            objectRef: ObjectRef(kind: .importJob, id: interruptedJob.id.rawValue)
        )

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(recoveredJob.status, .failed)
        XCTAssertEqual(recoveredJob.completedAt, fixedNow)
        XCTAssertEqual(recoveredJob.warningCount, 1)
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics.first?.severity, .error)
        XCTAssertEqual(diagnostics.first?.code, "import.interrupted")
        XCTAssertEqual(diagnostics.first?.createdAt, fixedNow)
        XCTAssertTrue(auditEvents.contains { $0.eventType == .importJobRecovered })
    }

    @MainActor
    func testInboxRetryImportActionReprocessesStoredStatementBlob() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppImportRetry.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = try appTestDate("2026-05-30T10:30:00Z")
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )
        model.newWorkspaceName = "Import Retry Workspace"
        model.createWorkspace()
        let session = try XCTUnwrap(model.session)
        let account = try XCTUnwrap(model.financialAccounts.first)
        model.selectAccount(account.id)
        let csvURL = try writeAppTestBankStatementCSV("""
        booking_date,value_date,amount,currency,counterparty,memo,reference,balance
        2026-01-15,2026-01-15,100.00,CHF,Retry Vendor,Payment,APP-RETRY-1,100.00
        """)
        let cancellationProbe = AppCancellationProbe(cancelOnCheck: 2)

        XCTAssertThrowsError(
            try session.importJobService.importStatement(
                from: csvURL,
                accountId: account.id,
                isCancellationRequested: cancellationProbe.shouldCancel
            )
        ) { error in
            XCTAssertTrue(error is ImportCancellationError)
        }

        let cancelledJob = try XCTUnwrap(
            try session.importJobService.listImportJobs().first { $0.status == .cancelled }
        )
        try fileManager.removeItem(at: csvURL)

        model.performInboxAction(.retryImport(cancelledJob.id))

        let completedJob = try XCTUnwrap(model.importJobs.first {
            $0.id != cancelledJob.id && $0.status == .completed
        })

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.transactions.count, 1)
        XCTAssertEqual(model.importJobs.count { $0.status == .cancelled }, 1)
        XCTAssertEqual(model.importJobs.count { $0.status == .completed }, 1)
        XCTAssertEqual(model.selectedSection, .inbox)
        XCTAssertEqual(model.selectedInboxSelection, .importJob(completedJob.id))
        XCTAssertEqual(model.inboxSnapshot.inspector?.statusText, "Completed")
    }

    @MainActor
    func testStatementImportDefaultRoutesImportsAndPersistsAcrossReopen() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppImportDefaults.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = try appTestDate("2026-05-30T11:30:00Z")
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let seededStorage = try workspaceService.createWorkspace(named: "Import Defaults Workspace")
        let entity = try XCTUnwrap(
            try seededStorage.legalEntityRepository
                .fetchLegalEntities(workspaceId: seededStorage.manifest.workspace.id)
                .first
        )
        let primaryAccount = try XCTUnwrap(
            try seededStorage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first
        )
        let secondaryAccount = FinancialAccount(
            entityId: entity.id,
            accountType: .bank,
            institutionName: "Secondary Bank",
            displayName: "Secondary Import Account",
            ledgerControlAccountId: primaryAccount.ledgerControlAccountId,
            openedAt: fixedNow
        )
        try seededStorage.financialAccountRepository.saveFinancialAccount(secondaryAccount)

        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )
        let recentReference = try XCTUnwrap(model.recentWorkspaces.first)

        model.openWorkspace(recentReference)
        model.selectAccount(primaryAccount.id)
        model.setDefaultStatementImportAccount(secondaryAccount.id)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.preferredStatementImportAccountId, secondaryAccount.id)
        XCTAssertEqual(model.settingsSnapshot.importDefaults.defaultAccountId, secondaryAccount.id)
        XCTAssertEqual(
            model.settingsSnapshot.importDefaults.status,
            "Statement imports default to Secondary Import Account."
        )
        XCTAssertTrue(model.settingsSnapshot.importDefaults.accounts.contains { $0.id == secondaryAccount.id })

        model.importSampleCSV()

        let openedStorage = try XCTUnwrap(model.session?.storage)
        let primaryTransactions = try openedStorage.transactionRepository.fetchTransactions(accountId: primaryAccount.id)
        let secondaryTransactions = try openedStorage.transactionRepository.fetchTransactions(accountId: secondaryAccount.id)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertTrue(primaryTransactions.isEmpty)
        XCTAssertEqual(secondaryTransactions.count, 3)
        XCTAssertEqual(model.selectedAccountId, primaryAccount.id)

        let reopenedModel = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )
        reopenedModel.openWorkspace(recentReference)

        XCTAssertEqual(reopenedModel.settingsSnapshot.importDefaults.defaultAccountId, secondaryAccount.id)
        XCTAssertEqual(reopenedModel.preferredStatementImportAccountId, secondaryAccount.id)
    }

    @MainActor
    func testBackupActionsCreateAndRestoreThroughWorkspaceAppModel() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let backupParentURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let requestedBackupURL = backupParentURL.appendingPathComponent("workspace-backup", isDirectory: true)
        let expectedBackupURL = requestedBackupURL.appendingPathExtension("alpenledgerbackup")
        let defaultsSuiteName = "AppBackupActions.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let secretStore = InMemorySecretStore()
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: secretStore,
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: {
                ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
            }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: {
                    ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
                }
            )
        )

        model.newWorkspaceName = "Backup Action Workspace"
        model.createWorkspace()
        let originalStorage = try XCTUnwrap(model.session?.storage)

        model.createBackup(at: requestedBackupURL)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBackupURL.appendingPathComponent("backup.json").path))
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBackupURL.appendingPathComponent("workspace.key").path))
        XCTAssertEqual(model.selectedSection, .settings)
        XCTAssertEqual(
            model.settingsSnapshot.backup.lastAction,
            "Created workspace-backup.alpenledgerbackup for Backup Action Workspace."
        )
        let createdIntegrity = try XCTUnwrap(model.settingsSnapshot.backup.integrity)
        XCTAssertEqual(createdIntegrity.title, "Backup can be restored")
        XCTAssertEqual(createdIntegrity.tone, .success)
        XCTAssertTrue(createdIntegrity.issues.isEmpty)

        try secretStore.deleteWorkspaceMasterKey(workspaceId: originalStorage.manifest.workspace.id)
        model.restoreBackup(from: expectedBackupURL)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertNotEqual(model.session?.storage.paths.rootURL, originalStorage.paths.rootURL)
        XCTAssertEqual(model.workspaceName, "Backup Action Workspace")
        XCTAssertEqual(model.selectedSection, .settings)
        XCTAssertEqual(
            model.settingsSnapshot.backup.lastAction,
            "Restored Backup Action Workspace from workspace-backup.alpenledgerbackup."
        )
    }

    @MainActor
    func testBackupPanelActionsUseConfiguredSelectionsThroughWorkspaceAppModel() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let backupParentURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let requestedBackupURL = backupParentURL.appendingPathComponent("panel-backup", isDirectory: true)
        let expectedBackupURL = requestedBackupURL.appendingPathExtension("alpenledgerbackup")
        let defaultsSuiteName = "AppBackupPanelActions.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let secretStore = InMemorySecretStore()
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: secretStore,
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: {
                ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
            }
        )
        let backupPanelClient = BackupPanelClient(
            createBackupDestination: { _ in requestedBackupURL },
            backupValidationSource: { expectedBackupURL },
            backupRestoreSource: { expectedBackupURL }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: {
                    ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
                },
                backupPanelClient: backupPanelClient
            )
        )

        model.newWorkspaceName = "Backup Panel Action Workspace"
        model.createWorkspace()
        model.createBackupFromPanel()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertTrue(fileManager.fileExists(atPath: expectedBackupURL.appendingPathComponent("backup.json").path))
        XCTAssertEqual(model.settingsSnapshot.backup.lastAction, "Created panel-backup.alpenledgerbackup for Backup Panel Action Workspace.")
        XCTAssertEqual(model.settingsSnapshot.backup.integrity?.title, "Backup can be restored")

        model.renameWorkspace(to: "Renamed After Panel Backup")
        XCTAssertEqual(model.workspaceName, "Renamed After Panel Backup")

        model.validateBackupFromPanel()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.settingsSnapshot.backup.lastAction, "Checked panel-backup.alpenledgerbackup.")
        XCTAssertTrue(model.settingsSnapshot.backup.integrity?.issues.isEmpty == true)

        model.restoreBackupFromPanel()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.workspaceName, "Backup Panel Action Workspace")
        XCTAssertEqual(model.settingsSnapshot.backup.lastAction, "Restored Backup Panel Action Workspace from panel-backup.alpenledgerbackup.")
        XCTAssertEqual(model.selectedSection, .settings)
    }

    @MainActor
    func testWorkspaceDeleteActionRequiresConfirmationAndClearsModelState() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppWorkspaceDeletion.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let secretStore = InMemorySecretStore()
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: secretStore,
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: {
                ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
            }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: {
                    ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
                }
            )
        )

        model.newWorkspaceName = "Delete Action Workspace"
        model.createWorkspace()
        let storage = try XCTUnwrap(model.session?.storage)
        let workspaceURL = storage.paths.rootURL
        let workspaceId = storage.manifest.workspace.id

        XCTAssertTrue(model.settingsSnapshot.dataReset.canDeleteWorkspace)

        model.deleteCurrentWorkspace(confirmingName: "Wrong Workspace")

        XCTAssertTrue(model.isShowingErrorAlert)
        XCTAssertEqual(model.errorTitle, "Workspace deletion not confirmed")
        XCTAssertNotNil(model.session)
        XCTAssertTrue(fileManager.fileExists(atPath: workspaceURL.path))
        XCTAssertEqual(model.recentWorkspaces.map(\.workspaceId), [workspaceId])

        model.dismissErrorAlert()
        model.deleteCurrentWorkspace(confirmingName: "Delete Action Workspace")

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertNil(model.session)
        XCTAssertEqual(model.workspaceName, "AlpenLedger")
        XCTAssertEqual(model.selectedSection, .overview)
        XCTAssertFalse(model.settingsSnapshot.dataReset.canDeleteWorkspace)
        XCTAssertTrue(model.recentWorkspaces.isEmpty)
        XCTAssertFalse(fileManager.fileExists(atPath: workspaceURL.path))
        XCTAssertThrowsError(try secretStore.loadWorkspaceMasterKey(workspaceId: workspaceId)) { error in
            XCTAssertEqual(error as? DomainError, .missingWorkspaceKey)
        }
    }

    @MainActor
    func testSettingsSnapshotShowsWorkspaceDatabaseHealth() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppDatabaseHealth.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults)
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults)
            )
        )

        model.newWorkspaceName = "Database Health Workspace"
        model.createWorkspace()

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.settingsSnapshot.dataHealth.title, "Workspace data checks passed")
        XCTAssertEqual(model.settingsSnapshot.dataHealth.tone, .success)
        XCTAssertTrue(
            model.settingsSnapshot.dataHealth.detail.contains(
                "\(AlpenLedgerDatabaseMigrations.identifiers.count)/\(AlpenLedgerDatabaseMigrations.identifiers.count) migrations"
            )
        )
        XCTAssertTrue(model.settingsSnapshot.dataHealth.detail.contains("foreign keys on"))
        XCTAssertTrue(model.settingsSnapshot.dataHealth.issues.isEmpty)
    }

    @MainActor
    func testGlobalSearchFindsAndNavigatesWorkspaceRecords() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaultsSuiteName = "AppGlobalSearch.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = try appTestDate("2026-04-22T12:00:00Z")
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        model.newWorkspaceName = "Global Search App Workspace"
        model.createWorkspace()

        let storage = try XCTUnwrap(model.session?.storage)
        let entity = try XCTUnwrap(
            try storage.legalEntityRepository
                .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
                .first
        )
        let taxYear = try XCTUnwrap(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
        let account = try XCTUnwrap(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
        let document = Document(
            workspaceId: storage.manifest.workspace.id,
            blobHash: "app-global-search-document-blob",
            originalFilename: "salary-certificate-global-app.pdf",
            mediaType: "application/pdf",
            documentType: .salaryCertificate,
            issueDate: fixedNow,
            detectedEntityId: entity.id,
            entityId: entity.id,
            extractedText: "alphapine salary certificate for app search readiness",
            metadataStatus: .confirmed
        )
        try storage.documentRepository.saveDocument(document)

        let transaction = Transaction(
            accountId: account.id,
            sourceLineRef: "app-global-search-row-1",
            bookingDate: fixedNow,
            amountMinor: -4_560,
            currency: .chf,
            counterpartyName: "Globex Search AG",
            memo: "ergomonitor subscription stand",
            reference: "GS-APP-2026",
            taxCode: "CH-VAT-INPUT-STD"
        )
        try storage.transactionRepository.saveTransactions([transaction])
        let savedTransaction = try XCTUnwrap(try storage.transactionRepository.fetchTransactions(ids: [transaction.id]).first)
        let counterpartyId = try XCTUnwrap(savedTransaction.counterpartyId)

        let issue = Issue(
            fingerprint: "app-global-search-missing-ergomonitor-receipt",
            workspaceId: storage.manifest.workspace.id,
            entityId: entity.id,
            taxYearId: taxYear.id,
            issueCode: .missingExpenseEvidence,
            severity: .warning,
            status: .open,
            summary: "Missing receipt for ergomonitor stand",
            objectRef: ObjectRef(kind: .transaction, id: savedTransaction.id.rawValue),
            firstDetectedAt: fixedNow,
            lastDetectedAt: fixedNow
        )
        try storage.issueRepository.saveIssue(issue)

        model.openWorkspace(try XCTUnwrap(model.recentWorkspaces.first))
        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")

        model.globalSearchQuery = "alphapine"
        model.refreshGlobalSearchResults()

        let documentHit = try XCTUnwrap(
            model.globalSearchResults.first {
                $0.objectRef == ObjectRef(kind: .document, id: document.id.rawValue)
            }
        )
        XCTAssertEqual(documentHit.title, "salary-certificate-global-app.pdf")

        model.openGlobalSearchHit(documentHit)
        XCTAssertEqual(model.selectedSection, .documents)
        XCTAssertEqual(model.selectedDocumentId, document.id)

        model.globalSearchQuery = "ergomonitor"
        model.refreshGlobalSearchResults()
        XCTAssertTrue(
            model.globalSearchResults.contains {
                $0.objectRef == ObjectRef(kind: .issue, id: issue.id.rawValue)
            }
        )
        let transactionHit = try XCTUnwrap(
            model.globalSearchResults.first {
                $0.objectRef == ObjectRef(kind: .transaction, id: savedTransaction.id.rawValue)
            }
        )

        model.openGlobalSearchHit(transactionHit)
        XCTAssertEqual(model.selectedSection, .ledger)
        XCTAssertEqual(model.selectedTransactionId, savedTransaction.id)

        model.globalSearchQuery = "Globex"
        model.refreshGlobalSearchResults()
        let counterpartyHit = try XCTUnwrap(
            model.globalSearchResults.first {
                $0.objectRef == ObjectRef(kind: .counterparty, id: counterpartyId.rawValue)
            }
        )

        model.openGlobalSearchHit(counterpartyHit)
        XCTAssertEqual(model.selectedSection, .ledger)
        XCTAssertEqual(model.selectedTransactionId, savedTransaction.id)

        model.clearGlobalSearch()
        XCTAssertTrue(model.globalSearchQuery.isEmpty)
        XCTAssertTrue(model.globalSearchResults.isEmpty)
    }

    @MainActor
    func testDocumentArchiveAndRestoreActionsSwitchReviewViews() throws {
        let fileManager = FileManager.default
        let tempRootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspacesRootURL = tempRootURL.appendingPathComponent("workspaces", isDirectory: true)
        let secretRootURL = tempRootURL.appendingPathComponent("secrets", isDirectory: true)
        let runtime = AppRuntimeConfiguration.fromEnvironment([
            "ALPENLEDGER_WORKSPACES_ROOT": workspacesRootURL.path,
            "ALPENLEDGER_SECRET_STORE_ROOT": secretRootURL.path,
            "ALPENLEDGER_DEFAULTS_SUITE": "AppDocumentArchive.\(UUID().uuidString)",
            "ALPENLEDGER_FIXED_NOW": "2026-05-30T08:00:00Z",
        ])
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: runtime.makeWorkspaceService(),
                uiPreferencesStore: runtime.makeUIPreferencesStore(),
                nowProvider: runtime.nowProvider,
                privacyMode: runtime.privacyMode
            )
        )

        model.newWorkspaceName = "Document Archive Workspace"
        model.createWorkspace()
        model.importSampleData()

        let document = try XCTUnwrap(model.documents.first)
        model.selectedSection = .documents
        model.selectDocument(document.id)

        XCTAssertTrue(model.canArchiveSelectedDocument)
        XCTAssertFalse(model.canRestoreSelectedDocument)
        XCTAssertTrue(model.canLinkSelectedTransaction)

        model.archiveSelectedDocument(reason: "Duplicate scan from app review.")

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.documents.map(\.id), [])
        XCTAssertEqual(model.archivedDocuments.map(\.id), [document.id])
        XCTAssertEqual(model.documentVaultCount, 1)
        XCTAssertEqual(model.documentCount, 0)
        XCTAssertEqual(model.documentFilterScope, .archived)
        XCTAssertEqual(model.selectedDocumentId, document.id)
        XCTAssertEqual(model.documentBrowserItems.first?.statusText, "Archived")
        XCTAssertTrue(model.documentBrowserItems.first?.isArchived == true)
        XCTAssertFalse(model.canArchiveSelectedDocument)
        XCTAssertTrue(model.canRestoreSelectedDocument)
        XCTAssertFalse(model.canLinkSelectedTransaction)

        model.restoreSelectedDocument(reason: "Reviewer confirmed this is the retained source.")

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertEqual(model.documents.map(\.id), [document.id])
        XCTAssertEqual(model.archivedDocuments.map(\.id), [])
        XCTAssertEqual(model.documentCount, 1)
        XCTAssertEqual(model.documentFilterScope, .all)
        XCTAssertEqual(model.selectedDocumentId, document.id)
        XCTAssertEqual(model.documentBrowserItems.first?.statusText, "Proposed")
        XCTAssertTrue(model.canArchiveSelectedDocument)
        XCTAssertFalse(model.canRestoreSelectedDocument)
        XCTAssertTrue(model.canLinkSelectedTransaction)
    }

    @MainActor
    func testDocumentMetadataReviewUpdatesVaultAndAuditTrail() throws {
        let fileManager = FileManager.default
        let tempRootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspacesRootURL = tempRootURL.appendingPathComponent("workspaces", isDirectory: true)
        let secretRootURL = tempRootURL.appendingPathComponent("secrets", isDirectory: true)
        let runtime = AppRuntimeConfiguration.fromEnvironment([
            "ALPENLEDGER_WORKSPACES_ROOT": workspacesRootURL.path,
            "ALPENLEDGER_SECRET_STORE_ROOT": secretRootURL.path,
            "ALPENLEDGER_DEFAULTS_SUITE": "AppDocumentMetadata.\(UUID().uuidString)",
            "ALPENLEDGER_FIXED_NOW": "2026-05-30T08:00:00Z",
        ])
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: runtime.makeWorkspaceService(),
                uiPreferencesStore: runtime.makeUIPreferencesStore(),
                nowProvider: runtime.nowProvider,
                privacyMode: runtime.privacyMode
            )
        )

        model.newWorkspaceName = "Document Metadata Workspace"
        model.createWorkspace()
        model.importSampleData()

        let document = try XCTUnwrap(model.documents.first)
        let reviewDate = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-02-14T00:00:00Z"))
        model.selectedSection = .documents
        model.selectDocument(document.id)
        model.reviewDocumentMetadata(
            documentId: document.id,
            documentType: .salaryCertificate,
            issueDate: reviewDate
        )

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        let reviewedDocument = try XCTUnwrap(model.documents.first(where: { $0.id == document.id }))
        XCTAssertEqual(reviewedDocument.documentType, .salaryCertificate)
        XCTAssertEqual(reviewedDocument.issueDate, reviewDate)
        XCTAssertEqual(reviewedDocument.metadataStatus, .confirmed)
        XCTAssertEqual(model.selectedDocumentId, document.id)
        XCTAssertEqual(model.documentBrowserItems.first?.typeLabel, "Salary Certificate")
        XCTAssertEqual(model.documentBrowserItems.first?.statusText, "Confirmed")

        let storage = try XCTUnwrap(model.session?.storage)
        let auditEvents = try storage.auditEventRepository.fetchAuditEvents(
            workspaceId: storage.manifest.workspace.id,
            objectRef: ObjectRef(kind: .document, id: document.id.rawValue)
        )
        XCTAssertTrue(auditEvents.contains { $0.eventType == .documentMetadataReviewed })
    }

    @MainActor
    func testExportDiagnosticsThroughWorkspaceAppModel() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let exportParentURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let requestedExportURL = exportParentURL.appendingPathComponent("support-diagnostics")
        let expectedExportURL = requestedExportURL.appendingPathExtension("json")
        let defaultsSuiteName = "AppSupportDiagnostics.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        model.newWorkspaceName = "Support Diagnostics Workspace"
        model.createWorkspace()
        model.exportDiagnostics(to: requestedExportURL)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertTrue(fileManager.fileExists(atPath: expectedExportURL.path))
        XCTAssertEqual(model.selectedSection, .settings)
        XCTAssertEqual(model.settingsSnapshot.support.lastAction, "Exported support-diagnostics.json.")
        XCTAssertEqual(model.settingsSnapshot.support.diagnostics?.title, "Diagnostics exported")
        XCTAssertEqual(model.settingsSnapshot.support.diagnostics?.tone, .success)
        XCTAssertTrue(model.settingsSnapshot.support.diagnostics?.detail.contains("tables") == true)

        let report = try JSONDecoder.alpenLedger.decode(
            WorkspaceSupportDiagnosticsReport.self,
            from: Data(contentsOf: expectedExportURL)
        )
        XCTAssertEqual(report.generatedAt, fixedNow)
        XCTAssertTrue(report.databaseHealth.isHealthy)
        XCTAssertFalse(report.privacy.includesWorkspaceName)
        XCTAssertFalse(report.privacy.includesDocumentContents)
    }

    @MainActor
    func testExportSupportBundleThroughWorkspaceAppModel() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let exportParentURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let requestedExportURL = exportParentURL.appendingPathComponent("support-bundle")
        let expectedExportURL = requestedExportURL.appendingPathExtension("json")
        let defaultsSuiteName = "AppSupportBundle.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let fixedNow = ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: { fixedNow }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: { fixedNow }
            )
        )

        model.newWorkspaceName = "Support Bundle Workspace"
        model.createWorkspace()
        model.exportSupportBundle(to: requestedExportURL)

        XCTAssertFalse(model.isShowingErrorAlert, model.errorMessage ?? "")
        XCTAssertTrue(fileManager.fileExists(atPath: expectedExportURL.path))
        XCTAssertEqual(model.selectedSection, .settings)
        XCTAssertEqual(model.settingsSnapshot.support.lastAction, "Exported support-bundle.json.")
        XCTAssertEqual(model.settingsSnapshot.support.supportBundle?.title, "Support bundle exported")
        XCTAssertEqual(model.settingsSnapshot.support.supportBundle?.tone, .success)
        XCTAssertTrue(model.settingsSnapshot.support.supportBundle?.detail.contains("audit events") == true)

        let bundle = try JSONDecoder.alpenLedger.decode(
            WorkspaceSupportBundle.self,
            from: Data(contentsOf: expectedExportURL)
        )
        XCTAssertEqual(bundle.generatedAt, fixedNow)
        XCTAssertTrue(bundle.diagnostics.databaseHealth.isHealthy)
        XCTAssertGreaterThanOrEqual(bundle.auditLog.totalEventCount, 1)
        XCTAssertFalse(bundle.privacy.includesRawAuditPayloads)
        XCTAssertFalse(bundle.privacy.includesWorkspaceName)
    }

    @MainActor
    func testRestoreBackupRejectsTamperedBundleThroughWorkspaceAppModel() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let backupParentURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let requestedBackupURL = backupParentURL.appendingPathComponent("workspace-backup", isDirectory: true)
        let expectedBackupURL = requestedBackupURL.appendingPathExtension("alpenledgerbackup")
        let defaultsSuiteName = "AppBackupTamper.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuiteName))
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        let workspaceService = WorkspaceService(
            storageManager: WorkspaceStorageManager(
                secretStore: InMemorySecretStore(),
                workspacesRootURL: rootURL
            ),
            recentStore: RecentWorkspacesStore(defaults: defaults),
            nowProvider: {
                ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
            }
        )
        let model = WorkspaceAppModel(
            container: DependencyContainer(
                workspaceService: workspaceService,
                uiPreferencesStore: WorkspaceUIPreferencesStore(defaults: defaults),
                nowProvider: {
                    ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z")!
                }
            )
        )

        model.newWorkspaceName = "Tamper Action Workspace"
        model.createWorkspace()
        model.createBackup(at: requestedBackupURL)
        try Data("tampered key material".utf8)
            .write(to: expectedBackupURL.appendingPathComponent("workspace.key"), options: .atomic)

        model.restoreBackup(from: expectedBackupURL)

        XCTAssertTrue(model.isShowingErrorAlert)
        XCTAssertEqual(model.errorMessage, DomainError.invalidWorkspaceBackup.localizedDescription)
        XCTAssertEqual(model.workspaceName, "Tamper Action Workspace")
        XCTAssertEqual(model.selectedSection, .settings)

        let integrity = try XCTUnwrap(model.settingsSnapshot.backup.integrity)
        XCTAssertEqual(integrity.title, "Backup blocked")
        XCTAssertEqual(integrity.tone, .critical)
        XCTAssertEqual(integrity.issues.first?.title, "Blocker")
        XCTAssertTrue(integrity.issues.first?.detail.contains("workspace.key") == true)
    }
}

private func appTestDate(_ rawValue: String) throws -> Date {
    try XCTUnwrap(ISO8601DateFormatter().date(from: rawValue))
}

private func writeAppTestBankStatementCSV(_ content: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("csv")
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private final class AppCancellationProbe: @unchecked Sendable {
    private let cancelOnCheck: Int
    private var checkCount = 0

    init(cancelOnCheck: Int) {
        self.cancelOnCheck = cancelOnCheck
    }

    func shouldCancel() -> Bool {
        checkCount += 1
        return checkCount >= cancelOnCheck
    }
}

private let appTestCloudProvider = ModelProviderDescriptor(
    id: "cloud.reasoning",
    displayName: "Cloud reasoning provider",
    role: .cloudReasoning,
    location: .externalNetwork,
    capabilities: [
        .chatReasoning,
        .taxExplanation,
        .reconciliationExplanation,
    ],
    requiresNetworkAccess: true,
    sendsDataOffDevice: true,
    requiresExplicitConsent: true
)
