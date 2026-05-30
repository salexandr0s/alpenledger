import SwiftUI
import ALDomain
import ALDesignSystem

public struct SettingsFeatureView: View {
    @Binding private var newSolePropName: String
    @State private var workspaceDraftName = ""

    private let snapshot: SettingsSnapshot
    private let onRenameWorkspace: (String) -> Void
    private let onSetWorkspaceLockEnabled: (Bool) -> Void
    private let onLockWorkspace: () -> Void
    private let onCreateBackup: () -> Void
    private let onValidateBackup: () -> Void
    private let onRestoreBackup: () -> Void
    private let onSetDefaultImportAccount: (FinancialAccountID?) -> Void
    private let onShowHelp: () -> Void
    private let onExportDiagnostics: () -> Void
    private let onExportSupportBundle: () -> Void
    private let onDeleteWorkspace: () -> Void
    private let onRenameEntity: (LegalEntityID, String) -> Void
    private let onRemoveEntity: (LegalEntityID) -> Void
    private let onCreateSoleProp: () -> Void

    public init(
        snapshot: SettingsSnapshot,
        newSolePropName: Binding<String>,
        onRenameWorkspace: @escaping (String) -> Void,
        onSetWorkspaceLockEnabled: @escaping (Bool) -> Void,
        onLockWorkspace: @escaping () -> Void,
        onCreateBackup: @escaping () -> Void,
        onValidateBackup: @escaping () -> Void,
        onRestoreBackup: @escaping () -> Void,
        onSetDefaultImportAccount: @escaping (FinancialAccountID?) -> Void,
        onShowHelp: @escaping () -> Void,
        onExportDiagnostics: @escaping () -> Void,
        onExportSupportBundle: @escaping () -> Void,
        onDeleteWorkspace: @escaping () -> Void,
        onRenameEntity: @escaping (LegalEntityID, String) -> Void,
        onRemoveEntity: @escaping (LegalEntityID) -> Void,
        onCreateSoleProp: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        _newSolePropName = newSolePropName
        self.onRenameWorkspace = onRenameWorkspace
        self.onSetWorkspaceLockEnabled = onSetWorkspaceLockEnabled
        self.onLockWorkspace = onLockWorkspace
        self.onCreateBackup = onCreateBackup
        self.onValidateBackup = onValidateBackup
        self.onRestoreBackup = onRestoreBackup
        self.onSetDefaultImportAccount = onSetDefaultImportAccount
        self.onShowHelp = onShowHelp
        self.onExportDiagnostics = onExportDiagnostics
        self.onExportSupportBundle = onExportSupportBundle
        self.onDeleteWorkspace = onDeleteWorkspace
        self.onRenameEntity = onRenameEntity
        self.onRemoveEntity = onRemoveEntity
        self.onCreateSoleProp = onCreateSoleProp
    }

