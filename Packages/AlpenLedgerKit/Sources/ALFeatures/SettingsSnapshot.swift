import Foundation
import ALDomain

public struct SettingsSnapshot: Sendable {
    public struct WorkspaceDetails: Sendable {
        public let name: String
        public let type: String
        public let location: String
        public let encryptionStatus: String
        public let createdAt: String

        public init(name: String, type: String, location: String, encryptionStatus: String, createdAt: String) {
            self.name = name
            self.type = type
            self.location = location
            self.encryptionStatus = encryptionStatus
            self.createdAt = createdAt
        }
    }

    public struct WorkspaceLockDetails: Sendable {
        public let isEnabled: Bool
        public let status: String
        public let detail: String
        public let canToggle: Bool
        public let canLockNow: Bool

        public init(
            isEnabled: Bool,
            status: String,
            detail: String,
            canToggle: Bool,
            canLockNow: Bool
        ) {
            self.isEnabled = isEnabled
            self.status = status
            self.detail = detail
            self.canToggle = canToggle
            self.canLockNow = canLockNow
        }
    }

    public struct BackupDetails: Sendable {
        public enum IntegrityTone: String, Hashable, Sendable {
            case neutral
            case success
            case warning
            case critical
        }

        public struct IntegrityIssueRow: Identifiable, Sendable {
            public let id: String
            public let title: String
            public let detail: String
            public let tone: IntegrityTone

            public init(id: String, title: String, detail: String, tone: IntegrityTone) {
                self.id = id
                self.title = title
                self.detail = detail
                self.tone = tone
            }
        }

        public struct IntegritySummary: Sendable {
            public let title: String
            public let detail: String
            public let tone: IntegrityTone
            public let issues: [IntegrityIssueRow]

            public init(title: String, detail: String, tone: IntegrityTone, issues: [IntegrityIssueRow]) {
                self.title = title
                self.detail = detail
                self.tone = tone
                self.issues = issues
            }
        }

        public let warning: String
        public let lastAction: String?
        public let canCreateBackup: Bool
        public let canValidateBackup: Bool
        public let canRestoreBackup: Bool
        public let integrity: IntegritySummary?

        public init(
            warning: String,
            lastAction: String?,
            canCreateBackup: Bool,
            canValidateBackup: Bool,
            canRestoreBackup: Bool,
            integrity: IntegritySummary?
        ) {
            self.warning = warning
            self.lastAction = lastAction
            self.canCreateBackup = canCreateBackup
            self.canValidateBackup = canValidateBackup
            self.canRestoreBackup = canRestoreBackup
            self.integrity = integrity
        }
    }

    public struct DataHealthDetails: Sendable {
        public struct IssueRow: Identifiable, Sendable {
            public let id: String
            public let title: String
            public let detail: String
            public let tone: BackupDetails.IntegrityTone

            public init(id: String, title: String, detail: String, tone: BackupDetails.IntegrityTone) {
                self.id = id
                self.title = title
                self.detail = detail
                self.tone = tone
            }
        }

        public let title: String
        public let detail: String
        public let tone: BackupDetails.IntegrityTone
        public let issues: [IssueRow]

        public init(title: String, detail: String, tone: BackupDetails.IntegrityTone, issues: [IssueRow]) {
            self.title = title
            self.detail = detail
            self.tone = tone
            self.issues = issues
        }
    }

    public struct ImportDefaultsDetails: Sendable {
        public struct AccountRow: Identifiable, Sendable {
            public let id: FinancialAccountID
            public let title: String
            public let detail: String

            public init(id: FinancialAccountID, title: String, detail: String) {
                self.id = id
                self.title = title
                self.detail = detail
            }
        }

        public let explanation: String
        public let defaultAccountId: FinancialAccountID?
        public let status: String
        public let accounts: [AccountRow]
        public let canChooseDefault: Bool

        public init(
            explanation: String,
            defaultAccountId: FinancialAccountID?,
            status: String,
            accounts: [AccountRow],
            canChooseDefault: Bool
        ) {
            self.explanation = explanation
            self.defaultAccountId = defaultAccountId
            self.status = status
            self.accounts = accounts
            self.canChooseDefault = canChooseDefault
        }
    }

    public struct DataResetDetails: Sendable {
        public let warning: String
        public let canDeleteWorkspace: Bool

        public init(warning: String, canDeleteWorkspace: Bool) {
            self.warning = warning
            self.canDeleteWorkspace = canDeleteWorkspace
        }
    }

    public struct SupportDetails: Sendable {
        public struct ExportSummary: Sendable {
            public let title: String
            public let detail: String
            public let tone: BackupDetails.IntegrityTone

