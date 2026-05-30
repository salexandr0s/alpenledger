import ALDesignSystem
import ALDomain
import ALFeatures
import ALStorage

extension WorkspaceAppModel {

    // MARK: - Forwarding properties

    var workspaceName: String {
        session?.storage.manifest.workspace.name ?? "AlpenLedger"
    }

    var hasWorkspace: Bool { session != nil }
    var transactionCount: Int { transactions.count }
    var documentCount: Int { documents.count }
    var openIssueCount: Int { issues.count(where: { $0.status == .open }) }
    var pendingProposalCount: Int { agentProposals.count(where: { $0.status == .pending }) }
    var canImportCSV: Bool { hasWorkspace && (selectedAccountId != nil || financialAccounts.isEmpty == false) }
    var canImportDocument: Bool { hasWorkspace }
    var canImportSampleData: Bool { hasWorkspace }
    var documentVaultCount: Int { documents.count + archivedDocuments.count }
    var canCreateBackup: Bool { hasWorkspace }
    var canValidateBackup: Bool { true }
    var canRestoreBackup: Bool { true }
    var canExportDiagnostics: Bool { hasWorkspace }
    var canExportSupportBundle: Bool { hasWorkspace }
    var canCloseCurrentWorkspace: Bool { hasWorkspace }
    var canLockCurrentWorkspace: Bool {
        guard let workspaceId = session?.storage.manifest.workspace.id else { return false }
        return uiPreferencesStore.workspaceLockEnabled(workspaceId: workspaceId)
    }
    var canDeleteCurrentWorkspace: Bool { hasWorkspace }
    var canUseGlobalSearch: Bool { hasWorkspace }
    var currentSectionSubtitle: String { selectedSection.subtitle }
    var visibleTransactions: [Transaction] { transactions.filter { ledgerTransactionScope.matches($0) } }
    var selectedDocument: Document? {
        documents.first(where: { $0.id == selectedDocumentId }) ??
            archivedDocuments.first(where: { $0.id == selectedDocumentId })
    }
    var visibleDocuments: [Document] {
        let source = documentFilterScope == .archived ? archivedDocuments : documents
        return source.filter { documentFilterScope.matches($0) && documentMatchesSearch($0) }
    }
    var ledgerInspectorButtonTitle: String { isLedgerInspectorVisible ? "Hide Inspector" : "Show Inspector" }
    var documentsInspectorButtonTitle: String { isDocumentsInspectorVisible ? "Hide Inspector" : "Show Inspector" }
    var activeInspectorToggleTitle: String {
        switch selectedSection {
        case .ledger:
            return ledgerInspectorButtonTitle
        case .documents:
            return documentsInspectorButtonTitle
        case .overview, .inbox, .copilot, .taxStudio, .settings:
            return "Toggle Inspector"
        }
    }
    var selectedAccountTitle: String? { selectedAccountName }
    var selectedDocumentName: String? {
        selectedDocument?.originalFilename
    }
    var canToggleActiveInspector: Bool {
        hasWorkspace && (selectedSection == .ledger || selectedSection == .documents)
    }
    var canLinkSelectedDocument: Bool {
        selectedSection == .ledger && selectedTransactionId != nil
    }
    var canLinkSelectedTransaction: Bool {
        selectedSection == .documents && selectedDocument?.status == .active
    }
    var canArchiveSelectedDocument: Bool {
        selectedSection == .documents && selectedDocument?.status == .active
    }
    var canRestoreSelectedDocument: Bool {
        selectedSection == .documents && selectedDocument?.status == .archived
    }

    // MARK: - Snapshot computed properties

    var shellToolbarConfiguration: ShellToolbarConfiguration {
        switch selectedSection {
        case .ledger:
            return ShellToolbarConfiguration(
                title: workspaceName,
                subtitle: currentSectionSubtitle,
                inspectorControl: .init(
                    title: ledgerInspectorButtonTitle,
                    accessibilityIdentifier: "toolbar.ledger.toggleInspector"
                )
            )
        case .documents:
            return ShellToolbarConfiguration(
                title: workspaceName,
                subtitle: currentSectionSubtitle,
                inspectorControl: .init(
                    title: documentsInspectorButtonTitle,
                    accessibilityIdentifier: "toolbar.documents.toggleInspector"
                )
            )
        case .overview, .inbox, .copilot, .taxStudio, .settings:
            return ShellToolbarConfiguration(
                title: workspaceName,
                subtitle: currentSectionSubtitle,
                inspectorControl: nil
            )
        }
    }

    var workspaceChooserSnapshot: WorkspaceChooserSnapshot {
        WorkspaceChooserSnapshot(
            title: "AlpenLedger",
            tagline: "Local-first bookkeeping and tax readiness for Swiss sole proprietors and natural persons.",
            trustLine: "Encrypted. Local. Yours.",
            onboardingItems: [
                WorkspaceChooserSnapshot.OnboardingItem(
                    id: "demo",
                    title: "Try the demo workspace",
                    detail: "Review sample transactions, a receipt, missing-evidence alerts, and search before using personal data.",
                    systemImage: "sparkles.rectangle.stack"
                ),
                WorkspaceChooserSnapshot.OnboardingItem(
                    id: "local-workspace",
                    title: "Create a local workspace",
                    detail: "Your ledger, documents, backups, and support exports stay on this Mac unless you choose otherwise.",
                    systemImage: "lock.laptopcomputer"
                ),
                WorkspaceChooserSnapshot.OnboardingItem(
                    id: "backup",
                    title: "Back up before review",
                    detail: "Use Settings to create and check a protected backup bundle before filing or sharing diagnostics.",
                    systemImage: "externaldrive.badge.checkmark"
                ),
            ],
            recentWorkspaces: recentWorkspaces.map { reference in
                WorkspaceChooserSnapshot.RecentWorkspace(
                    reference: reference,
                    title: reference.name,
                    lastOpenedText: relativeDateString(for: reference.lastOpenedAt)
                )
            }
        )
    }

    var helpCenterSnapshot: HelpCenterSnapshot {
        HelpCenterSnapshot(
            title: "AlpenLedger Help",
            subtitle: "A local-first guide for setup, evidence review, tax readiness, backup, and support.",
            privacyNotice: "AlpenLedger keeps workspace data local by default. Agent answers and support exports must cite stored evidence and omit raw source data unless an explicit workflow says otherwise.",
            sections: [
                HelpCenterSnapshot.HelpSection(
                    id: "first-run",
                    title: "First Run",
                    systemImage: "checklist",
                    items: [
                        HelpCenterSnapshot.HelpItem(
                            id: "first-run-demo",
                            title: "Use the demo workspace for a safe tour.",
                            detail: "The demo imports bundled sample data through the same local services used for real statements and receipts."
                        ),
                        HelpCenterSnapshot.HelpItem(
                            id: "first-run-workspace",
                            title: "Create a dedicated workspace for real records.",
                            detail: "Each workspace has its own local database, document blobs, encryption key, recents entry, and backup path."
                        ),
                    ]
                ),
                HelpCenterSnapshot.HelpSection(
                    id: "evidence",
                    title: "Evidence Review",
                    systemImage: "doc.text.magnifyingglass",
                    items: [
                        HelpCenterSnapshot.HelpItem(
                            id: "evidence-imports",
                            title: "Import statements and documents from trusted local files.",
                            detail: "Import diagnostics and the inbox show parse warnings, missing evidence, duplicate risks, and retry options."
                        ),
                        HelpCenterSnapshot.HelpItem(
                            id: "evidence-links",
                            title: "Review matches before they become support.",
                            detail: "Document and transaction links are proposals until confirmed, and low-confidence matches ask for review."
                        ),
                    ]
                ),
                HelpCenterSnapshot.HelpSection(
                    id: "tax-readiness",
                    title: "Tax Readiness",
                    systemImage: "building.columns",
                    items: [
                        HelpCenterSnapshot.HelpItem(
                            id: "tax-readiness-facts",
                            title: "Treat tax amounts as deterministic facts.",
                            detail: "Tax Studio displays rule-derived facts, requirements, VAT period diagnostics, and blockers without letting the model invent values."
                        ),
                        HelpCenterSnapshot.HelpItem(
                            id: "tax-readiness-locks",
                            title: "Respect locked periods.",
                            detail: "Locked tax years and VAT periods block imports or overrides that would change confirmed filing evidence."
                        ),
                    ]
                ),
                HelpCenterSnapshot.HelpSection(
                    id: "support",
                    title: "Backup & Support",
                    systemImage: "lifepreserver",
                    items: [
                        HelpCenterSnapshot.HelpItem(
                            id: "support-backup",
                            title: "Create and check backups before destructive actions.",
                            detail: "Backup bundles include the workspace key and should be stored only in a protected local location."
                        ),
                        HelpCenterSnapshot.HelpItem(
                            id: "support-bundle",
                            title: "Export sanitized support files for troubleshooting.",
                            detail: "Diagnostics and support bundles exclude source documents, raw audit payloads, workspace names, paths, and encryption keys."
                        ),
                    ]
                ),
            ]
        )
    }

    var overviewSnapshot: OverviewSnapshot {
        OverviewSnapshot(
            workspaceName: workspaceName,
            workspaceSubtitle: workspaceSummarySubtitle,
            metrics: overviewMetrics,
            priorityAction: overviewPriorityAction,
            secondaryActions: overviewSecondaryActions,
            attentionItems: overviewAttentionItems,
            recentActivityItems: overviewRecentActivityItems,
            recentActivityEmptyTitle: "No recent imports",
            recentActivityActionTitle: "Import",
            recentActivityAction: canImportDocument ? .importDocument : nil
        )
    }

    var inboxSnapshot: InboxSnapshot {
        InboxSnapshot(
            tabs: [
                InboxTabSummary(tab: .issues, count: issues.count),
                InboxTabSummary(tab: .proposals, count: pendingProposalCount),
                InboxTabSummary(tab: .imports, count: importJobs.count),
            ],
            rows: inboxRows,
            inspector: inboxInspector
        )
    }

    var copilotSnapshot: CopilotSnapshot {
        CopilotSnapshot(
            title: "Copilot",
            subtitle: copilotContextSubtitle,
            contextItems: copilotContextItems,
            prompts: copilotPrompts,
            answers: [
                copilotTaxReadinessAnswer,
                copilotExpenseEvidenceAnswer,
                copilotStatementCoverageAnswer,
                copilotVATAnswer,
                copilotBusinessExportAnswer,
            ]
        )
    }

    var ledgerAccountSummaries: [LedgerAccountSummary] {
        financialAccounts.map { account in
            let balanceText: String
            let tone: StatusBadge.Tone
            if let balance = accountBalanceById[account.id] {
                balanceText = amountString(balance, currency: account.currency)
                tone = balance < 0 ? .warning : .neutral
            } else {
                balanceText = "Balance unavailable"
                tone = .neutral
            }

            return LedgerAccountSummary(
                id: account.id,
                title: account.displayName,
                subtitle: account.institutionName,
                accountTypeLabel: accountTypeLabel(account.accountType),
                balanceText: balanceText,
                statusText: account.closedAt == nil ? "Active" : "Closed",
                tone: tone,
                systemImage: symbol(for: account.accountType)
            )
        }
    }

    var documentBrowserItems: [DocumentBrowserItem] {
        visibleDocuments.map { document in
            DocumentBrowserItem(
                id: document.id,
                title: document.originalFilename,
                subtitle: documentTypeLabel(document.documentType),
                documentType: document.documentType,
                typeLabel: documentTypeLabel(document.documentType),
                dateLabel: formattedDate(document.issueDate),
                statusText: documentStatusLabel(document),
                metadataStatus: document.metadataStatus,
                tone: documentStatusTone(document),
                systemImage: document.status == .archived ? "archivebox" : documentSymbol(document.documentType),
                issueDate: document.issueDate,
                mediaType: document.mediaType,
                isArchived: document.status == .archived,
                archivedAtText: document.archivedAt.map(formattedDate),
                archivedBy: document.archivedBy,
                archiveReason: document.archiveReason
            )
        }
    }

    var taxStudioSnapshot: TaxStudioSnapshot {
        TaxStudioSnapshot(
            readinessTitle: readinessTitle(taxReadinessSummary.state),
            readinessSummary: taxReadinessSummaryText,
            readinessTone: taxReadinessTone,
            periodStatus: taxPeriodStatus,
            vatPeriods: taxStudioVATPeriods,
            filingPackages: taxStudioFilingPackages,
            checklistItems: taxChecklistItems,
            factCategories: taxFactCategories,
            inspector: taxInspector
        )
    }