    public var body: some View {
        Form {
            workspaceSection
            workspaceLockSection
            aiPrivacySection
            backupSection
            importDefaultsSection
            dataHealthSection
            helpSection
            supportSection
            dataResetSection
            entitiesSection
            addEntitySection
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .navigationSubtitle("Workspace and entity configuration")
        .onAppear {
            workspaceDraftName = snapshot.workspace.name
        }
        .onChange(of: snapshot.workspace.name) { _, newValue in
            workspaceDraftName = newValue
        }
    }

    private var workspaceSection: some View {
        Section("Workspace") {
            HStack(spacing: AppTheme.spacingS) {
                TextField("Workspace name", text: $workspaceDraftName)
                    .onSubmit {
                        let trimmed = workspaceDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            onRenameWorkspace(workspaceDraftName)
                        }
                    }
                    .accessibilityIdentifier("settings.workspaceNameField")

                Button("Save") {
                    onRenameWorkspace(workspaceDraftName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(workspaceDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("settings.renameWorkspaceButton")
            }

            LabeledContent("Type", value: snapshot.workspace.type)
            LabeledContent("Location", value: snapshot.workspace.location)
            LabeledContent("Encryption", value: snapshot.workspace.encryptionStatus)
            LabeledContent("Created", value: snapshot.workspace.createdAt)
        }
    }

    private var workspaceLockSection: some View {
        Section("Workspace Lock") {
            Toggle(
                "Require Mac login when opening this workspace",
                isOn: Binding(
                    get: { snapshot.workspaceLock.isEnabled },
                    set: { onSetWorkspaceLockEnabled($0) }
                )
            )
            .disabled(snapshot.workspaceLock.canToggle == false)
            .accessibilityIdentifier("settings.workspaceLockToggle")

            Text(snapshot.workspaceLock.detail)
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.workspaceLock.detail")

            LabeledContent("Status", value: snapshot.workspaceLock.status)

            Button(action: onLockWorkspace) {
                Label("Lock Workspace", systemImage: "lock")
            }
            .buttonStyle(.bordered)
            .disabled(snapshot.workspaceLock.canLockNow == false)
            .accessibilityIdentifier("settings.lockWorkspaceButton")
        }
    }

    private var aiPrivacySection: some View {
        Section("AI & Privacy") {
            LabeledContent("Mode", value: snapshot.aiPrivacy.modeTitle)
            Text(snapshot.aiPrivacy.modeDetail)
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.aiPrivacy.modeDetail")

            LabeledContent("Network", value: snapshot.aiPrivacy.networkStatus)
            LabeledContent("Cloud inference", value: snapshot.aiPrivacy.cloudStatus)

            HStack(spacing: AppTheme.spacingS) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.aiPrivacy.activity.title)
                        .font(.headline)
                    Text(snapshot.aiPrivacy.activity.detail)
                        .font(AppTheme.metaFont)
                        .foregroundStyle(.secondary)
                    Text("\(snapshot.aiPrivacy.activity.networkStatus) · \(snapshot.aiPrivacy.activity.offDeviceStatus)")
                        .font(AppTheme.metaFont)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                StatusBadge(
                    snapshot.aiPrivacy.activity.title,
                    tone: statusTone(for: snapshot.aiPrivacy.activity.tone)
                )
            }
            .accessibilityIdentifier("settings.aiPrivacy.activity")

            ForEach(snapshot.aiPrivacy.controls) { control in
                HStack(spacing: AppTheme.spacingS) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(control.title)
                            .font(.headline)
                        Text(control.detail)
                            .font(AppTheme.metaFont)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    StatusBadge(
                        control.value,
                        tone: statusTone(for: control.tone)
                    )
                }
                .accessibilityIdentifier("settings.aiPrivacy.control.\(accessibilitySlug(control.id))")
            }

            if snapshot.aiPrivacy.providers.isEmpty {
                Text("No model providers are enabled.")
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.aiPrivacy.providers) { provider in
                    HStack(spacing: AppTheme.spacingS) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(provider.name)
                                .font(.headline)
                            Text("\(provider.role) · \(provider.capabilities)")
                                .font(AppTheme.metaFont)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        StatusBadge(
                            provider.status,
                            tone: statusTone(for: provider.tone)
                        )
                    }
                    .accessibilityIdentifier("settings.aiPrivacy.provider.\(accessibilitySlug(provider.id))")
                }
            }
        }
    }

    private var backupSection: some View {
        Section("Backup & Restore") {
            Text(snapshot.backup.warning)
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)

            HStack(spacing: AppTheme.spacingS) {
                Button(action: onCreateBackup) {
                    Label("Create Backup…", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(snapshot.backup.canCreateBackup == false)
                .accessibilityIdentifier("settings.createBackupButton")

                Button(action: onValidateBackup) {
                    Label("Check Backup…", systemImage: "checkmark.shield")
                }
                .buttonStyle(.bordered)
                .disabled(snapshot.backup.canValidateBackup == false)
                .accessibilityIdentifier("settings.validateBackupButton")

                Button(action: onRestoreBackup) {
                    Label("Restore Backup…", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .disabled(snapshot.backup.canRestoreBackup == false)
                .accessibilityIdentifier("settings.restoreBackupButton")
            }

            if let lastAction = snapshot.backup.lastAction {
                LabeledContent("Last action", value: lastAction)
            }

            if let integrity = snapshot.backup.integrity {
                BackupIntegritySummaryView(integrity: integrity)
            }
        }
    }

    private var importDefaultsSection: some View {
        Section("Import Defaults") {
            Text(snapshot.importDefaults.explanation)
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)

            Picker(
                "Statement account",
                selection: Binding<FinancialAccountID?>(
                    get: { snapshot.importDefaults.defaultAccountId },
                    set: { onSetDefaultImportAccount($0) }
                )
            ) {
                Text("Selected ledger account")
                    .tag(nil as FinancialAccountID?)

                ForEach(snapshot.importDefaults.accounts) { account in
                    Text(account.title)
                        .tag(Optional(account.id))
                }
            }
            .disabled(snapshot.importDefaults.canChooseDefault == false)
            .accessibilityIdentifier("settings.defaultImportAccountPicker")

            LabeledContent("Current default", value: snapshot.importDefaults.status)

            if snapshot.importDefaults.accounts.isEmpty {
                Text("Create or open an entity with a financial account before setting a default.")
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.importDefaults.accounts) { account in
                    HStack(spacing: AppTheme.spacingS) {
                        Text(account.title)
                            .font(.headline)
                        Spacer()
                        Text(account.detail)
                            .font(AppTheme.metaFont)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("settings.defaultImportAccount.\(accessibilitySlug(account.title))")
                }
            }
        }
    }

    private var entitiesSection: some View {
        Section("Entities") {
            if snapshot.entities.isEmpty {
                Text("No entities configured.")
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.entities) { entity in
                    EntityEditorRow(
                        entity: entity,
                        onRename: onRenameEntity,
                        onRemove: onRemoveEntity
                    )
                }
            }
        }
    }

    private var addEntitySection: some View {
        Section("Add Entity") {
            HStack(spacing: AppTheme.spacingS) {
                TextField("Business name", text: $newSolePropName)
                    .accessibilityIdentifier("settings.solePropNameField")

                Button("Add Sole Proprietor", action: onCreateSoleProp)
                    .buttonStyle(.borderedProminent)
                    .disabled(newSolePropName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("settings.addSolePropButton")
            }
        }
    }

    private var dataHealthSection: some View {
        Section("Data Health") {
            HStack(spacing: AppTheme.spacingS) {
                StatusBadge(
                    snapshot.dataHealth.title,
                    tone: statusTone(for: snapshot.dataHealth.tone),
                    accessibilityIdentifier: "settings.dataHealth.status"
                )

                Text(snapshot.dataHealth.detail)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            }

            if snapshot.dataHealth.issues.isEmpty {
                Text("No database health issues found.")
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.dataHealth.noIssues")
            } else {
                ForEach(snapshot.dataHealth.issues) { issue in
                    HStack(spacing: AppTheme.spacingS) {
                        StatusBadge(issue.title, tone: statusTone(for: issue.tone))
                        Text(issue.detail)
                            .font(AppTheme.metaFont)
                    }
                    .accessibilityIdentifier("settings.dataHealth.issue.\(accessibilitySlug(issue.id))")
                }
            }
        }
    }

    private var helpSection: some View {
        Section("Help") {
            Text("Open the local guide for setup, evidence review, tax readiness, backups, and sanitized support exports.")
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)

            Button(action: onShowHelp) {
                Label("Open AlpenLedger Help", systemImage: "questionmark.circle")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("settings.openHelpButton")
        }
    }

    private var dataResetSection: some View {
        Section("Data Reset") {
            Text(snapshot.dataReset.warning)
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: onDeleteWorkspace) {
                Label("Delete Current Workspace…", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(snapshot.dataReset.canDeleteWorkspace == false)
            .accessibilityIdentifier("settings.deleteWorkspaceButton")
        }
    }

    private var supportSection: some View {
        Section("Support Diagnostics") {
            Text(snapshot.support.explanation)
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)

            HStack(spacing: AppTheme.spacingS) {
                Button(action: onExportDiagnostics) {
                    Label("Export Diagnostics…", systemImage: "wrench.and.screwdriver")
                }
                .buttonStyle(.bordered)
                .disabled(snapshot.support.canExportDiagnostics == false)
                .accessibilityIdentifier("settings.exportDiagnosticsButton")

                Button(action: onExportSupportBundle) {
                    Label("Export Support Bundle…", systemImage: "doc.zipper")
                }
                .buttonStyle(.bordered)
                .disabled(snapshot.support.canExportSupportBundle == false)
                .accessibilityIdentifier("settings.exportSupportBundleButton")
            }

            if let lastAction = snapshot.support.lastAction {
                LabeledContent("Last action", value: lastAction)
            }

            if let diagnostics = snapshot.support.diagnostics {
                HStack(spacing: AppTheme.spacingS) {
                    StatusBadge(
                        diagnostics.title,
                        tone: statusTone(for: diagnostics.tone),
                        accessibilityIdentifier: "settings.supportDiagnostics.status"
                    )

                    Text(diagnostics.detail)
                        .font(AppTheme.metaFont)
                        .foregroundStyle(.secondary)
                }
            }

            if let supportBundle = snapshot.support.supportBundle {
                HStack(spacing: AppTheme.spacingS) {
                    StatusBadge(
                        supportBundle.title,
                        tone: statusTone(for: supportBundle.tone),
                        accessibilityIdentifier: "settings.supportBundle.status"
                    )

                    Text(supportBundle.detail)
                        .font(AppTheme.metaFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private func statusTone(
    for tone: SettingsSnapshot.BackupDetails.IntegrityTone
) -> StatusBadge.Tone {
    switch tone {
    case .neutral:
        return .neutral
    case .success:
        return .success
    case .warning:
        return .warning
    case .critical:
        return .critical
    }
}

private struct BackupIntegritySummaryView: View {
    let integrity: SettingsSnapshot.BackupDetails.IntegritySummary

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
            HStack(spacing: AppTheme.spacingS) {
                StatusBadge(
                    integrity.title,
                    tone: statusTone(for: integrity.tone),
                    accessibilityIdentifier: "settings.backupIntegrity.status"
                )

                Text(integrity.detail)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            }

            if integrity.issues.isEmpty {
                Text("No integrity issues found.")
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.backupIntegrity.noIssues")
            } else {
                ForEach(integrity.issues) { issue in
                    VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                        HStack(spacing: AppTheme.spacingS) {
                            StatusBadge(issue.title, tone: statusTone(for: issue.tone))
                            Text(issue.detail)
                                .font(AppTheme.metaFont)
                        }
                    }
                    .accessibilityIdentifier("settings.backupIntegrity.issue.\(accessibilitySlug(issue.id))")
                }
            }
        }
        .padding(.vertical, AppTheme.spacingXXS)
    }
}

private struct EntityEditorRow: View {
    @State private var draftName: String

    private let entity: EntityRowModel
    private let onRename: (LegalEntityID, String) -> Void
    private let onRemove: (LegalEntityID) -> Void

    init(
        entity: EntityRowModel,
        onRename: @escaping (LegalEntityID, String) -> Void,
        onRemove: @escaping (LegalEntityID) -> Void
    ) {
        self.entity = entity
        self.onRename = onRename
        self.onRemove = onRemove
        _draftName = State(initialValue: entity.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack(spacing: AppTheme.spacingS) {
                TextField("Entity name", text: $draftName)
                    .accessibilityIdentifier("settings.entity.name.\(accessibilitySlug(entity.name))")

                Button("Save") {
                    onRename(entity.id, draftName)
                }
                .buttonStyle(.bordered)
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("settings.entity.save.\(accessibilitySlug(entity.name))")

                Button("Remove") {
                    onRemove(entity.id)
                }
                .buttonStyle(.bordered)
                .disabled(entity.canRemove == false)
                .accessibilityIdentifier("settings.entity.remove.\(accessibilitySlug(entity.name))")
            }

            Text("\(entity.kindLabel) \u{2022} \(entity.detail)")
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)

            if let removalHint = entity.removalHint {
                Text(removalHint)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