            public init(title: String, detail: String, tone: BackupDetails.IntegrityTone) {
                self.title = title
                self.detail = detail
                self.tone = tone
            }
        }

        public let explanation: String
        public let lastAction: String?
        public let canExportDiagnostics: Bool
        public let canExportSupportBundle: Bool
        public let diagnostics: ExportSummary?
        public let supportBundle: ExportSummary?

        public init(
            explanation: String,
            lastAction: String?,
            canExportDiagnostics: Bool,
            canExportSupportBundle: Bool,
            diagnostics: ExportSummary?,
            supportBundle: ExportSummary?
        ) {
            self.explanation = explanation
            self.lastAction = lastAction
            self.canExportDiagnostics = canExportDiagnostics
            self.canExportSupportBundle = canExportSupportBundle
            self.diagnostics = diagnostics
            self.supportBundle = supportBundle
        }
    }

    public struct AIPrivacyDetails: Sendable {
        public struct ProviderRow: Identifiable, Sendable {
            public let id: String
            public let name: String
            public let role: String
            public let capabilities: String
            public let status: String
            public let tone: BackupDetails.IntegrityTone

            public init(
                id: String,
                name: String,
                role: String,
                capabilities: String,
                status: String,
                tone: BackupDetails.IntegrityTone
            ) {
                self.id = id
                self.name = name
                self.role = role
                self.capabilities = capabilities
                self.status = status
                self.tone = tone
            }
        }

        public struct ControlRow: Identifiable, Sendable {
            public let id: String
            public let title: String
            public let value: String
            public let detail: String
            public let tone: BackupDetails.IntegrityTone

            public init(
                id: String,
                title: String,
                value: String,
                detail: String,
                tone: BackupDetails.IntegrityTone
            ) {
                self.id = id
                self.title = title
                self.value = value
                self.detail = detail
                self.tone = tone
            }
        }

        public struct ActivityDetails: Sendable {
            public let title: String
            public let detail: String
            public let networkStatus: String
            public let offDeviceStatus: String
            public let tone: BackupDetails.IntegrityTone

            public init(
                title: String,
                detail: String,
                networkStatus: String,
                offDeviceStatus: String,
                tone: BackupDetails.IntegrityTone
            ) {
                self.title = title
                self.detail = detail
                self.networkStatus = networkStatus
                self.offDeviceStatus = offDeviceStatus
                self.tone = tone
            }
        }

        public let modeTitle: String
        public let modeDetail: String
        public let networkStatus: String
        public let cloudStatus: String
        public let activity: ActivityDetails
        public let controls: [ControlRow]
        public let providers: [ProviderRow]

        public init(
            modeTitle: String,
            modeDetail: String,
            networkStatus: String,
            cloudStatus: String,
            activity: ActivityDetails,
            controls: [ControlRow],
            providers: [ProviderRow]
        ) {
            self.modeTitle = modeTitle
            self.modeDetail = modeDetail
            self.networkStatus = networkStatus
            self.cloudStatus = cloudStatus
            self.activity = activity
            self.controls = controls
            self.providers = providers
        }
    }

    public let workspace: WorkspaceDetails
    public let workspaceLock: WorkspaceLockDetails
    public let aiPrivacy: AIPrivacyDetails
    public let backup: BackupDetails
    public let importDefaults: ImportDefaultsDetails
    public let dataHealth: DataHealthDetails
    public let dataReset: DataResetDetails
    public let support: SupportDetails
    public let entities: [EntityRowModel]

    public init(
        workspace: WorkspaceDetails,
        workspaceLock: WorkspaceLockDetails,
        aiPrivacy: AIPrivacyDetails,
        backup: BackupDetails,
        importDefaults: ImportDefaultsDetails,
        dataHealth: DataHealthDetails,
        dataReset: DataResetDetails,
        support: SupportDetails,
        entities: [EntityRowModel]
    ) {
        self.workspace = workspace
        self.workspaceLock = workspaceLock
        self.aiPrivacy = aiPrivacy
        self.backup = backup
        self.importDefaults = importDefaults
        self.dataHealth = dataHealth
        self.dataReset = dataReset
        self.support = support
        self.entities = entities
    }
}

public struct EntityRowModel: Identifiable, Sendable {
    public let id: LegalEntityID
    public let name: String
    public let kindLabel: String
    public let detail: String
    public let canRemove: Bool
    public let removalHint: String?

    public init(
        id: LegalEntityID,
        name: String,
        kindLabel: String,
        detail: String,
        canRemove: Bool,
        removalHint: String?
    ) {
        self.id = id
        self.name = name
        self.kindLabel = kindLabel
        self.detail = detail
        self.canRemove = canRemove
        self.removalHint = removalHint
    }
}