    var settingsSnapshot: SettingsSnapshot {
        SettingsSnapshot(
            workspace: SettingsSnapshot.WorkspaceDetails(
                name: workspaceName,
                type: container.privacyMode.workspaceTypeLabel,
                location: session?.storage.paths.rootURL.path ?? "Not available",
                encryptionStatus: container.privacyMode.privacyStatusLabel,
                createdAt: formattedDate(session?.storage.manifest.workspace.createdAt)
            ),
            workspaceLock: workspaceLockSnapshot,
            aiPrivacy: aiPrivacySnapshot,
            backup: SettingsSnapshot.BackupDetails(
                warning: "Backup bundles include the workspace encryption key. Store them only in a protected local location.",
                lastAction: backupStatusMessage,
                canCreateBackup: canCreateBackup,
                canValidateBackup: canValidateBackup,
                canRestoreBackup: canRestoreBackup,
                integrity: backupIntegritySnapshot
            ),
            importDefaults: importDefaultsSnapshot,
            dataHealth: dataHealthSnapshot,
            dataReset: SettingsSnapshot.DataResetDetails(
                warning: "Deleting a workspace removes the local workspace folder and its encryption key. Create and verify a backup before using this action.",
                canDeleteWorkspace: canDeleteCurrentWorkspace
            ),
            support: supportSnapshot,
            entities: entities.map { entity in
                let deletionCheck = entityDeletionChecks[entity.id]
                return EntityRowModel(
                    id: entity.id,
                    name: entity.displayName,
                    kindLabel: entityKindLabel(entity.kind),
                    detail: entity.canton.map { "Canton \($0)" } ?? "Switzerland",
                    canRemove: deletionCheck?.canDelete ?? true,
                    removalHint: deletionRemovalHint(deletionCheck)
                )
            }
        )
    }

    private var workspaceLockSnapshot: SettingsSnapshot.WorkspaceLockDetails {
        guard let workspaceId = session?.storage.manifest.workspace.id else {
            return SettingsSnapshot.WorkspaceLockDetails(
                isEnabled: false,
                status: "Unavailable",
                detail: "Open a workspace before configuring the app-level lock gate.",
                canToggle: false,
                canLockNow: false
            )
        }

        let isEnabled = uiPreferencesStore.workspaceLockEnabled(workspaceId: workspaceId)
        return SettingsSnapshot.WorkspaceLockDetails(
            isEnabled: isEnabled,
            status: workspaceLockStatusMessage ?? (isEnabled ? "Enabled" : "Disabled"),
            detail: isEnabled
                ? "Opening this workspace requires Mac authentication. Locking closes the active decrypted session and returns to the workspace chooser."
                : "Enable this to require Touch ID, Apple Watch, or Mac password authentication before this workspace opens.",
            canToggle: hasWorkspace,
            canLockNow: canLockCurrentWorkspace
        )
    }

    private var importDefaultsSnapshot: SettingsSnapshot.ImportDefaultsDetails {
        let accountRows = financialAccounts.map { account in
            SettingsSnapshot.ImportDefaultsDetails.AccountRow(
                id: account.id,
                title: account.displayName,
                detail: [
                    accountTypeLabel(account.accountType),
                    account.institutionName,
                    account.currency.rawValue,
                ].joined(separator: " • ")
            )
        }

        let defaultAccount = preferredStatementImportAccountId.flatMap { accountId in
            financialAccounts.first { $0.id == accountId }
        }
        let status: String
        if let defaultAccount {
            status = importDefaultsStatusMessage ?? "Statement imports default to \(defaultAccount.displayName)."
        } else if financialAccounts.isEmpty {
            status = "No financial accounts available."
        } else {
            status = "Uses the selected ledger account, then the first available account."
        }

        return SettingsSnapshot.ImportDefaultsDetails(
            explanation: "Choose the account used for bank statement imports when no account-specific action started the import.",
            defaultAccountId: defaultAccount?.id,
            status: status,
            accounts: accountRows,
            canChooseDefault: hasWorkspace && accountRows.isEmpty == false
        )
    }

    private var aiPrivacySnapshot: SettingsSnapshot.AIPrivacyDetails {
        let appPrivacyMode = container.privacyMode
        let privacyMode = appPrivacyMode.modelProviderPrivacyMode
        let consent = container.modelProviderConsent
        let allowedProviderIDs = Set(
            container.modelProviderRegistry
                .allowedProviders(privacyMode: privacyMode, consent: consent)
                .map(\.id)
        )

        return SettingsSnapshot.AIPrivacyDetails(
            modeTitle: container.privacyMode.aiPrivacyModeTitle,
            modeDetail: container.privacyMode.aiPrivacyModeDetail,
            networkStatus: container.privacyMode.networkActivityLabel,
            cloudStatus: container.privacyMode.cloudInferenceLabel,
            activity: aiPrivacyActivityDetails(container.modelProviderActivityLog.latestSnapshot),
            controls: aiPrivacyControlRows(appPrivacyMode: appPrivacyMode, consent: consent),
            providers: container.modelProviderRegistry.providers.map { provider in
                let isAllowed = allowedProviderIDs.contains(provider.id)
                let decision = container.modelProviderRegistry.decision(
                    forProviderID: provider.id,
                    privacyMode: privacyMode,
                    consent: consent
                )
                let status = modelProviderStatus(for: decision, isAllowed: isAllowed)
                return SettingsSnapshot.AIPrivacyDetails.ProviderRow(
                    id: provider.id,
                    name: provider.displayName,
                    role: modelProviderRoleLabel(provider.role),
                    capabilities: modelProviderCapabilitySummary(provider.capabilities),
                    status: status.title,
                    tone: status.tone
                )
            }
        )
    }

    private var supportSnapshot: SettingsSnapshot.SupportDetails {
        let diagnosticsSummary: SettingsSnapshot.SupportDetails.ExportSummary?
        if let latestDiagnosticsReport {
            let blockerCount = latestDiagnosticsReport.databaseHealth.issues.count { $0.severity == .blocker }
            let warningCount = latestDiagnosticsReport.databaseHealth.issues.count { $0.severity == .warning }
            let tone: SettingsSnapshot.BackupDetails.IntegrityTone
            let title: String
            if blockerCount > 0 {
                tone = .critical
                title = "Diagnostics exported with blockers"
            } else if warningCount > 0 {
                tone = .warning
                title = "Diagnostics exported with warnings"
            } else {
                tone = .success
                title = "Diagnostics exported"
            }

            let recordCount = latestDiagnosticsReport.tableCounts.reduce(0) { $0 + $1.rowCount }
            diagnosticsSummary = SettingsSnapshot.SupportDetails.ExportSummary(
                title: title,
                detail: "\(latestDiagnosticsReport.tableCounts.count) tables • \(recordCount) records • \(latestDiagnosticsReport.filesystem.blobs.fileCount) blob files",
                tone: tone
            )
        } else {
            diagnosticsSummary = nil
        }

        let bundleSummary: SettingsSnapshot.SupportDetails.ExportSummary?
        if let latestSupportBundle {
            let blockerCount = latestSupportBundle.diagnostics.databaseHealth.issues.count { $0.severity == .blocker }
            let warningCount = latestSupportBundle.diagnostics.databaseHealth.issues.count { $0.severity == .warning }
            let tone: SettingsSnapshot.BackupDetails.IntegrityTone
            let title: String
            if blockerCount > 0 {
                tone = .critical
                title = "Support bundle exported with blockers"
            } else if warningCount > 0 {
                tone = .warning
                title = "Support bundle exported with warnings"
            } else {
                tone = .success
                title = "Support bundle exported"
            }

            bundleSummary = SettingsSnapshot.SupportDetails.ExportSummary(
                title: title,
                detail: "\(latestSupportBundle.auditLog.totalEventCount) audit events • \(latestSupportBundle.auditLog.eventsByType.count) event types • \(latestSupportBundle.diagnostics.tableCounts.count) tables",
                tone: tone
            )
        } else {
            bundleSummary = nil
        }

        return SettingsSnapshot.SupportDetails(
            explanation: "Exports sanitized local troubleshooting files. They exclude source documents, document names, transaction text, raw audit payloads, workspace names, absolute paths, and encryption keys.",
            lastAction: diagnosticsStatusMessage,
            canExportDiagnostics: canExportDiagnostics,
            canExportSupportBundle: canExportSupportBundle,
            diagnostics: diagnosticsSummary,
            supportBundle: bundleSummary
        )
    }

    private var dataHealthSnapshot: SettingsSnapshot.DataHealthDetails {
        guard let report = databaseHealthReport else {
            return SettingsSnapshot.DataHealthDetails(
                title: "Health not checked",
                detail: "Open a workspace to run database checks.",
                tone: .neutral,
                issues: []
            )
        }

        let blockerCount = report.issues.count { $0.severity == .blocker }
        let warningCount = report.issues.count { $0.severity == .warning }
        let tone: SettingsSnapshot.BackupDetails.IntegrityTone
        let title: String

        if blockerCount > 0 {
            tone = .critical
            title = "Workspace data blocked"
        } else if warningCount > 0 {
            tone = .warning
            title = "Workspace data warnings"
        } else {
            tone = .success
            title = "Workspace data checks passed"
        }

        let detail = [
            "\(report.appliedMigrationIdentifiers.count)/\(report.expectedMigrationIdentifiers.count) migrations",
            "\(report.pageCount) DB pages",
            report.foreignKeysEnabled ? "foreign keys on" : "foreign keys off",
        ].joined(separator: " • ")

        return SettingsSnapshot.DataHealthDetails(
            title: title,
            detail: detail,
            tone: tone,
            issues: report.issues.map { issue in
                SettingsSnapshot.DataHealthDetails.IssueRow(
                    id: issue.code,
                    title: issue.severity == .blocker ? "Blocker" : "Warning",
                    detail: issue.summary,
                    tone: issue.severity == .blocker ? .critical : .warning
                )
            }
        )
    }

    private var backupIntegritySnapshot: SettingsSnapshot.BackupDetails.IntegritySummary? {
        guard let backupIntegrityResult else { return nil }

        let issues = backupIntegrityResult.report.issues
        let blockerCount = issues.count { $0.severity == .blocker }
        let warningCount = issues.count { $0.severity == .warning }
        let tone: SettingsSnapshot.BackupDetails.IntegrityTone
        let title: String

        if blockerCount > 0 {
            tone = .critical
            title = "Backup blocked"
        } else if warningCount > 0 {
            tone = .warning
            title = "Restorable with warnings"
        } else {
            tone = .success
            title = "Backup can be restored"
        }

        let manifest = backupIntegrityResult.report.manifest
        let workspaceName = manifest?.workspaceName ?? "Unknown workspace"
        let hashCount = manifest?.fileHashes.count ?? 0
        let detail = "\(backupIntegrityResult.backupName) • \(workspaceName) • \(hashCount) hashed files"

        return SettingsSnapshot.BackupDetails.IntegritySummary(
            title: title,
            detail: detail,
            tone: tone,
            issues: issues.enumerated().map { index, issue in
                SettingsSnapshot.BackupDetails.IntegrityIssueRow(
                    id: "\(index)-\(issue.code)-\(issue.relativePath ?? "backup")",
                    title: issue.severity == .blocker ? "Blocker" : "Warning",
                    detail: backupIntegrityIssueDetail(issue),
                    tone: issue.severity == .blocker ? .critical : .warning
                )
            }
        )
    }

    // MARK: - Sidebar badge

    func sidebarBadgeText(for section: AppSection) -> String? {
        switch section {
        case .inbox:
            let total = openIssueCount + pendingProposalCount
            return total > 0 ? total.formatted() : nil
        case .ledger:
            return visibleTransactions.isEmpty ? nil : visibleTransactions.count.formatted()
        case .documents:
            return visibleDocuments.isEmpty ? nil : visibleDocuments.count.formatted()
        case .taxStudio:
            let total = taxReadinessSummary.openIssueCount + taxReadinessSummary.pendingRequirementCount
            return total > 0 ? total.formatted() : nil
        case .overview, .copilot, .settings:
            return nil
        }
    }

    // MARK: - Supporting computed properties

    var workspaceSummarySubtitle: String {
        let entityLabel = "\(entities.count) \(entities.count == 1 ? "entity" : "entities")"
        let accountLabel = "\(financialAccounts.count) \(financialAccounts.count == 1 ? "account" : "accounts")"
        let documentLabel = "\(documents.count) \(documents.count == 1 ? "document" : "documents")"
        return [entityLabel, accountLabel, documentLabel].joined(separator: " • ")
    }

    var overviewMetrics: [OverviewSnapshot.MetricItem] {
        [
            OverviewSnapshot.MetricItem(
                id: "issues",
                title: "Open Issues",
                value: openIssueCount.formatted(),
                subtitle: openIssueCount == 0 ? "All clear" : "Need attention",
                tone: openIssueCount == 0 ? .success : .critical,
                systemImage: "exclamationmark.bubble"
            ),
            OverviewSnapshot.MetricItem(
                id: "requirements",
                title: "Pending Requirements",
                value: taxReadinessSummary.pendingRequirementCount.formatted(),
                subtitle: taxReadinessSummary.pendingRequirementCount == 0 ? "Complete" : "Still missing",
                tone: taxReadinessSummary.pendingRequirementCount == 0 ? .success : .warning,
                systemImage: "list.bullet.clipboard"
            ),
            OverviewSnapshot.MetricItem(
                id: "documents",
                title: "Documents",
            value: documentCount.formatted(),
                subtitle: latestImportSummary ?? "No imports yet",
                tone: documentCount == 0 ? .neutral : .info,
                systemImage: "doc.on.doc"
            ),
            OverviewSnapshot.MetricItem(
                id: "tax",
                title: "Tax Readiness",
                value: readinessTitle(taxReadinessSummary.state),
                subtitle: "\(taxReadinessSummary.currentFactCount) current facts",
                tone: readinessTone(taxReadinessSummary.state),
                systemImage: "checkmark.shield"
            ),
        ]
    }

    var overviewActionItems: [OverviewSnapshot.ActionItem] {
        var items: [OverviewSnapshot.ActionItem] = []

        if let issueSelection = firstOpenIssueSelection, openIssueCount > 0 {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "issues",
                    title: "Resolve open issues",
                    subtitle: "\(openIssueCount) issue\(openIssueCount == 1 ? "" : "s") are still blocking confidence in this workspace.",
                    buttonTitle: "Open Inbox",
                    systemImage: "tray.full",
                    action: .openInbox(selection: issueSelection)
                )
            )
        }

        if let proposalSelection = firstPendingProposalSelection, pendingProposalCount > 0 {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "proposals",
                    title: "Review pending proposals",
                    subtitle: "\(pendingProposalCount) suggestion\(pendingProposalCount == 1 ? "" : "s") still need a decision.",
                    buttonTitle: "Review Proposals",
                    systemImage: "wand.and.stars",
                    action: .openInbox(selection: proposalSelection)
                )
            )
        }

        if taxReadinessSummary.state != .readyForReview {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "tax",
                    title: "Check tax readiness",
                    subtitle: "\(taxReadinessSummary.pendingRequirementCount) pending requirements and \(taxReadinessSummary.missingConceptCodes.count) missing facts remain.",
                    buttonTitle: "Open Tax Studio",
                    systemImage: "checklist.checked",
                    action: .openTaxStudio(
                        entityId: selectedTaxEntityId,
                        taxYearId: selectedTaxYearId,
                        factId: nil
                    )
                )
            )
        }

        if let latestDocument = documents.first {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "documents",
                    title: "Review imported documents",
                    subtitle: "Inspect the latest evidence in the document vault.",
                    buttonTitle: "Open Documents",
                    systemImage: "doc.text.image",
                    action: .openDocuments(documentId: latestDocument.id)
                )
            )
        } else if let latestTransaction = visibleTransactions.first ?? transactions.first {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "ledger",
                    title: "Review imported transactions",
                    subtitle: "Classify and link transactions in the ledger.",
                    buttonTitle: "Open Ledger",
                    systemImage: "list.bullet.rectangle.portrait",
                    action: .openLedger(
                        accountId: latestTransaction.accountId,
                        transactionId: latestTransaction.id
                    )
                )
            )
        }

        if items.isEmpty {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "ready",
                    title: "Workspace looks healthy",
                    subtitle: "Use the sidebar to inspect details or import more data.",
                    buttonTitle: "Open Documents",
                    systemImage: "checkmark.circle",
                    action: .openDocuments(documentId: nil)
                )
            )
        }

        return items
    }

    var overviewPriorityAction: OverviewSnapshot.ActionItem? {
        overviewActionItems.first
    }

    var overviewSecondaryActions: [OverviewSnapshot.ActionItem] {
        Array(overviewActionItems.dropFirst().prefix(2))
    }

    var overviewAttentionItems: [OverviewSnapshot.AttentionItem] {
        let issueItems = issues
            .sorted { lhs, rhs in
                issuePriority(lhs.severity) > issuePriority(rhs.severity)
            }
            .prefix(3)
            .map { issue in
                OverviewSnapshot.AttentionItem(
                    id: issue.id.rawValue.uuidString,
                    title: shortIssueTitle(issue),
                    subtitle: entityName(for: issue.entityId) ?? "Workspace",
                    statusText: issue.severity == .blocking ? "Blocking" : "Pending",
                    tone: issue.severity == .blocking ? .critical : .warning,
                    systemImage: issue.severity == .blocking ? "exclamationmark.octagon" : "exclamationmark.triangle",
                    action: .openInbox(selection: .issue(issue.id))
                )
            }

        let proposalItems = agentProposals
            .filter { $0.status == .pending }
            .prefix(2)
            .map { proposal in
                OverviewSnapshot.AttentionItem(
                    id: proposal.id.rawValue.uuidString,
                    title: proposal.summary,
                    subtitle: proposal.rationale,
                    statusText: proposalConfidenceLabel(proposal.confidence),
                    tone: proposalConfidenceTone(proposal.confidence),
                    systemImage: "wand.and.stars",
                    action: .openInbox(selection: .proposal(proposal.id))
                )
            }

        let requirementItems = taxRequirements
            .prefix(2)
            .map { requirement in
                OverviewSnapshot.AttentionItem(
                    id: requirement.id.rawValue.uuidString,
                    title: shortRequirementTitle(requirement),
                    subtitle: entityName(for: requirement.entityId) ?? "Tax Studio",
                    statusText: "Missing",
                    tone: .warning,
                    systemImage: "list.bullet.clipboard",
                    action: .openTaxStudio(
                        entityId: requirement.entityId,
                        taxYearId: requirement.taxYearId,
                        factId: nil
                    )
                )
            }

        return Array((issueItems + proposalItems + requirementItems).prefix(4))
    }

    var overviewRecentActivityItems: [OverviewSnapshot.RecentActivityItem] {
        importJobs
            .sorted(by: importSortOrder)
            .prefix(4)
            .map { job in
                OverviewSnapshot.RecentActivityItem(
                    id: job.id.rawValue.uuidString,
                    title: job.source,
                    subtitle: "\(importKindLabel(job.kind)) • \(importTimestampLabel(job))",
                    statusText: importStatusLabel(job.status),
                    tone: tone(for: job.status)
                )
            }
    }

    var inboxRows: [InboxRowModel] {
        let issueRows = issues.map { issue in
            InboxRowModel(
                id: issue.id.rawValue.uuidString,
                selection: .issue(issue.id),
                tab: .issues,
                groupTitle: entityName(for: issue.entityId) ?? "Workspace",
                title: shortIssueTitle(issue),
                subtitle: issue.summary,
                meta: relativeDateString(for: issue.lastDetectedAt),
                statusText: issue.severity == .blocking ? "Blocking" : "Pending",
                tone: issue.severity == .blocking ? .critical : .warning,
                systemImage: issue.severity == .blocking ? "exclamationmark.octagon" : "exclamationmark.triangle",
                searchText: [issue.summary, entityName(for: issue.entityId) ?? "", issue.issueCode.rawValue].joined(separator: "\n")
            )
        }

        let proposalRows = agentProposals
            .filter { $0.status == .pending }
            .map { proposal in
                InboxRowModel(
                    id: proposal.id.rawValue.uuidString,
                    selection: .proposal(proposal.id),
                    tab: .proposals,
                    groupTitle: "Proposals",
                    title: proposal.summary,
                    subtitle: proposal.rationale,
                    meta: relativeDateString(for: proposal.createdAt),
                    statusText: proposalConfidenceLabel(proposal.confidence),
                    tone: proposalConfidenceTone(proposal.confidence),
                    systemImage: "wand.and.stars",
                    searchText: [proposal.summary, proposal.rationale, proposal.targetRef.stringValue].joined(separator: "\n")
                )
            }

        let importRows = importJobs.map { job in
            let diagnostics = importDiagnosticsByJobId[job.id] ?? []
            return InboxRowModel(
                id: job.id.rawValue.uuidString,
                selection: .importJob(job.id),
                tab: .imports,
                groupTitle: importKindLabel(job.kind),
                title: job.source,
                subtitle: diagnostics.isEmpty ? importKindLabel(job.kind) : importDiagnosticsSummary(diagnostics),
                meta: importTimestampLabel(job),
                statusText: importStatusLabel(job.status),
                tone: tone(for: job.status),
                systemImage: "tray.full",
                searchText: (
                    [job.source, importKindLabel(job.kind), importStatusLabel(job.status)] +
                    diagnostics.flatMap { [$0.code, $0.location ?? "", $0.message] }
                ).joined(separator: "\n")
            )
        }

        return issueRows + proposalRows + importRows
    }

    var inboxInspector: InboxInspectorModel? {
        guard let selection = selectedInboxSelection else { return nil }

        switch selection {
        case let .issue(issueId):
            guard let issue = issues.first(where: { $0.id == issueId }) else { return nil }
            return InboxInspectorModel(
                title: shortIssueTitle(issue),
                subtitle: entityName(for: issue.entityId) ?? "Workspace issue",
                statusText: issue.severity == .blocking ? "Blocking" : "Pending",
                tone: issue.severity == .blocking ? .critical : .warning,
                description: issue.summary,
                details: issueInspectorDetails(issue),
                evidence: issueInspectorEvidence(issue),
                actions: issueInspectorActions(issue)
            )
        case let .proposal(proposalId):
            guard let proposal = agentProposals.first(where: { $0.id == proposalId }) else { return nil }
            return InboxInspectorModel(
                title: proposal.summary,
                subtitle: "Proposal",
                statusText: proposal.status.rawValue.capitalized,
                tone: .info,
                description: proposal.rationale,
                details: proposalInspectorDetails(proposal),
                evidence: proposalInspectorEvidence(proposal),
                actions: proposalInspectorActions(proposal)
            )
        case let .importJob(importJobId):
            guard let job = importJobs.first(where: { $0.id == importJobId }) else { return nil }
            let diagnostics = importDiagnosticsByJobId[job.id] ?? []
            return InboxInspectorModel(
                title: job.source,
                subtitle: importKindLabel(job.kind),
                statusText: importStatusLabel(job.status),
                tone: tone(for: job.status),
                description: importInspectorDescription(job, diagnostics: diagnostics),
                details: importInspectorDetails(job, diagnostics: diagnostics),
                evidence: importInspectorEvidence(job),
                actions: importInspectorActions(job)
            )
        }
    }

    var taxChecklistItems: [TaxChecklistItem] {
        let issueItems = taxIssues.map { issue in
            TaxChecklistItem(
                id: "issue-\(issue.id.rawValue.uuidString)",
                selection: .issue(issue.id),
                title: shortIssueTitle(issue),
                subtitle: issue.summary,
                statusText: issue.severity == .blocking ? "Blocking" : "Pending",
                tone: issue.severity == .blocking ? .critical : .warning,
                systemImage: issue.severity == .blocking ? "exclamationmark.octagon" : "exclamationmark.triangle"
            )
        }

        let requirementItems = taxRequirements.map { requirement in
            TaxChecklistItem(
                id: "requirement-\(requirement.id.rawValue.uuidString)",
                selection: .requirement(requirement.id),
                title: shortRequirementTitle(requirement),
                subtitle: requirement.summary,
                statusText: "Missing",
                tone: .warning,
                systemImage: "list.bullet.clipboard"
            )
        }

        let missingFactItems = taxReadinessSummary.missingConceptCodes.map { conceptCode in
            TaxChecklistItem(
                id: "concept-\(conceptCode)",
                selection: .missingConcept(conceptCode),
                title: factLabel(for: conceptCode),
                subtitle: "Add this fact to advance readiness.",
                statusText: "Missing fact",
                tone: .warning,
                systemImage: "questionmark.circle"
            )
        }

        return issueItems + requirementItems + missingFactItems + vatIssueChecklistItems
    }

    var taxPeriodStatus: TaxPeriodStatusModel? {
        guard let selectedTaxYearId,
              let taxYear = taxYears.first(where: { $0.id == selectedTaxYearId })
        else {
            return nil
        }

        return TaxPeriodStatusModel(
            title: "\(taxYear.year) period status",
            detail: taxPeriodDetail(taxYear),
            statusText: taxYearStatusLabel(taxYear.status),
            tone: taxYearStatusTone(taxYear.status),
            canLock: taxYear.status == .open,
            canUnlock: taxYear.status == .locked
        )
    }

    var taxFactCategories: [TaxFactCategoryModel] {
        [
            makeTaxFactCategory(
                id: "personal-income",
                title: "Personal Income",
                prefix: "personal.income."
            ),
            makeTaxFactCategory(
                id: "deductions",
                title: "Deductions",
                prefix: "personal.deduction."
            ),
            makeTaxFactCategory(
                id: "self-employment",
                title: "Self-Employment",
                prefix: "personal.self_employment."
            ),
        ]
    }

    var taxInspector: TaxInspectorModel? {
        guard let selection = selectedTaxStudioSelection ?? selectedTaxFactId.map(TaxStudioSelection.fact) else {
            return nil
        }

        switch selection {
        case let .fact(factId):
            guard let fact = taxFacts.first(where: { $0.id == factId }) else { return nil }
            return TaxInspectorModel(
                title: factLabel(for: fact.conceptCode),
                subtitle: "Tax fact",
                statusText: fact.status.rawValue.capitalized,
                tone: statusTone(fact.status),
                details: [
                    TaxInspectorDetail(id: "value", label: "Value", value: valueString(for: fact)),
                    TaxInspectorDetail(id: "concept", label: "Concept", value: fact.conceptCode),
                    TaxInspectorDetail(id: "ruleset", label: "Ruleset", value: fact.rulesetVersion),
                ],
                evidence: fact.provenanceRefs.map { ref in
                    DocumentReferenceRowModel(
                        id: ref.stringValue,
                        title: provenanceTitle(for: ref),
                        subtitle: ref.stringValue,
                        systemImage: provenanceSymbol(for: ref)
                    )
                }
            )
        case let .issue(issueId):
            guard let issue = taxIssues.first(where: { $0.id == issueId }) else { return nil }
            return TaxInspectorModel(
                title: shortIssueTitle(issue),
                subtitle: "Tax issue",
                statusText: issue.status.rawValue.capitalized,
                tone: issue.severity == .blocking ? .critical : .warning,
                details: issueInspectorDetails(issue).map { TaxInspectorDetail(id: $0.id, label: $0.label, value: $0.value) },
                evidence: issue.relatedRef.map {
                    [DocumentReferenceRowModel(id: $0.stringValue, title: "Related object", subtitle: $0.stringValue, systemImage: "link")]
                } ?? []
            )
        case let .requirement(requirementId):
            guard let requirement = taxRequirements.first(where: { $0.id == requirementId }) else { return nil }
            return TaxInspectorModel(
                title: shortRequirementTitle(requirement),
                subtitle: "Requirement",
                statusText: requirement.status.rawValue.capitalized,
                tone: .warning,
                details: [
                    TaxInspectorDetail(id: "subject", label: "Subject", value: requirement.subjectRef.stringValue),
                    TaxInspectorDetail(id: "coverage", label: "Coverage", value: coverageLabel(start: requirement.coverageStart, end: requirement.coverageEnd)),
                ],
                evidence: requirement.satisfiedByRef.map {
                    [DocumentReferenceRowModel(id: $0.stringValue, title: "Satisfied by", subtitle: $0.stringValue, systemImage: "checkmark.circle")]
                } ?? []
            )
        case let .missingConcept(conceptCode):
            return TaxInspectorModel(
                title: factLabel(for: conceptCode),
                subtitle: "Missing fact",
                statusText: "Not provided",
                tone: .warning,
                details: [
                    TaxInspectorDetail(id: "concept", label: "Concept", value: conceptCode),
                    TaxInspectorDetail(id: "guidance", label: "Guidance", value: "Add evidence or fact data to continue."),
                ],
                evidence: []
            )
        case let .vatPeriod(periodId):
            guard let report = vatPeriodReports.first(where: { $0.period.id == periodId }) else { return nil }
            return TaxInspectorModel(
                title: vatPeriodTitle(report.period),
                subtitle: "VAT period",
                statusText: vatStatusText(report),
                tone: vatStatusTone(report),
                details: [
                    TaxInspectorDetail(id: "period", label: "Period", value: coverageLabel(start: report.period.periodStart, end: report.period.periodEnd)),
                    TaxInspectorDetail(id: "status", label: "Status", value: report.period.status.rawValue.capitalized),
                    TaxInspectorDetail(id: "outputTax", label: "Output tax", value: amountString(report.outputTaxMinor, currency: report.period.currency)),
                    TaxInspectorDetail(id: "inputTax", label: "Input tax", value: amountString(report.inputTaxMinor, currency: report.period.currency)),
                    TaxInspectorDetail(id: "payableTax", label: "Payable tax", value: amountString(report.netTaxPayableMinor, currency: report.period.currency)),
                    TaxInspectorDetail(id: "issues", label: "Issues", value: vatIssueSummary(report)),
                    TaxInspectorDetail(id: "ruleset", label: "Ruleset", value: report.rulesetVersion),
                ],
                evidence: report.lines.prefix(5).map { line in
                    let ref = ObjectRef(kind: .transaction, id: line.transactionId.rawValue)
                    return DocumentReferenceRowModel(
                        id: ref.stringValue,
                        title: "VAT transaction",
                        subtitle: ref.stringValue,
                        systemImage: "list.bullet.rectangle"
                    )
                }
            )
        case let .vatIssue(issueId):
            guard let context = vatIssueContext(for: issueId) else { return nil }
            let sourceRef = context.issue.sourceRef
            return TaxInspectorModel(
                title: shortVATIssueTitle(context.issue),
                subtitle: vatPeriodTitle(context.report.period),
                statusText: vatIssueStatusText(context.issue),
                tone: vatIssueTone(context.issue),
                details: [
                    TaxInspectorDetail(id: "message", label: "Issue", value: context.issue.message),
                    TaxInspectorDetail(id: "code", label: "Code", value: context.issue.code),
                    TaxInspectorDetail(id: "period", label: "Period", value: coverageLabel(start: context.report.period.periodStart, end: context.report.period.periodEnd)),
                    TaxInspectorDetail(id: "source", label: "Source", value: sourceRef?.stringValue ?? "VAT period"),
                ],
                evidence: sourceRef.map {
                    [DocumentReferenceRowModel(id: $0.stringValue, title: "Related object", subtitle: $0.stringValue, systemImage: provenanceSymbol(for: $0))]
                } ?? []
            )
        case let .filingPackage(packageId):
            guard let filingPackage = filingPackages.first(where: { $0.id == packageId }) else { return nil }
            let packageRef = ObjectRef(kind: .filingPackage, id: filingPackage.id.rawValue)
            return TaxInspectorModel(
                title: filingPackageTitle(filingPackage),
                subtitle: "Filing package",
                statusText: filingPackageStatusLabel(filingPackage.status),
                tone: filingPackageStatusTone(filingPackage.status),
                details: [
                    TaxInspectorDetail(
                        id: "boundary",
                        label: "Filing state",
                        value: filingPackageBoundaryText(filingPackage)
                    ),
                    TaxInspectorDetail(
                        id: "format",
                        label: "Export format",
                        value: filingPackage.exportFormat
                    ),
                    TaxInspectorDetail(
                        id: "generated",
                        label: "Generated",
                        value: formattedDate(filingPackage.generatedAt)
                    ),
                    TaxInspectorDetail(
                        id: "finalized",
                        label: "Finalized",
                        value: filingPackageFinalizationDetail(filingPackage)
                    ),
                    TaxInspectorDetail(
                        id: "submitted",
                        label: "Submitted",
                        value: formattedDate(filingPackage.submittedAt)
                    ),
                    TaxInspectorDetail(
                        id: "snapshot",
                        label: "Snapshot hash",
                        value: filingPackage.snapshotHash ?? "n/a"
                    ),
                ],
                evidence: [
                    DocumentReferenceRowModel(
                        id: packageRef.stringValue,
                        title: "Package record",
                        subtitle: packageRef.stringValue,
                        systemImage: "shippingbox"
                    ),
                ]
            )
        }
    }

    var latestImportSummary: String? {
        guard let latest = importJobs.sorted(by: importSortOrder).first else {
            return nil
        }
        return importTimestampLabel(latest)
    }

    var copilotContextSubtitle: String {
        let entity = selectedTaxEntityId.flatMap(entityName(for:)) ?? activeEntityId.flatMap(entityName(for:)) ?? "All entities"
        let taxYear = taxYears.first(where: { $0.id == selectedTaxYearId })
        let yearLabel = taxYear.map { "\($0.year)" } ?? "No tax year selected"
        let cantonLabel = taxYear?.canton?.rawValue ?? "No canton"
        return [entity, yearLabel, cantonLabel].joined(separator: " • ")
    }

    var copilotContextItems: [CopilotSnapshot.ContextItem] {
        [
            CopilotSnapshot.ContextItem(
                id: "entity",
                title: "Entity",
                value: selectedTaxEntityId.flatMap(entityName(for:)) ?? activeEntityId.flatMap(entityName(for:)) ?? "All",
                tone: .neutral,
                systemImage: "person.text.rectangle"
            ),
            CopilotSnapshot.ContextItem(
                id: "tax-year",
                title: "Tax Year",
                value: taxYears.first(where: { $0.id == selectedTaxYearId }).map { "\($0.year)" } ?? "n/a",
                tone: selectedTaxYearId == nil ? .warning : .info,
                systemImage: "calendar"
            ),
            CopilotSnapshot.ContextItem(
                id: "open-issues",
                title: "Open Issues",
                value: openIssueCount.formatted(),
                tone: openIssueCount == 0 ? .success : .critical,
                systemImage: "exclamationmark.bubble"
            ),
            CopilotSnapshot.ContextItem(
                id: "readiness",
                title: "Readiness",
                value: readinessTitle(taxReadinessSummary.state),
                tone: readinessTone(taxReadinessSummary.state),
                systemImage: "checkmark.shield"
            ),
        ]
    }

    var copilotPrompts: [CopilotSnapshot.PromptItem] {
        [
            CopilotSnapshot.PromptItem(
                id: "missing-tax-evidence",
                title: "What is missing for this return?",
                subtitle: "\(taxReadinessSummary.pendingRequirementCount) requirements, \(taxReadinessSummary.missingConceptCodes.count) missing facts",
                systemImage: "checklist",
                action: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
            ),
            CopilotSnapshot.PromptItem(
                id: "expenses-without-invoices",
                title: "Which expenses lack invoices?",
                subtitle: "\(missingExpenseEvidenceIssues.count) open evidence issue\(missingExpenseEvidenceIssues.count == 1 ? "" : "s")",
                systemImage: "doc.badge.clock",
                action: .openInbox(selection: missingExpenseEvidenceIssues.first.map { .issue($0.id) })
            ),
            CopilotSnapshot.PromptItem(
                id: "missing-monthly-extracts",
                title: "Which accounts still miss monthly extracts?",
                subtitle: "\(pendingStatementCoverageRequirements.count) statement gap\(pendingStatementCoverageRequirements.count == 1 ? "" : "s")",
                systemImage: "calendar.badge.exclamationmark",
                action: .openInbox(selection: missingStatementCoverageIssues.first.map { .issue($0.id) })
            ),
            CopilotSnapshot.PromptItem(
                id: "vat-due-high",
                title: "Why is VAT due high?",
                subtitle: vatPeriodReports.isEmpty ? "No VAT period in context" : "\(vatPeriodReports.count) VAT period\(vatPeriodReports.count == 1 ? "" : "s")",
                systemImage: "percent",
                action: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
            ),
            CopilotSnapshot.PromptItem(
                id: "business-tax-export",
                title: "Prepare my business tax export",
                subtitle: taxReadinessSummary.state == .readyForReview ? "Ready for review" : "Blockers still need review",
                systemImage: "shippingbox",
                action: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
            ),
        ]
    }

    var copilotTaxReadinessAnswer: CopilotSnapshot.AnswerCard {
        let taxYearRef = selectedTaxYearId.map { ObjectRef(kind: .taxYear, id: $0.rawValue) }
        let issueRefs = taxIssues.map { ObjectRef(kind: .issue, id: $0.id.rawValue) }
        let requirementRefs = taxRequirements.map { ObjectRef(kind: .requirement, id: $0.id.rawValue) }
        let fallbackRefs = copilotFallbackRefs(taxYearRef: taxYearRef)

        var claims: [CopilotSnapshot.ClaimItem] = [
            CopilotSnapshot.ClaimItem(
                id: "readiness-state",
                text: "Tax readiness is \(readinessTitle(taxReadinessSummary.state).lowercased()) for the selected context.",
                kind: .derivedValue,
                sourceRefs: taxYearRef.map { [$0] } ?? fallbackRefs
            ),
        ]
        if taxIssues.isEmpty == false {
            claims.append(
                CopilotSnapshot.ClaimItem(
                    id: "open-tax-issues",
                    text: "\(taxIssues.count) open tax issue\(taxIssues.count == 1 ? "" : "s") need review before filing confidence is high.",
                    kind: .missingInformation,
                    sourceRefs: issueRefs
                )
            )
        }
        if taxRequirements.isEmpty == false {
            claims.append(
                CopilotSnapshot.ClaimItem(
                    id: "pending-requirements",
                    text: "\(taxRequirements.count) evidence requirement\(taxRequirements.count == 1 ? "" : "s") are still pending.",
                    kind: .missingInformation,
                    sourceRefs: requirementRefs
                )
            )
        }
        if taxReadinessSummary.missingConceptCodes.isEmpty == false {
            claims.append(
                CopilotSnapshot.ClaimItem(
                    id: "missing-facts",
                    text: "Missing tax facts: \(taxReadinessSummary.missingConceptCodes.sorted().prefix(4).joined(separator: ", ")).",
                    kind: .missingInformation,
                    sourceRefs: taxYearRef.map { [$0] } ?? fallbackRefs
                )
            )
        }
        if claims.count == 1 && taxReadinessSummary.state == .readyForReview {
            claims.append(
                CopilotSnapshot.ClaimItem(
                    id: "ready",
                    text: "No open tax requirements or tax issues are present in the current readiness snapshot.",
                    kind: .observedFact,
                    sourceRefs: taxYearRef.map { [$0] } ?? fallbackRefs
                )
            )
        }

        let allRefs = claims.flatMap(\.sourceRefs)
        return CopilotSnapshot.AnswerCard(
            id: "missing-tax-evidence",
            question: "What is missing for this return?",
            summary: "Readiness, open tax issues, and pending evidence.",
            statusText: readinessTitle(taxReadinessSummary.state),
            tone: readinessTone(taxReadinessSummary.state),
            systemImage: "checklist",
            claims: claims,
            sources: copilotSources(for: allRefs),
            followUpQuestions: copilotTaxReadinessFollowUps(
                issueRefs: issueRefs,
                requirementRefs: requirementRefs,
                fallbackRefs: fallbackRefs
            ),
            primaryActionTitle: "Open Tax Studio",
            primaryAction: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId),
            secondaryActionTitle: "Turn Into Task",
            secondaryAction: copilotTaskAction(
                answerId: "missing-tax-evidence",
                title: "Review missing tax evidence",
                summary: "Review Copilot answer: What is missing for this return?",
                sourceRefs: allRefs
            )
        )
    }

    var copilotExpenseEvidenceAnswer: CopilotSnapshot.AnswerCard {
        let expenseIssues = missingExpenseEvidenceIssues
        let issueRefs = expenseIssues.map { ObjectRef(kind: .issue, id: $0.id.rawValue) }
        let transactionRefs = expenseIssues
            .map(\.objectRef)
            .filter { $0.kind == .transaction }
        let sourceRefs = issueRefs.isEmpty ? copilotFallbackRefs(taxYearRef: nil) : issueRefs + transactionRefs
        let claims: [CopilotSnapshot.ClaimItem]
        if expenseIssues.isEmpty {
            claims = [
                CopilotSnapshot.ClaimItem(
                    id: "no-open-expense-evidence",
                    text: "No open missing-expense-evidence issues are present for the current workspace snapshot.",
                    kind: .observedFact,
                    sourceRefs: sourceRefs
                ),
            ]
        } else {
            claims = [
                CopilotSnapshot.ClaimItem(
                    id: "open-expense-evidence",
                    text: "\(expenseIssues.count) business expense\(expenseIssues.count == 1 ? "" : "s") still lack linked invoice or receipt evidence.",
                    kind: .missingInformation,
                    sourceRefs: sourceRefs
                ),
            ]
        }

        return CopilotSnapshot.AnswerCard(
            id: "expenses-without-invoices",
            question: "Which expenses lack invoices?",
            summary: "Open evidence issues tied to expense records.",
            statusText: expenseIssues.isEmpty ? "Clear" : "\(expenseIssues.count) open",
            tone: expenseIssues.isEmpty ? .success : .critical,
            systemImage: "doc.badge.clock",
            claims: claims,
            sources: copilotSources(for: sourceRefs),
            followUpQuestions: copilotExpenseEvidenceFollowUps(expenseIssues),
            primaryActionTitle: "Open Inbox",
            primaryAction: .openInbox(selection: expenseIssues.first.map { .issue($0.id) }),
            secondaryActionTitle: "Turn Into Task",
            secondaryAction: copilotTaskAction(
                answerId: "expenses-without-invoices",
                title: "Review expenses without invoices",
                summary: "Review Copilot answer: Which expenses lack invoices?",
                sourceRefs: sourceRefs
            )
        )
    }

    var copilotStatementCoverageAnswer: CopilotSnapshot.AnswerCard {
        let requirements = statementCoverageRequirements
        let pendingRequirements = pendingStatementCoverageRequirements
        let satisfiedRequirements = requirements.filter { $0.status == .satisfied }
        let openIssues = missingStatementCoverageIssues
        let requirementRefs = requirements.map { ObjectRef(kind: .requirement, id: $0.id.rawValue) }
        let pendingRequirementRefs = pendingRequirements.map { ObjectRef(kind: .requirement, id: $0.id.rawValue) }
        let accountRefs = requirements
            .map(\.subjectRef)
            .filter { $0.kind == .financialAccount }
        let issueRefs = openIssues.map { ObjectRef(kind: .issue, id: $0.id.rawValue) }
        let statementImportRefs = requirements
            .compactMap(\.satisfiedByRef)
            .filter { $0.kind == .statementImport }
        let fallbackRefs = copilotFallbackRefs(
            taxYearRef: selectedTaxYearId.map { ObjectRef(kind: .taxYear, id: $0.rawValue) }
        )

        var claims: [CopilotSnapshot.ClaimItem] = []
        if requirements.isEmpty {
            claims.append(
                CopilotSnapshot.ClaimItem(
                    id: "no-statement-coverage-requirements",
                    text: "No statement-coverage requirements are present for the selected context, so monthly extract completeness is not proven yet.",
                    kind: .missingInformation,
                    sourceRefs: fallbackRefs
                )
            )
        } else if pendingRequirements.isEmpty {
            claims.append(
                CopilotSnapshot.ClaimItem(
                    id: "statement-coverage-clear",
                    text: "No accounts have open monthly statement coverage gaps in the current snapshot.",
                    kind: .observedFact,
                    sourceRefs: requirementRefs + accountRefs + statementImportRefs
                )
            )
        } else {
            claims.append(
                CopilotSnapshot.ClaimItem(
                    id: "pending-statement-coverage",
                    text: "\(pendingRequirements.count) statement coverage requirement\(pendingRequirements.count == 1 ? "" : "s") are still pending across \(statementCoverageAccountCount(for: pendingRequirements)) account\(statementCoverageAccountCount(for: pendingRequirements) == 1 ? "" : "s").",
                    kind: .missingInformation,
                    sourceRefs: pendingRequirementRefs + accountRefs + issueRefs
                )
            )
            claims.append(
                CopilotSnapshot.ClaimItem(
                    id: "pending-statement-coverage-examples",
                    text: "First gaps: \(pendingRequirements.prefix(3).map(statementCoverageGapLabel).joined(separator: "; ")).",
                    kind: .observedFact,
                    sourceRefs: pendingRequirementRefs + issueRefs
                )
            )
        }

        if satisfiedRequirements.isEmpty == false {
            claims.append(
                CopilotSnapshot.ClaimItem(
                    id: "satisfied-statement-coverage",
                    text: "\(satisfiedRequirements.count) statement coverage requirement\(satisfiedRequirements.count == 1 ? "" : "s") are already satisfied by imported statements.",
                    kind: .observedFact,
                    sourceRefs: satisfiedRequirements.map { ObjectRef(kind: .requirement, id: $0.id.rawValue) } + statementImportRefs
                )
            )
        }

        let refs = claims.flatMap(\.sourceRefs)
        return CopilotSnapshot.AnswerCard(
            id: "missing-monthly-extracts",
            question: "Which accounts still miss monthly extracts?",
            summary: "Statement coverage requirements, open issues, and imported-statement evidence.",
            statusText: pendingRequirements.isEmpty ? (requirements.isEmpty ? "Not proven" : "Clear") : "\(pendingRequirements.count) missing",
            tone: pendingRequirements.isEmpty ? (requirements.isEmpty ? .neutral : .success) : .critical,
            systemImage: "calendar.badge.exclamationmark",
            claims: claims,
            sources: copilotSources(for: refs),
            followUpQuestions: copilotStatementCoverageFollowUps(
                requirements: requirements,
                pendingRequirements: pendingRequirements,
                fallbackRefs: fallbackRefs
            ),
            primaryActionTitle: pendingRequirements.isEmpty ? "Open Ledger" : "Open Missing Statement",
            primaryAction: openIssues.first
                .map { .openInbox(selection: .issue($0.id)) }
                ?? .openLedger(accountId: pendingRequirements.first.flatMap(financialAccountIdForRequirement), transactionId: nil),
            secondaryActionTitle: "Turn Into Task",
            secondaryAction: copilotTaskAction(
                answerId: "missing-monthly-extracts",
                title: "Review missing monthly extracts",
                summary: "Review Copilot answer: Which accounts still miss monthly extracts?",
                sourceRefs: refs
            )
        )
    }

    var copilotVATAnswer: CopilotSnapshot.AnswerCard {
        guard let report = vatPeriodReports.max(by: { abs($0.netTaxPayableMinor) < abs($1.netTaxPayableMinor) }) else {
            let refs = copilotFallbackRefs(taxYearRef: selectedTaxYearId.map { ObjectRef(kind: .taxYear, id: $0.rawValue) })
            return CopilotSnapshot.AnswerCard(
                id: "vat-due-high",
                question: "Why is VAT due high?",
                summary: "No VAT period is available in the selected context.",
                statusText: "No period",
                tone: .neutral,
                systemImage: "percent",
                claims: [
                    CopilotSnapshot.ClaimItem(
                        id: "no-vat-period",
                        text: "No VAT reconciliation period is available for the selected entity and tax year.",
                        kind: .missingInformation,
                        sourceRefs: refs
                    ),
                ],
                sources: copilotSources(for: refs),
                followUpQuestions: [
                    CopilotSnapshot.FollowUpQuestion(
                        id: "choose-vat-period",
                        text: "Which VAT period should be prepared for this entity?",
                        sourceRefs: refs,
                        primaryActionTitle: "Open Tax Studio",
                        primaryAction: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
                    ),
                ],
                primaryActionTitle: "Open Tax Studio",
                primaryAction: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId),
                secondaryActionTitle: "Turn Into Task",
                secondaryAction: copilotTaskAction(
                    answerId: "vat-due-high",
                    title: "Review VAT explanation",
                    summary: "Review Copilot answer: Why is VAT due high?",
                    sourceRefs: refs
                )
            )
        }

        let periodRef = ObjectRef(kind: .vatPeriod, id: report.period.id.rawValue)
        let issueRefs = report.issues.compactMap(\.sourceRef)
        let lineRefs = report.lines
            .sorted { abs($0.vatAmountMinor) > abs($1.vatAmountMinor) }
            .prefix(3)
            .map { ObjectRef(kind: .transaction, id: $0.transactionId.rawValue) }
        let sourceRefs = [periodRef] + issueRefs + lineRefs
        let tone: StatusBadge.Tone = report.blockerCount > 0 ? .critical : (report.issues.isEmpty ? .success : .warning)

        return CopilotSnapshot.AnswerCard(
            id: "vat-due-high",
            question: "Why is VAT due high?",
            summary: vatPeriodTitle(report.period),
            statusText: amountString(report.netTaxPayableMinor, currency: report.period.currency),
            tone: tone,
            systemImage: "percent",
            claims: [
                CopilotSnapshot.ClaimItem(
                    id: "vat-net",
                    text: "Net VAT payable is \(amountString(report.netTaxPayableMinor, currency: report.period.currency)) for \(vatPeriodTitle(report.period)).",
                    kind: .derivedValue,
                    sourceRefs: [periodRef]
                ),
                CopilotSnapshot.ClaimItem(
                    id: "vat-components",
                    text: "Output tax is \(amountString(report.outputTaxMinor, currency: report.period.currency)); input tax is \(amountString(report.inputTaxMinor, currency: report.period.currency)).",
                    kind: .derivedValue,
                    sourceRefs: [periodRef] + lineRefs
                ),
                CopilotSnapshot.ClaimItem(
                    id: "vat-issues",
                    text: report.issues.isEmpty
                        ? "No VAT reconciliation issues are attached to this period."
                        : "\(report.issues.count) VAT reconciliation issue\(report.issues.count == 1 ? "" : "s") may affect the explanation.",
                    kind: report.issues.isEmpty ? .observedFact : .missingInformation,
                    sourceRefs: issueRefs.isEmpty ? [periodRef] : issueRefs
                ),
            ],
            sources: copilotSources(for: sourceRefs),
            followUpQuestions: copilotVATFollowUps(report: report, sourceRefs: sourceRefs),
            primaryActionTitle: "Open VAT Period",
            primaryAction: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId),
            secondaryActionTitle: "Turn Into Task",
            secondaryAction: copilotTaskAction(
                answerId: "vat-due-high",
                title: "Review VAT explanation",
                summary: "Review Copilot answer: Why is VAT due high?",
                sourceRefs: sourceRefs
            )
        )
    }

    var copilotBusinessExportAnswer: CopilotSnapshot.AnswerCard {
        let taxYearRef = selectedTaxYearId.map { ObjectRef(kind: .taxYear, id: $0.rawValue) }
        let issueRefs = (taxIssues.isEmpty ? issues : taxIssues).map { ObjectRef(kind: .issue, id: $0.id.rawValue) }
        let refs = issueRefs.isEmpty ? copilotFallbackRefs(taxYearRef: taxYearRef) : issueRefs
        let isBlocked = taxReadinessSummary.state != .readyForReview || issueRefs.isEmpty == false

        return CopilotSnapshot.AnswerCard(
            id: "business-tax-export",
            question: "Prepare my business tax export",
            summary: "Export readiness is based on validation status and blockers.",
            statusText: isBlocked ? "Blocked" : "Ready",
            tone: isBlocked ? .warning : .success,
            systemImage: "shippingbox",
            claims: [
                CopilotSnapshot.ClaimItem(
                    id: "export-readiness",
                    text: isBlocked
                        ? "The export should stay in review until open blockers and missing readiness inputs are resolved."
                        : "The current readiness snapshot is ready for review before draft export generation.",
                    kind: isBlocked ? .missingInformation : .derivedValue,
                    sourceRefs: refs
                ),
                CopilotSnapshot.ClaimItem(
                    id: "export-boundary",
                    text: "Draft packages can be generated for review; finalization still requires explicit approval.",
                    kind: .agentSuggestion,
                    sourceRefs: refs
                ),
            ],
            sources: copilotSources(for: refs),
            followUpQuestions: copilotBusinessExportFollowUps(isBlocked: isBlocked, sourceRefs: refs),
            primaryActionTitle: "Open Tax Studio",
            primaryAction: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId),
            secondaryActionTitle: "Turn Into Task",
            secondaryAction: copilotTaskAction(
                answerId: "business-tax-export",
                title: "Review business tax export readiness",
                summary: "Review Copilot answer: Prepare my business tax export",
                sourceRefs: refs
            )
        )
    }

    func copilotTaxReadinessFollowUps(
        issueRefs: [ObjectRef],
        requirementRefs: [ObjectRef],
        fallbackRefs: [ObjectRef]
    ) -> [CopilotSnapshot.FollowUpQuestion] {
        var questions: [CopilotSnapshot.FollowUpQuestion] = []

        if let firstIssue = taxIssues.first {
            let issueRef = ObjectRef(kind: .issue, id: firstIssue.id.rawValue)
            questions.append(
                CopilotSnapshot.FollowUpQuestion(
                    id: "review-tax-issue",
                    text: "Can you resolve or dismiss the first open tax issue before treating this return as ready?",
                    sourceRefs: issueRefs.isEmpty ? [issueRef] : issueRefs,
                    primaryActionTitle: "Open Issue",
                    primaryAction: .openInbox(selection: .issue(firstIssue.id))
                )
            )
        }

        if let firstRequirement = taxRequirements.first(where: { $0.status == .pending }) {
            let requirementRef = ObjectRef(kind: .requirement, id: firstRequirement.id.rawValue)
            questions.append(
                CopilotSnapshot.FollowUpQuestion(
                    id: "satisfy-tax-requirement",
                    text: "Can you add or link evidence for the first pending tax requirement?",
                    sourceRefs: requirementRefs.isEmpty ? [requirementRef] : requirementRefs,
                    primaryActionTitle: "Open Tax Studio",
                    primaryAction: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
                )
            )
        }

        if taxReadinessSummary.missingConceptCodes.isEmpty == false {
            questions.append(
                CopilotSnapshot.FollowUpQuestion(
                    id: "complete-missing-tax-facts",
                    text: "Which source document should provide the missing tax fact values?",
                    sourceRefs: fallbackRefs,
                    primaryActionTitle: "Open Tax Studio",
                    primaryAction: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
                )
            )
        }

        return questions
    }

    func copilotExpenseEvidenceFollowUps(_ expenseIssues: [Issue]) -> [CopilotSnapshot.FollowUpQuestion] {
        guard let firstIssue = expenseIssues.first else { return [] }
        let issueRef = ObjectRef(kind: .issue, id: firstIssue.id.rawValue)
        let refs = [issueRef, firstIssue.objectRef]

        return [
            CopilotSnapshot.FollowUpQuestion(
                id: "attach-expense-evidence",
                text: "Can you attach the invoice or receipt for the first unsupported business expense?",
                sourceRefs: refs,
                primaryActionTitle: "Open Issue",
                primaryAction: .openInbox(selection: .issue(firstIssue.id))
            ),
        ]
    }

    func copilotStatementCoverageFollowUps(
        requirements: [Requirement],
        pendingRequirements: [Requirement],
        fallbackRefs: [ObjectRef]
    ) -> [CopilotSnapshot.FollowUpQuestion] {
        guard requirements.isEmpty == false else {
            return [
                CopilotSnapshot.FollowUpQuestion(
                    id: "define-statement-coverage",
                    text: "Which account coverage cadence should be expected for this tax year?",
                    sourceRefs: fallbackRefs,
                    primaryActionTitle: "Open Tax Studio",
                    primaryAction: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
                ),
            ]
        }

        guard let firstPending = pendingRequirements.first else { return [] }
        let requirementRef = ObjectRef(kind: .requirement, id: firstPending.id.rawValue)
        let relatedIssue = missingStatementCoverageIssues.first { issue in
            issue.relatedRef == requirementRef || issue.objectRef == firstPending.subjectRef
        }
        var refs = [requirementRef, firstPending.subjectRef]
        if let relatedIssue {
            refs.append(ObjectRef(kind: .issue, id: relatedIssue.id.rawValue))
        }

        return [
            CopilotSnapshot.FollowUpQuestion(
                id: "import-missing-statement",
                text: "Can you import the missing statement for \(statementCoverageGapLabel(firstPending))?",
                sourceRefs: refs,
                primaryActionTitle: relatedIssue == nil ? "Open Ledger" : "Open Issue",
                primaryAction: relatedIssue.map { .openInbox(selection: .issue($0.id)) }
                    ?? .openLedger(accountId: financialAccountIdForRequirement(firstPending), transactionId: nil)
            ),
        ]
    }

    func copilotVATFollowUps(
        report: VATReconciliationReport,
        sourceRefs: [ObjectRef]
    ) -> [CopilotSnapshot.FollowUpQuestion] {
        guard report.issues.isEmpty == false else { return [] }
        return [
            CopilotSnapshot.FollowUpQuestion(
                id: "review-vat-issue",
                text: "Can you review the VAT reconciliation issue before relying on this explanation?",
                sourceRefs: sourceRefs,
                primaryActionTitle: "Open VAT Period",
                primaryAction: .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
            ),
        ]
    }

    func copilotBusinessExportFollowUps(
        isBlocked: Bool,
        sourceRefs: [ObjectRef]
    ) -> [CopilotSnapshot.FollowUpQuestion] {
        guard isBlocked else { return [] }
        let firstIssue = taxIssues.first ?? issues.first
        return [
            CopilotSnapshot.FollowUpQuestion(
                id: "resolve-export-blocker",
                text: "Can you resolve the first blocker before generating the draft export package?",
                sourceRefs: sourceRefs,
                primaryActionTitle: firstIssue == nil ? "Open Tax Studio" : "Open Issue",
                primaryAction: firstIssue.map { .openInbox(selection: .issue($0.id)) }
                    ?? .openTaxStudio(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
            ),
        ]
    }

    var missingExpenseEvidenceIssues: [Issue] {
        issues
            .filter { $0.issueCode == .missingExpenseEvidence && $0.status == .open }
            .sorted { lhs, rhs in
                if issuePriority(lhs.severity) != issuePriority(rhs.severity) {
                    return issuePriority(lhs.severity) > issuePriority(rhs.severity)
                }
                return lhs.lastDetectedAt > rhs.lastDetectedAt
            }
    }

    var statementCoverageRequirements: [Requirement] {
        taxRequirements
            .filter { requirement in
                guard requirement.requirementCode == .statementCoverage else { return false }
                if let selectedTaxEntityId, requirement.entityId != selectedTaxEntityId {
                    return false
                }
                if let selectedTaxYearId, requirement.taxYearId != selectedTaxYearId {
                    return false
                }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status == .pending
                }
                let lhsStart = lhs.coverageStart ?? .distantPast
                let rhsStart = rhs.coverageStart ?? .distantPast
                if lhsStart != rhsStart {
                    return lhsStart < rhsStart
                }
                return statementCoverageGapLabel(lhs) < statementCoverageGapLabel(rhs)
            }
    }

    var pendingStatementCoverageRequirements: [Requirement] {
        statementCoverageRequirements.filter { $0.status == .pending }
    }

    var missingStatementCoverageIssues: [Issue] {
        issues
            .filter { issue in
                guard issue.issueCode == .missingStatementCoverage && issue.status == .open else { return false }
                if let selectedTaxEntityId, issue.entityId != selectedTaxEntityId {
                    return false
                }
                if let selectedTaxYearId, issue.taxYearId != selectedTaxYearId {
                    return false
                }
                return true
            }
            .sorted { lhs, rhs in
                if issuePriority(lhs.severity) != issuePriority(rhs.severity) {
                    return issuePriority(lhs.severity) > issuePriority(rhs.severity)
                }
                return lhs.lastDetectedAt > rhs.lastDetectedAt
            }
    }

    func financialAccountIdForRequirement(_ requirement: Requirement) -> FinancialAccountID? {
        financialAccountId(from: requirement.subjectRef)
    }

    func statementCoverageAccountCount(for requirements: [Requirement]) -> Int {
        Set(requirements.compactMap(financialAccountIdForRequirement)).count
    }

    func statementCoverageGapLabel(_ requirement: Requirement) -> String {
        let accountName = financialAccountIdForRequirement(requirement)
            .flatMap { accountId in financialAccounts.first(where: { $0.id == accountId })?.displayName }
            ?? "Unknown account"
        return "\(accountName) (\(coverageLabel(start: requirement.coverageStart, end: requirement.coverageEnd)))"
    }

    func copilotFallbackRefs(taxYearRef: ObjectRef?) -> [ObjectRef] {
        if let taxYearRef {
            return [taxYearRef]
        }
        if let selectedTaxEntityId {
            return [ObjectRef(kind: .legalEntity, id: selectedTaxEntityId.rawValue)]
        }
        if let activeEntityId {
            return [ObjectRef(kind: .legalEntity, id: activeEntityId.rawValue)]
        }
        if let workspaceId = session?.storage.manifest.workspace.id {
            return [ObjectRef(kind: .workspace, id: workspaceId.rawValue)]
        }
        return []
    }

    func copilotTaskAction(
        answerId: String,
        title: String,
        summary: String,
        sourceRefs: [ObjectRef]
    ) -> CopilotAction {
        .createTaskFromAnswer(
            CopilotTaskDraft(
                answerId: answerId,
                title: title,
                summary: summary,
                sourceRef: sourceRefs.first ?? copilotFallbackRefs(
                    taxYearRef: selectedTaxYearId.map { ObjectRef(kind: .taxYear, id: $0.rawValue) }
                ).first,
                entityId: selectedTaxEntityId ?? activeEntityId,
                taxYearId: selectedTaxYearId
            )
        )
    }

    func copilotSources(for refs: [ObjectRef]) -> [CopilotSnapshot.SourceItem] {
        var seenRefs = Set<ObjectRef>()
        return refs.compactMap { ref in
            guard seenRefs.insert(ref).inserted else { return nil }
            return CopilotSnapshot.SourceItem(
                title: provenanceTitle(for: ref),
                subtitle: ref.stringValue,
                systemImage: provenanceSymbol(for: ref),
                ref: ref
            )
        }
    }

    var selectedAccountName: String? {
        financialAccounts.first(where: { $0.id == selectedAccountId })?.displayName
    }

    var firstOpenIssueSelection: InboxSelection? {
        issues
            .sorted { lhs, rhs in
                issuePriority(lhs.severity) > issuePriority(rhs.severity)
            }
            .first
            .map { .issue($0.id) }
    }

    var firstPendingProposalSelection: InboxSelection? {
        agentProposals
            .filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
            .first
            .map { .proposal($0.id) }
    }

    // MARK: - Supporting methods

    func issueInspectorDetails(_ issue: Issue) -> [InboxInspectorDetail] {
        var details = [
            InboxInspectorDetail(id: "status", label: "Status", value: issue.status.rawValue.capitalized),
            InboxInspectorDetail(id: "object", label: "Object", value: issue.objectRef.stringValue),
        ]
        if let relatedRef = issue.relatedRef {
            details.append(InboxInspectorDetail(id: "related", label: "Related", value: relatedRef.stringValue))
        }
        return details
    }

    func issueInspectorActions(_ issue: Issue) -> [InboxInspectorAction] {
        var actions = [
            InboxInspectorAction(
                id: "resolve-\(issue.id.rawValue.uuidString)",
                title: "Resolve",
                role: .primary,
                action: .resolveIssue(issue.id)
            ),
            InboxInspectorAction(
                id: "dismiss-\(issue.id.rawValue.uuidString)",
                title: "Dismiss",
                role: .destructive,
                action: .dismissIssue(issue.id)
            ),
        ]

        switch issue.issueCode {
        case .missingStatementCoverage:
            let accountId = financialAccountId(from: issue.objectRef)
            actions.append(
                InboxInspectorAction(
                    id: "import-\(issue.id.rawValue.uuidString)",
                    title: "Import Statement…",
                    role: .secondary,
                    action: .importStatement(accountId)
                )
            )
        case .missingExpenseEvidence:
            if let transactionId = transactionId(from: issue.objectRef) {
                actions.append(
                    InboxInspectorAction(
                        id: "link-\(issue.id.rawValue.uuidString)",
                        title: "Link Document…",
                        role: .secondary,
                        action: .linkDocument(transactionId)
                    )
                )
            }
        case .copilotTask:
            break
        }

        return actions
    }

    func proposalInspectorDetails(_ proposal: AgentProposal) -> [InboxInspectorDetail] {
        var details = [
            InboxInspectorDetail(id: "status", label: "Status", value: proposal.status.rawValue.capitalized),
            InboxInspectorDetail(id: "confidence", label: "Confidence", value: proposalConfidenceLabel(proposal.confidence)),
            InboxInspectorDetail(id: "reviewPath", label: "Review path", value: proposalReviewPath(proposal)),
            InboxInspectorDetail(id: "target", label: "Target", value: proposal.targetRef.stringValue),
        ]
        if proposal.missingFields.isEmpty == false {
            details.append(InboxInspectorDetail(id: "missingFields", label: "Missing fields", value: proposal.missingFields.joined(separator: ", ")))
        }
        if let question = proposal.question {
            details.append(InboxInspectorDetail(id: "question", label: "Question", value: question))
        }
        if let relatedRef = proposal.relatedRef {
            details.append(InboxInspectorDetail(id: "related", label: "Related", value: relatedRef.stringValue))
        }
        if let decidedAt = proposal.decidedAt {
            details.append(InboxInspectorDetail(id: "decidedAt", label: "Decided", value: relativeDateString(for: decidedAt)))
        }
        if let decidedBy = proposal.decidedBy {
            details.append(InboxInspectorDetail(id: "decidedBy", label: "Decided by", value: decidedBy))
        }
        if let decisionReason = proposal.decisionReason {
            details.append(InboxInspectorDetail(id: "decisionReason", label: "Decision reason", value: decisionReason))
        }
        return details
    }

    func issueInspectorEvidence(_ issue: Issue) -> [DocumentReferenceRowModel] {
        var refs = [issue.objectRef]
        if let relatedRef = issue.relatedRef {
            refs.append(relatedRef)
        }
        return provenanceRows(for: refs)
    }

    func proposalInspectorEvidence(_ proposal: AgentProposal) -> [DocumentReferenceRowModel] {
        var refs = [
            ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
            proposal.targetRef,
        ]
        if let relatedRef = proposal.relatedRef {
            refs.append(relatedRef)
        }
        return provenanceRows(for: refs)
    }

    func importInspectorEvidence(_ job: ImportJob) -> [DocumentReferenceRowModel] {
        provenanceRows(for: [ObjectRef(kind: .importJob, id: job.id.rawValue)])
    }

    func importInspectorDetails(
        _ job: ImportJob,
        diagnostics: [ImportDiagnostic]
    ) -> [InboxInspectorDetail] {
        var details = [
            InboxInspectorDetail(id: "status", label: "Status", value: importStatusLabel(job.status)),
            InboxInspectorDetail(id: "kind", label: "Kind", value: importKindLabel(job.kind)),
            InboxInspectorDetail(id: "parser", label: "Parser", value: "\(job.parserKey) \(job.parserVersion)"),
            InboxInspectorDetail(
                id: "startedAt",
                label: "Started",
                value: job.startedAt.formatted(date: .abbreviated, time: .shortened)
            ),
            InboxInspectorDetail(id: "warnings", label: "Warnings", value: job.warningCount.formatted()),
        ]
        if let completedAt = job.completedAt {
            details.append(InboxInspectorDetail(
                id: "completedAt",
                label: "Completed",
                value: completedAt.formatted(date: .abbreviated, time: .shortened)
            ))
        }
        details.append(InboxInspectorDetail(
            id: "sourceBlob",
            label: "Stored source",
            value: job.sourceBlobHash == nil ? "Unavailable" : "Available"
        ))
        if let sourceFingerprint = job.sourceFingerprint, sourceFingerprint.isEmpty == false {
            details.append(InboxInspectorDetail(
                id: "sourceFingerprint",
                label: "Source fingerprint",
                value: sourceFingerprint
            ))
        }
        if jobCanRetry(job) {
            details.append(InboxInspectorDetail(
                id: "retry",
                label: "Retry",
                value: "Available from stored source"
            ))
        }
        let errorCount = diagnostics.filter { $0.severity == .error }.count
        if errorCount > 0 {
            details.append(InboxInspectorDetail(id: "errors", label: "Errors", value: errorCount.formatted()))
        }
        if diagnostics.isEmpty == false {
            details.append(InboxInspectorDetail(id: "diagnostics", label: "Diagnostics", value: importDiagnosticsSummary(diagnostics)))
        }
        details.append(contentsOf: diagnostics.prefix(6).map { diagnostic in
            InboxInspectorDetail(
                id: "diagnostic-\(diagnostic.id.rawValue.uuidString)",
                label: importDiagnosticLabel(diagnostic),
                value: diagnostic.message
            )
        })
        if diagnostics.count > 6 {
            details.append(InboxInspectorDetail(
                id: "diagnostic-overflow",
                label: "More diagnostics",
                value: "\(diagnostics.count - 6) additional item(s)"
            ))
        }
        return details
    }

    func importInspectorDescription(
        _ job: ImportJob,
        diagnostics: [ImportDiagnostic]
    ) -> String {
        if jobCanRetry(job) {
            return diagnostics.isEmpty
                ? "This import did not complete. Retry it from the stored local source when the selected account is correct."
                : "This import did not complete. Review parser diagnostics, then retry it from the stored local source when the selected account is correct."
        }
        return diagnostics.isEmpty
            ? "Use the document or ledger views to continue review."
            : "Review parser diagnostics before relying on this import."
    }

    func importInspectorActions(_ job: ImportJob) -> [InboxInspectorAction] {
        guard jobCanRetry(job) else { return [] }
        return [
            InboxInspectorAction(
                id: "retry-\(job.id.rawValue.uuidString)",
                title: "Retry Import",
                role: .primary,
                action: .retryImport(job.id)
            ),
        ]
    }

    func jobCanRetry(_ job: ImportJob) -> Bool {
        guard job.status == .failed || job.status == .cancelled else { return false }
        guard financialAccounts.isEmpty == false else { return false }
        guard job.sourceBlobHash?.isEmpty == false else { return false }
        switch job.kind {
        case .bankStatementCSV, .bankStatementCAMT:
            return true
        case .documentIntake:
            return false
        }
    }

    func proposalInspectorActions(_ proposal: AgentProposal) -> [InboxInspectorAction] {
        var actions: [InboxInspectorAction] = []
        let isActionableDocumentMatch = proposal.status == .pending &&
            proposal.targetRef.kind == .document &&
            proposal.relatedRef?.kind == .transaction
        let canApproveDirectly = isActionableDocumentMatch &&
            proposalAllowsDirectApproval(proposal)
        let isRevocableDocumentMatch = proposal.status == .resolved &&
            proposal.targetRef.kind == .document &&
            proposal.relatedRef?.kind == .transaction

        if canApproveDirectly {
            actions.append(
                InboxInspectorAction(
                    id: "approve-\(proposal.id.rawValue.uuidString)",
                    title: "Approve",
                    role: .primary,
                    action: .approveProposal(proposal.id)
                )
            )
        }

        if isRevocableDocumentMatch {
            actions.append(
                InboxInspectorAction(
                    id: "revoke-\(proposal.id.rawValue.uuidString)",
                    title: "Revoke",
                    role: .destructive,
                    action: .revokeProposalApproval(proposal.id)
                )
            )
        }

        actions.append(
            InboxInspectorAction(
                id: "open-\(proposal.id.rawValue.uuidString)",
                title: "Open",
                role: canApproveDirectly || isRevocableDocumentMatch ? .secondary : .primary,
                action: .openProposalTarget(proposal.targetRef)
            )
        )

        if proposal.status == .pending {
            actions.append(
                InboxInspectorAction(
                    id: "reject-\(proposal.id.rawValue.uuidString)",
                    title: "Reject",
                    role: .destructive,
                    action: .rejectProposal(proposal.id)
                )
            )
        }

        if proposal.status == .pending,
           proposal.targetRef.kind == .document,
           let documentId = documentId(from: proposal.targetRef) {
            actions.append(
                InboxInspectorAction(
                    id: "link-\(proposal.id.rawValue.uuidString)",
                    title: "Link Transaction…",
                    role: .secondary,
                    action: .linkTransaction(documentId)
                )
            )
        }

        return actions
    }

    func makeTaxFactCategory(id: String, title: String, prefix: String) -> TaxFactCategoryModel {
        let items = taxFacts
            .filter { $0.conceptCode.hasPrefix(prefix) }
            .map { fact in
                TaxFactRowModel(
                    id: fact.id,
                    selection: .fact(fact.id),
                    title: factLabel(for: fact.conceptCode),
                    value: valueString(for: fact),
                    statusText: fact.status.rawValue.capitalized,
                    tone: statusTone(fact.status),
                    systemImage: symbol(for: fact.status)
                )
            }
        let completionText = items.isEmpty ? "No data yet" : "\(items.count) fact\(items.count == 1 ? "" : "s")"
        return TaxFactCategoryModel(id: id, title: title, completionText: completionText, items: items)
    }

    var taxReadinessSummaryText: String {
        var parts = [
            "\(taxReadinessSummary.openIssueCount) open issues",
            "\(taxReadinessSummary.pendingRequirementCount) pending requirements",
        ]
        let vatIssueCount = vatPeriodReports.reduce(0) { $0 + $1.issues.count }
        if vatIssueCount > 0 {
            parts.append("\(vatIssueCount) VAT issue\(vatIssueCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: " • ")
    }

    var taxReadinessTone: StatusBadge.Tone {
        if vatPeriodReports.contains(where: { $0.blockerCount > 0 }) {
            return .critical
        }
        if vatPeriodReports.contains(where: { $0.issues.isEmpty == false }) {
            return .warning
        }
        return readinessTone(taxReadinessSummary.state)
    }

    var taxStudioVATPeriods: [TaxStudioVATPeriodModel] {
        vatPeriodReports
            .sorted { $0.period.periodStart > $1.period.periodStart }
            .map { report in
                TaxStudioVATPeriodModel(
                    id: report.period.id,
                    selection: .vatPeriod(report.period.id),
                    title: vatPeriodTitle(report.period),
                    subtitle: coverageLabel(start: report.period.periodStart, end: report.period.periodEnd),
                    statusText: vatStatusText(report),
                    tone: vatStatusTone(report),
                    outputTaxText: amountString(report.outputTaxMinor, currency: report.period.currency),
                    inputTaxText: amountString(report.inputTaxMinor, currency: report.period.currency),
                    payableTaxText: amountString(report.netTaxPayableMinor, currency: report.period.currency),
                    issueSummary: vatIssueSummary(report),
                    issues: vatIssueRows(report)
                )
            }
    }

    var taxStudioFilingPackages: [TaxStudioFilingPackageModel] {
        filingPackages
            .sorted { lhs, rhs in
                let lhsDate = lhs.generatedAt ?? lhs.updatedAt
                let rhsDate = rhs.generatedAt ?? rhs.updatedAt
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
            }
            .map { filingPackage in
                TaxStudioFilingPackageModel(
                    id: filingPackage.id,
                    selection: .filingPackage(filingPackage.id),
                    title: filingPackageTitle(filingPackage),
                    subtitle: filingPackageBoundaryText(filingPackage),
                    statusText: filingPackageStatusLabel(filingPackage.status),
                    tone: filingPackageStatusTone(filingPackage.status),
                    exportFormatText: filingPackage.exportFormat,
                    generatedAtText: formattedDate(filingPackage.generatedAt),
                    finalizationText: filingPackageFinalizationDetail(filingPackage),
                    filingBoundaryText: filingPackageBoundaryText(filingPackage),
                    systemImage: filingPackageSystemImage(filingPackage.status)
                )
            }
    }

    var vatIssueChecklistItems: [TaxChecklistItem] {
        vatPeriodReports.flatMap { report in
            vatIssueRows(report).map { row in
                TaxChecklistItem(
                    id: "vat-\(row.id)",
                    selection: row.selection,
                    title: row.title,
                    subtitle: "\(vatPeriodTitle(report.period)): \(row.subtitle)",
                    statusText: row.statusText,
                    tone: row.tone,
                    systemImage: row.systemImage
                )
            }
        }
    }

    func vatIssueRows(_ report: VATReconciliationReport) -> [TaxStudioVATIssueRowModel] {
        report.issues.enumerated().map { index, issue in
            let id = ActiveWorkspaceSession.vatIssueSelectionID(
                periodId: report.period.id,
                index: index,
                issue: issue
            )
            return TaxStudioVATIssueRowModel(
                id: id,
                selection: .vatIssue(id),
                title: shortVATIssueTitle(issue),
                subtitle: issue.message,
                statusText: vatIssueStatusText(issue),
                tone: vatIssueTone(issue),
                systemImage: issue.severity == .blocker ? "exclamationmark.octagon" : "exclamationmark.triangle"
            )
        }
    }

    func vatIssueContext(for id: String) -> (report: VATReconciliationReport, issue: VATReconciliationIssue)? {
        for report in vatPeriodReports {
            for (index, issue) in report.issues.enumerated() {
                let issueId = ActiveWorkspaceSession.vatIssueSelectionID(
                    periodId: report.period.id,
                    index: index,
                    issue: issue
                )
                if issueId == id {
                    return (report, issue)
                }
            }
        }
        return nil
    }

    func vatPeriodTitle(_ period: VATPeriod) -> String {
        "VAT \(formattedDate(period.periodStart)) - \(formattedDate(period.periodEnd))"
    }

    func vatStatusText(_ report: VATReconciliationReport) -> String {
        if report.blockerCount > 0 {
            return "Blocked"
        }
        if report.issues.isEmpty == false {
            return "Review"
        }
        return "Ready"
    }

    func vatStatusTone(_ report: VATReconciliationReport) -> StatusBadge.Tone {
        if report.blockerCount > 0 {
            return .critical
        }
        if report.issues.isEmpty == false {
            return .warning
        }
        return .success
    }

    func vatIssueSummary(_ report: VATReconciliationReport) -> String {
        let blockerCount = report.blockerCount
        let warningCount = report.issues.count - blockerCount
        if blockerCount == 0 && warningCount == 0 {
            return "No VAT reconciliation issues"
        }
        return [
            blockerCount > 0 ? "\(blockerCount) blocker\(blockerCount == 1 ? "" : "s")" : nil,
            warningCount > 0 ? "\(warningCount) warning\(warningCount == 1 ? "" : "s")" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: " • ")
    }

    func shortVATIssueTitle(_ issue: VATReconciliationIssue) -> String {
        switch issue.code {
        case "vat.currency_mismatch":
            return "Currency mismatch"
        case "vat.missing_tax_code":
            return "Missing tax code"
        case "vat.unknown_tax_code":
            return "Unknown VAT code"
        case "vat.output_code_on_debit":
            return "Output code on debit"
        case "vat.input_code_on_credit":
            return "Input code on credit"
        default:
            return issue.code
                .replacingOccurrences(of: "vat.", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    func vatIssueStatusText(_ issue: VATReconciliationIssue) -> String {
        switch issue.severity {
        case .blocker:
            return "Blocking"
        case .warning:
            return "Warning"
        }
    }

    func vatIssueTone(_ issue: VATReconciliationIssue) -> StatusBadge.Tone {
        switch issue.severity {
        case .blocker:
            return .critical
        case .warning:
            return .warning
        }
    }

    func taxYearStatusLabel(_ status: TaxYearStatus) -> String {
        switch status {
        case .open:
            return "Open"
        case .locked:
            return "Locked"
        case .filed:
            return "Filed"
        }
    }

    func taxYearStatusTone(_ status: TaxYearStatus) -> StatusBadge.Tone {
        switch status {
        case .open:
            return .info
        case .locked:
            return .warning
        case .filed:
            return .success
        }
    }

    func taxPeriodDetail(_ taxYear: TaxYear) -> String {
        switch taxYear.status {
        case .open:
            return "Imports and tax fact updates are allowed for this year."
        case .locked:
            return "Imports and tax fact updates are blocked until this year is reopened."
        case .filed:
            return "This year is filed; period-changing actions remain blocked."
        }
    }

    func backupIntegrityIssueDetail(_ issue: WorkspaceBackupIntegrityIssue) -> String {
        guard let relativePath = issue.relativePath else {
            return issue.message
        }
        return "\(issue.message) \(relativePath)"
    }

    func proposalConfidenceLabel(_ confidence: Double) -> String {
        "\(proposalConfidenceBand(confidence)) confidence (\(boundedConfidencePercent(confidence))%)"
    }

    func proposalConfidenceTone(_ confidence: Double) -> StatusBadge.Tone {
        switch boundedConfidenceScore(confidence) {
        case 0.85...1.0:
            return .success
        case 0.50..<0.85:
            return .warning
        default:
            return .critical
        }
    }

    func proposalAllowsDirectApproval(_ proposal: AgentProposal) -> Bool {
        proposal.requiresManualReview == false && boundedConfidenceScore(proposal.confidence) >= 0.50
    }

    func proposalReviewPath(_ proposal: AgentProposal) -> String {
        if proposal.requiresManualReview {
            return "Manual review required before approval"
        }
        switch boundedConfidenceScore(proposal.confidence) {
        case 0.85...1.0:
            return "Suggested for approval after evidence review"
        case 0.50..<0.85:
            return "Suggested; verify source evidence before approval"
        default:
            return "Manual review required before approval"
        }
    }

    func importDiagnosticsSummary(_ diagnostics: [ImportDiagnostic]) -> String {
        let warningCount = diagnostics.filter { $0.severity == .warning }.count
        let errorCount = diagnostics.filter { $0.severity == .error }.count
        var parts: [String] = []
        if errorCount > 0 {
            parts.append("\(errorCount) error\(errorCount == 1 ? "" : "s")")
        }
        if warningCount > 0 {
            parts.append("\(warningCount) warning\(warningCount == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "No diagnostics" : parts.joined(separator: ", ")
    }

    func importDiagnosticLabel(_ diagnostic: ImportDiagnostic) -> String {
        let severity = diagnostic.severity.rawValue.capitalized
        guard let location = diagnostic.location, location.isEmpty == false else {
            return severity
        }
        return "\(severity) \(location)"
    }

    private func proposalConfidenceBand(_ confidence: Double) -> String {
        switch boundedConfidenceScore(confidence) {
        case 0.85...1.0:
            return "High"
        case 0.50..<0.85:
            return "Medium"
        default:
            return "Low"
        }
    }

    private func boundedConfidencePercent(_ confidence: Double) -> Int {
        Int((boundedConfidenceScore(confidence) * 100).rounded())
    }

    private func boundedConfidenceScore(_ confidence: Double) -> Double {
        guard confidence.isFinite else {
            return 0
        }
        return min(max(confidence, 0), 1)
    }

    func modelProviderRoleLabel(_ role: ModelProviderRole) -> String {
        switch role {
        case .localSmall:
            return "Local small"
        case .localReasoning:
            return "Local reasoning"
        case .cloudReasoning:
            return "Cloud reasoning"
        case .embeddingProvider:
            return "Embeddings"
        case .rerankerProvider:
            return "Reranker"
        }
    }

    func modelProviderCapabilitySummary(_ capabilities: Set<ModelProviderCapability>) -> String {
        let labels = capabilities
            .sorted { $0.rawValue < $1.rawValue }
            .map(modelProviderCapabilityLabel(_:))
        guard labels.isEmpty == false else {
            return "No capabilities"
        }
        return labels.joined(separator: ", ")
    }

    func modelProviderCapabilityLabel(_ capability: ModelProviderCapability) -> String {
        switch capability {
        case .fileClassification:
            return "File classification"
        case .extractionCleanup:
            return "Extraction cleanup"
        case .evidenceLinking:
            return "Evidence linking"
        case .reconciliationExplanation:
            return "Reconciliation explanation"
        case .taxExplanation:
            return "Tax explanation"
        case .chatReasoning:
            return "Chat reasoning"
        case .embeddings:
            return "Embeddings"
        case .reranking:
            return "Reranking"
        }
    }

    func modelProviderInputScopeLabel(_ inputScope: ModelProviderInputScope) -> String {
        switch inputScope {
        case .metadataOnly:
            return "metadata only"
        case .redactedSnippets:
            return "redacted snippets"
        case .localWorkspaceData:
            return "local workspace data"
        }
    }

    func aiPrivacyActivityDetails(
        _ snapshot: ModelProviderActivitySnapshot?
    ) -> SettingsSnapshot.AIPrivacyDetails.ActivityDetails {
        guard let snapshot else {
            return SettingsSnapshot.AIPrivacyDetails.ActivityDetails(
                title: "Idle",
                detail: "No model provider requests have run in this app session.",
                networkStatus: "Network idle",
                offDeviceStatus: "No off-device data",
                tone: .success
            )
        }

        let providerName = snapshot.providerName ?? snapshot.providerID
        let capability = snapshot.capability.map(modelProviderCapabilityLabel(_:)) ?? "Unknown capability"
        let inputScope = snapshot.inputScope.map(modelProviderInputScopeLabel(_:)) ?? "unknown input"
        let networkStatus = snapshot.requiresNetworkAccess
            ? (snapshot.phase == .running ? "Network active" : "Network provider")
            : "No network"
        let offDeviceStatus: String
        if snapshot.sendsDataOffDevice {
            if snapshot.sentDataOffDevice == true {
                offDeviceStatus = "Data sent off-device"
            } else if snapshot.phase == .running {
                offDeviceStatus = "Off-device request in progress"
            } else {
                offDeviceStatus = "Off-device capable"
            }
        } else {
            offDeviceStatus = "No off-device data"
        }

        let title: String
        let detail: String
        let tone: SettingsSnapshot.BackupDetails.IntegrityTone
        switch snapshot.phase {
        case .running:
            title = "Provider running"
            detail = "\(providerName) is processing \(capability) with \(inputScope)."
            tone = snapshot.requiresNetworkAccess || snapshot.sendsDataOffDevice ? .warning : .success
        case .completed:
            title = "Provider completed"
            detail = "\(providerName) completed \(capability) with \(inputScope)."
            tone = .success
        case .blocked:
            title = "Provider blocked"
            detail = "\(providerName) was blocked: \(modelProviderBlockReasonLabel(snapshot.blockReason ?? .providerNotApproved))."
            tone = .warning
        case .failed:
            title = "Provider failed"
            detail = snapshot.errorDescription.map { "\(providerName) failed: \($0)." }
                ?? "\(providerName) failed while processing \(capability)."
            tone = .critical
        }

        return SettingsSnapshot.AIPrivacyDetails.ActivityDetails(
            title: title,
            detail: detail,
            networkStatus: networkStatus,
            offDeviceStatus: offDeviceStatus,
            tone: tone
        )
    }

    func aiPrivacyControlRows(
        appPrivacyMode: AppPrivacyMode,
        consent: ModelProviderConsent
    ) -> [SettingsSnapshot.AIPrivacyDetails.ControlRow] {
        [
            SettingsSnapshot.AIPrivacyDetails.ControlRow(
                id: "network-consent",
                title: "Network consent",
                value: appPrivacyMode == .localOnly
                    ? "Disabled"
                    : (consent.allowsNetworkAccess ? "Allowed" : "Required"),
                detail: appPrivacyMode == .localOnly
                    ? "Network model providers cannot run in local-only mode."
                    : "External model providers cannot run until network access is explicitly allowed.",
                tone: appPrivacyMode == .localOnly
                    ? .success
                    : (consent.allowsNetworkAccess ? .success : .warning)
            ),
            SettingsSnapshot.AIPrivacyDetails.ControlRow(
                id: "off-device-consent",
                title: "Off-device data",
                value: appPrivacyMode == .localOnly
                    ? "Disabled"
                    : (consent.allowsOffDeviceData ? "Allowed" : "Required"),
                detail: appPrivacyMode == .localOnly
                    ? "Workspace data stays on this device."
                    : "Approved providers still need explicit consent before any data can leave this device.",
                tone: appPrivacyMode == .localOnly
                    ? .success
                    : (consent.allowsOffDeviceData ? .success : .warning)
            ),
            SettingsSnapshot.AIPrivacyDetails.ControlRow(
                id: "redaction-policy",
                title: "Redaction",
                value: modelProviderRedactionPolicyLabel(consent.redactionPolicy),
                detail: modelProviderRedactionPolicyDetail(consent.redactionPolicy),
                tone: .success
            ),
            SettingsSnapshot.AIPrivacyDetails.ControlRow(
                id: "approved-providers",
                title: "Approved providers",
                value: consent.approvedProviderIDs.isEmpty
                    ? "None"
                    : "\(consent.approvedProviderIDs.count) approved",
                detail: consent.approvedProviderIDs.isEmpty
                    ? "Providers that require explicit approval remain blocked."
                    : consent.approvedProviderIDs.sorted().joined(separator: ", "),
                tone: consent.approvedProviderIDs.isEmpty && appPrivacyMode != .localOnly
                    ? .warning
                    : .success
            ),
        ]
    }

    func modelProviderRedactionPolicyLabel(_ policy: ModelProviderRedactionPolicy) -> String {
        switch policy {
        case .metadataOnly:
            return "Metadata only"
        case .redactedSnippets:
            return "Redacted snippets"
        }
    }

    func modelProviderRedactionPolicyDetail(_ policy: ModelProviderRedactionPolicy) -> String {
        switch policy {
        case .metadataOnly:
            return "Only document, transaction, and issue metadata can be sent to approved off-device providers."
        case .redactedSnippets:
            return "Short redacted snippets may be sent to approved off-device providers; full workspace data remains local."
        }
    }

    func modelProviderStatus(
        for decision: ModelProviderPolicyDecision,
        isAllowed: Bool
    ) -> (title: String, tone: SettingsSnapshot.BackupDetails.IntegrityTone) {
        guard isAllowed else {
            switch decision {
            case .allowed:
                return ("Blocked", .warning)
            case .blocked(let reason):
                return ("Blocked: \(modelProviderBlockReasonLabel(reason))", .warning)
            }
        }
        return ("Available", .success)
    }

    func modelProviderBlockReasonLabel(_ reason: ModelProviderPolicyBlockReason) -> String {
        switch reason {
        case .providerNotRegistered:
            return "not registered"
        case .missingCapability:
            return "missing capability"
        case .networkDisabled:
            return "network disabled"
        case .offDeviceDataDisabled:
            return "off-device data disabled"
        case .explicitConsentRequired:
            return "consent required"
        case .providerNotApproved:
            return "provider not approved"
        case .inputScopeNotAllowed:
            return "redaction limit"
        }
    }
}
