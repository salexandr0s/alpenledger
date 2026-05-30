import AppKit
import Foundation
import Observation
import ALAudit
import ALDesignSystem
import ALDocuments
import ALDomain
import ALEvidence
import ALFeatures
import ALImports
import ALLedger
import ALStorage
import ALTaxCH
import ALTaxCore
import ALWorkspace

@MainActor
@Observable
final class WorkspaceAppModel {
    struct ShellToolbarConfiguration {
        struct InspectorControl {
            let title: String
            let accessibilityIdentifier: String
        }

        let title: String
        let subtitle: String
        let inspectorControl: InspectorControl?
    }

    struct BackupIntegrityResult {
        let backupName: String
        let report: WorkspaceBackupIntegrityReport
    }

    let container: DependencyContainer
    let uiPreferencesStore: WorkspaceUIPreferencesStore

    var recentWorkspaces: [RecentWorkspaceReference] = []
    var newWorkspaceName = ""
    var newSolePropName = ""
    var documentSearchQuery = ""
    var globalSearchQuery = ""
    var ledgerTransactionScope: LedgerTransactionScope = .all
    var documentFilterScope: DocumentFilterScope = .all
    var selectedSection: AppSection = .overview
    var selectedAccountId: FinancialAccountID?
    var selectedTransactionId: TransactionID?
    var selectedDocumentId: DocumentID?
    var selectedInboxSelection: InboxSelection?
    var selectedTaxEntityId: LegalEntityID?
    var selectedTaxYearId: TaxYearID?
    var selectedTaxFactId: TaxFactID?
    var selectedTaxStudioSelection: TaxStudioSelection?
    var isShowingNewWorkspaceSheet = false
    var isShowingGlobalSearch = false
    var isLedgerInspectorVisible = true
    var isDocumentsInspectorVisible = true
    var isShowingHelpCenter = false
    var isShowingDocumentLinkSheet = false
    var isShowingTransactionLinkSheet = false
    var errorTitle = "Action could not be completed"
    var errorMessage: String?
    var errorRecoverySuggestion: String?
    var isShowingErrorAlert = false
    var errorAlertBody: String {
        let message: String
        if let trimmedMessage = errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
           trimmedMessage.isEmpty == false {
            message = trimmedMessage
        } else {
            message = "The action could not be completed."
        }

        guard let recoverySuggestion = errorRecoverySuggestion?.trimmingCharacters(in: .whitespacesAndNewlines),
              recoverySuggestion.isEmpty == false
        else {
            return message
        }
        return "\(message)\n\n\(recoverySuggestion)"
    }
    var backupStatusMessage: String?
    var backupIntegrityResult: BackupIntegrityResult?
    var importDefaultsStatusMessage: String?
    var diagnosticsStatusMessage: String?
    var workspaceLockStatusMessage: String?
    var latestDiagnosticsReport: WorkspaceSupportDiagnosticsReport?
    var latestSupportBundle: WorkspaceSupportBundle?
    var databaseHealthReport: WorkspaceDatabaseHealthReport?

    private(set) var session: ActiveWorkspaceSession?

    private(set) var entities: [LegalEntity] = []
    private(set) var taxYears: [TaxYear] = []
    private(set) var financialAccounts: [FinancialAccount] = []
    private(set) var transactions: [Transaction] = []
    private(set) var documents: [Document] = []
    private(set) var archivedDocuments: [Document] = []
    private(set) var importJobs: [ImportJob] = []
    private(set) var importDiagnosticsByJobId: [ImportJobID: [ImportDiagnostic]] = [:]
    private(set) var issues: [Issue] = []
    private(set) var agentProposals: [AgentProposal] = []
    private(set) var taxFacts: [TaxFact] = []
    private(set) var taxRequirements: [Requirement] = []
    private(set) var taxIssues: [Issue] = []
    private(set) var filingPackages: [FilingPackage] = []
    private(set) var vatPeriodReports: [VATReconciliationReport] = []
    private(set) var taxReadinessSummary = TaxReadinessSummary(
        state: .notStarted,
        openIssueCount: 0,
        pendingRequirementCount: 0,
        currentFactCount: 0,
        missingConceptCodes: []
    )
    private(set) var linkedDocuments: [Document] = []
    private(set) var linkedTransactions: [Transaction] = []
    private(set) var selectedDocumentPreviewURL: URL?
    private(set) var entityDeletionChecks: [LegalEntityID: LegalEntityService.DeletionCheck] = [:]
    private(set) var accountBalanceById: [FinancialAccountID: Int64] = [:]
    private(set) var entityWorkspaces: [EntityWorkspace] = []
    private(set) var globalSearchResults: [GlobalSearchHit] = []
    private(set) var preferredStatementImportAccountId: FinancialAccountID?
    var activeEntityId: LegalEntityID? { session?.activeEntityId }
#if DEBUG
    var shouldShowQAValidationFixturesCommand: Bool { container.featureFlags.qaValidationFixtures }
    var canImportQAValidationFixtures: Bool { session != nil && container.featureFlags.qaValidationFixtures }
#endif

    init(container: DependencyContainer) {
        self.container = container
        self.uiPreferencesStore = container.uiPreferencesStore
        reloadRecentWorkspaces()
    }

    // MARK: - Workspace Lifecycle

    func reloadRecentWorkspaces() {
        recentWorkspaces = container.workspaceService.recentWorkspaces()
    }

    func presentHelpCenter() {
        isShowingHelpCenter = true
    }

    func dismissHelpCenter() {
        isShowingHelpCenter = false
    }

    func createWorkspace() {
        perform {
            let openedStorage = try container.workspaceService.createWorkspace(named: newWorkspaceName)
            newWorkspaceName = ""
            isShowingNewWorkspaceSheet = false
            configure(openedStorage)
        }
    }

    func createDemoWorkspace() {
        perform {
            let openedStorage = try container.workspaceService.createWorkspace(named: demoWorkspaceName())
            newWorkspaceName = ""
            isShowingNewWorkspaceSheet = false
            configure(openedStorage)
            try createDemoBusinessEntity()
            try importBundledSampleData()
            selectedSection = .overview
        }
    }

    func openWorkspace(_ reference: RecentWorkspaceReference) {
        openWorkspace(
            at: URL(fileURLWithPath: reference.path),
            knownWorkspaceId: reference.workspaceId,
            workspaceName: reference.name
        )
    }

    func openExistingWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Workspace"
        if panel.runModal() == .OK, let url = panel.url {
            openWorkspace(at: url, knownWorkspaceId: nil, workspaceName: nil)
        }
    }

    func closeCurrentWorkspace() {
        guard session != nil else { return }
        clearWorkspaceState()
        reloadRecentWorkspaces()
    }

    func lockCurrentWorkspace() {
        guard let session,
              uiPreferencesStore.workspaceLockEnabled(workspaceId: session.storage.manifest.workspace.id)
        else {
            return
        }
        clearWorkspaceState()
        reloadRecentWorkspaces()
    }

    func setWorkspaceLockEnabled(_ isEnabled: Bool) {
        guard let session else { return }
        uiPreferencesStore.setWorkspaceLockEnabled(isEnabled, workspaceId: session.storage.manifest.workspace.id)
        workspaceLockStatusMessage = isEnabled
            ? "Workspace lock is enabled. Opening this workspace now requires Mac authentication."
            : "Workspace lock is disabled. Opening this workspace will use the stored local key without an extra prompt."
        selectedSection = .settings
    }

    func createBackupFromPanel() {
        guard session != nil else { return }

        if let url = container.backupPanelClient.createBackupDestination(defaultBackupFilename()) {
            createBackup(at: url)
        }
    }

    func validateBackupFromPanel() {
        if let url = container.backupPanelClient.backupValidationSource() {
            validateBackup(at: url)
        }
    }

    func restoreBackupFromPanel() {
        if let url = container.backupPanelClient.backupRestoreSource() {
            restoreBackup(from: url)
        }
    }

    func deleteCurrentWorkspaceFromPanel() {
        guard let session else { return }

        let workspaceName = session.storage.manifest.workspace.name
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Delete Current Workspace?"
        alert.informativeText = "This removes the local workspace folder and its encryption key. Create and verify a backup before deleting. Type the workspace name to confirm: \(workspaceName)"
        alert.addButton(withTitle: "Delete Workspace")
        alert.addButton(withTitle: "Cancel")

        let confirmationField = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        confirmationField.placeholderString = workspaceName
        confirmationField.setAccessibilityIdentifier("deleteWorkspace.confirmationField")
        alert.accessoryView = confirmationField

        if alert.runModal() == .alertFirstButtonReturn {
            deleteCurrentWorkspace(confirmingName: confirmationField.stringValue)
        }
    }

    private func documentRetentionReasonFromPanel(
        title: String,
        message: String,
        defaultReason: String
    ) -> String? {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")

        let reasonField = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        reasonField.stringValue = defaultReason
        reasonField.setAccessibilityIdentifier("documentRetention.reasonField")
        alert.accessoryView = reasonField

        guard alert.runModal() == .alertFirstButtonReturn else {
            return nil
        }
        return reasonField.stringValue
    }

    func exportDiagnosticsFromPanel() {
        guard session != nil else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.prompt = "Export Diagnostics"
        panel.nameFieldStringValue = defaultDiagnosticsFilename()
        panel.message = "Diagnostics omit source documents, transaction descriptions, workspace names, absolute paths, and encryption keys."

        if panel.runModal() == .OK, let url = panel.url {
            exportDiagnostics(to: url)
        }
    }

    func exportSupportBundleFromPanel() {
        guard session != nil else { return }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.prompt = "Export Support Bundle"
        panel.nameFieldStringValue = defaultSupportBundleFilename()
        panel.message = "Support bundles include sanitized diagnostics and audit-log summaries. They omit raw audit payloads, source documents, transaction descriptions, workspace names, absolute paths, and encryption keys."

        if panel.runModal() == .OK, let url = panel.url {
            exportSupportBundle(to: url)
        }
    }

    func createBackup(at url: URL) {
        guard let session else { return }

        perform {
            let backupURL = backupURLWithExpectedExtension(url)
            let manifest = try container.workspaceService.createBackup(for: session.storage, at: backupURL)
            let integrityReport = try container.workspaceService.validateBackup(at: backupURL)
            backupIntegrityResult = BackupIntegrityResult(
                backupName: backupURL.lastPathComponent,
                report: integrityReport
            )
            backupStatusMessage = "Created \(backupURL.lastPathComponent) for \(manifest.workspaceName)."
            reloadRecentWorkspaces()
            selectedSection = .settings
        }
    }

    func validateBackup(at url: URL) {
        perform {
            let integrityReport = try container.workspaceService.validateBackup(at: url)
            backupIntegrityResult = BackupIntegrityResult(
                backupName: url.lastPathComponent,
                report: integrityReport
            )
            backupStatusMessage = "Checked \(url.lastPathComponent)."
            selectedSection = .settings
        }
    }

    func restoreBackup(from url: URL) {
        perform {
            let integrityReport = try container.workspaceService.validateBackup(at: url)
            backupIntegrityResult = BackupIntegrityResult(
                backupName: url.lastPathComponent,
                report: integrityReport
            )
            guard integrityReport.isRestorable else {
                selectedSection = .settings
                throw DomainError.invalidWorkspaceBackup
            }

            let restoredStorage = try container.workspaceService.restoreBackup(from: url)
            configure(restoredStorage)
            backupStatusMessage = "Restored \(restoredStorage.manifest.workspace.name) from \(url.lastPathComponent)."
            selectedSection = .settings
        }
    }

    func deleteCurrentWorkspace(confirmingName confirmation: String) {
        guard let session else { return }
        let workspaceId = session.storage.manifest.workspace.id

        perform {
            try container.workspaceService.deleteWorkspace(
                session.storage,
                confirmingWorkspaceName: confirmation
            )
            uiPreferencesStore.setWorkspaceLockEnabled(false, workspaceId: workspaceId)
            clearWorkspaceState()
            reloadRecentWorkspaces()
        }
    }

    func exportDiagnostics(to url: URL) {
        guard let session else { return }

        perform {
            let diagnosticsURL = diagnosticsURLWithExpectedExtension(url)
            let report = try session.storage.exportSupportDiagnostics(
                to: diagnosticsURL,
                generatedAt: container.nowProvider()
            )
            latestDiagnosticsReport = report
            diagnosticsStatusMessage = "Exported \(diagnosticsURL.lastPathComponent)."
            selectedSection = .settings
        }
    }

    func exportSupportBundle(to url: URL) {
        guard let session else { return }

        perform {
            let bundleURL = supportBundleURLWithExpectedExtension(url)
            let bundle = try session.storage.exportSupportBundle(
                to: bundleURL,
                generatedAt: container.nowProvider()
            )
            latestSupportBundle = bundle
            diagnosticsStatusMessage = "Exported \(bundleURL.lastPathComponent)."
            selectedSection = .settings
        }
    }

    func presentNewWorkspaceSheet() {
        newWorkspaceName = ""
        isShowingNewWorkspaceSheet = true
    }

    func dismissNewWorkspaceSheet() {
        isShowingNewWorkspaceSheet = false
    }

    // MARK: - Entity Switching

    func switchEntity(to entityWorkspaceId: EntityWorkspaceID) {
        guard let session else { return }
        perform {
            try session.switchEntity(to: entityWorkspaceId)
            entityWorkspaces = session.entityWorkspaces
            try refreshData(recomputeEvidence: false)
        }
    }

    var entitySwitcherSnapshot: EntitySwitcherSnapshot {
        EntitySwitcherSnapshot(
            activeEntityName: entities.first(where: { $0.id == activeEntityId })?.displayName ?? "All Entities",
            entities: entityWorkspaces.map { ew in
                EntitySwitcherSnapshot.EntityItem(
                    id: ew.id,
                    entityId: ew.entityId,
                    displayName: ew.displayName,
                    isActive: ew.entityId == activeEntityId,
                    lastAccessedText: ew.lastAccessedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        )
    }

    // MARK: - Entity Management

    func createSoleProp() {
        guard let session else { return }
        perform {
            _ = try session.legalEntityService.createSoleProprietor(name: newSolePropName)
            newSolePropName = ""
            try refreshData(recomputeEvidence: false)
        }
    }

    func renameWorkspace(to name: String) {
        guard let session else { return }
        perform {
            let reopenedStorage = try container.workspaceService.renameWorkspace(session.storage, name: name)
            let newSession = ActiveWorkspaceSession(storage: reopenedStorage, container: container)
            self.session = newSession
            reloadRecentWorkspaces()
            try refreshData(recomputeEvidence: false)
        }
    }

    func updateEntityName(_ entityId: LegalEntityID, name: String) {
        guard let session,
              let existingEntity = entities.first(where: { $0.id == entityId })
        else {
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }

        perform {
            var updatedEntity = existingEntity
            updatedEntity.displayName = trimmedName
            if updatedEntity.legalName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updatedEntity.legalName = trimmedName
            }
            try session.legalEntityService.updateEntity(updatedEntity)
            try refreshData(recomputeEvidence: false)
        }
    }

    func removeEntity(_ entityId: LegalEntityID) {
        guard let session else { return }
        perform {
            let deletionCheck = try session.legalEntityService.deleteEntity(entityId)
            if deletionCheck.canDelete == false {
                presentError(
                    title: "Entity cannot be removed",
                    message: blockedEntityDeletionMessage(for: deletionCheck),
                    recoverySuggestion: "Remove or reassign the dependent records before deleting this entity."
                )
                return
            }

            if selectedTaxEntityId == entityId {
                selectedTaxEntityId = nil
            }
            try refreshData(recomputeEvidence: false)
        }
    }

    // MARK: - Navigation

    func openInbox() {
        selectedSection = .inbox
    }

    func navigate(to section: AppSection) {
        selectedSection = section
    }

    func performShellToolbarInspectorAction() {
        toggleInspectorForActiveSection()
    }

    // MARK: - Global Search

    func presentGlobalSearch() {
        guard hasWorkspace else { return }
        isShowingGlobalSearch = true
        refreshGlobalSearchResults()
    }

    func dismissGlobalSearch() {
        isShowingGlobalSearch = false
    }

    func refreshGlobalSearchResults() {
        guard let session else {
            globalSearchResults = []
            return
        }

        let trimmedQuery = globalSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            globalSearchResults = []
            return
        }

        perform {
            globalSearchResults = try session.storage.searchIndex.search(
                workspaceId: session.storage.manifest.workspace.id,
                query: trimmedQuery,
                limit: 12
            )
        }
    }

    func clearGlobalSearch() {
        globalSearchQuery = ""
        globalSearchResults = []
    }

    func openGlobalSearchHit(_ hit: GlobalSearchHit) {
        dismissGlobalSearch()
        openObjectRef(hit.objectRef)
    }

    // MARK: - Inbox Actions

    func performInboxAction(_ action: InboxAction) {
        switch action {
        case let .resolveIssue(issueId):
            guard let session else { return }
            perform {
                _ = try session.issueService.resolveIssue(issueId, now: container.nowProvider())
                try refreshData(recomputeEvidence: false)
            }
        case let .dismissIssue(issueId):
            guard let session else { return }
            perform {
                _ = try session.issueService.dismissIssue(issueId, now: container.nowProvider())
                try refreshData(recomputeEvidence: false)
            }
        case let .importStatement(accountId):
            if let accountId {
                selectedAccountId = accountId
            }
            selectedSection = .ledger
            importCSVFromPanel()
        case let .retryImport(importJobId):
            guard let session else { return }
            guard let accountId = statementImportAccountId() else {
                presentError(DomainError.financialAccountNotFound)
                return
            }
            perform {
                let retrySource = try session.importJobService
                    .listImportJobs()
                    .first { $0.id == importJobId }?
                    .source
                _ = try session.importJobService.retryStatementImport(
                    importJobId: importJobId,
                    accountId: accountId
                )
                try refreshData(recomputeEvidence: true)
                selectedSection = .inbox
                if let retrySource,
                   let completedJob = importJobs
                    .sorted(by: importSortOrder)
                    .first(where: {
                        $0.id != importJobId &&
                            $0.source == retrySource &&
                            $0.status == .completed
                    }) {
                    selectedInboxSelection = .importJob(completedJob.id)
                } else {
                    selectedInboxSelection = .importJob(importJobId)
                }
            }
        case let .linkDocument(transactionId):
            guard let transaction = transactionById(transactionId) else { return }
            openLedger(accountId: transaction.accountId, transactionId: transaction.id)
            presentDocumentLinkSheet()
        case let .linkTransaction(documentId):
            openDocuments(documentId: documentId)
            presentTransactionLinkSheet()
        case let .openProposalTarget(objectRef):
            openObjectRef(objectRef)
        case let .approveProposal(proposalId):
            guard let session else { return }
            perform {
                _ = try session.reconciliationService.approveDocumentMatchProposal(
                    proposalId,
                    now: container.nowProvider()
                )
                try refreshData(recomputeEvidence: true)
            }
        case let .revokeProposalApproval(proposalId):
            guard let session else { return }
            perform {
                _ = try session.reconciliationService.revokeDocumentMatchProposalApproval(
                    proposalId,
                    now: container.nowProvider()
                )
                try refreshData(recomputeEvidence: true)
            }
        case let .rejectProposal(proposalId):
            guard let session else { return }
            perform {
                _ = try session.reconciliationService.rejectProposal(proposalId, now: container.nowProvider())
                try refreshData(recomputeEvidence: false)
            }
        }
    }

    // MARK: - Overview Actions

    func performOverviewAction(_ action: OverviewAction) {
        switch action {
        case let .openInbox(selection):
            selectedSection = .inbox
            selectedInboxSelection = selection
        case let .openLedger(accountId, transactionId):
            openLedger(accountId: accountId, transactionId: transactionId)
        case let .openDocuments(documentId):
            openDocuments(documentId: documentId)
        case let .openTaxStudio(entityId, taxYearId, factId):
            openTaxStudio(entityId: entityId, taxYearId: taxYearId, factId: factId)
        case .importSampleCSV:
            importSampleCSV()
        case .importSampleDocument:
            importSampleDocument()
        case .importDocument:
            importDocumentFromPanel()
        }
    }

    // MARK: - Copilot Actions

    func performCopilotAction(_ action: CopilotAction) {
        switch action {
        case let .openInbox(selection):
            selectedSection = .inbox
            selectedInboxSelection = selection
        case let .openTaxStudio(entityId, taxYearId):
            openTaxStudio(
                entityId: entityId ?? selectedTaxEntityId,
                taxYearId: taxYearId ?? selectedTaxYearId,
                factId: nil
            )
        case let .openLedger(accountId, transactionId):
            openLedger(accountId: accountId, transactionId: transactionId)
        case let .openDocuments(documentId):
            openDocuments(documentId: documentId)
        case let .openSource(ref):
            openCopilotSource(ref)
        case let .createTaskFromAnswer(task):
            createCopilotTask(from: task)
        }
    }

    // MARK: - Document Import

    func importDocumentURLs(_ urls: [URL]) {
        guard let session, urls.isEmpty == false else { return }
        perform {
            for url in urls {
                _ = try session.documentService.importDocument(from: url, entityId: session.activeEntityId)
            }
            try refreshData(recomputeEvidence: true)
        }
    }

    func importSampleData() {
        perform {
            try importBundledSampleData()
        }
    }

    func importSampleCSV() {
        guard let url = Bundle.main.url(forResource: "sample-bank-statement", withExtension: "csv") else { return }
        importCSV(url: url)
    }

    func importSampleDocument() {
        guard let url = Bundle.main.url(forResource: "sample-receipt", withExtension: "pdf") else { return }
        importDocument(url: url)
    }

    func importCSVFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            importCSV(url: url)
        }
    }

    func importDocumentFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .png, .jpeg, .tiff, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            importDocument(url: url)
        }
    }

    func setDefaultStatementImportAccount(_ accountId: FinancialAccountID?) {
        guard let session else { return }

        if let accountId, financialAccounts.contains(where: { $0.id == accountId }) == false {
            presentError(DomainError.financialAccountNotFound)
            return
        }

        uiPreferencesStore.setPreferredStatementImportAccountId(
            accountId,
            workspaceId: session.storage.manifest.workspace.id
        )
        preferredStatementImportAccountId = accountId
        if let account = financialAccounts.first(where: { $0.id == accountId }) {
            importDefaultsStatusMessage = "Statement imports default to \(account.displayName)."
        } else {
            importDefaultsStatusMessage = "Statement imports use the selected ledger account, then the first available account."
        }
        selectedSection = .settings
    }

    // MARK: - Tax Studio Selection

    func selectTaxStudioSelection(_ selection: TaxStudioSelection?) {
        selectedTaxStudioSelection = selection
        if case let .fact(factId) = selection {
            selectedTaxFactId = factId
        } else {
            selectedTaxFactId = nil
        }
    }

    func selectTaxEntity(_ entityId: LegalEntityID?) {
        selectedTaxEntityId = entityId
        selectedTaxYearId = nil
        selectedTaxFactId = nil
        selectedTaxStudioSelection = nil
        perform {
            try refreshTaxStudio(recomputeFacts: true)
        }
    }

    func selectTaxYear(_ taxYearId: TaxYearID?) {
        selectedTaxYearId = taxYearId
        selectedTaxFactId = nil
        selectedTaxStudioSelection = nil
        perform {
            try refreshTaxStudio(recomputeFacts: true)
        }
    }

    func lockSelectedTaxYear() {
        guard let session, let selectedTaxEntityId, let selectedTaxYearId else { return }
        perform {
            _ = try session.taxYearService.lockTaxYear(
                entityId: selectedTaxEntityId,
                taxYearId: selectedTaxYearId
            )
            try refreshTaxStudio(recomputeFacts: false)
        }
    }

    func unlockSelectedTaxYear() {
        guard let session, let selectedTaxEntityId, let selectedTaxYearId else { return }
        perform {
            _ = try session.taxYearService.unlockTaxYear(
                entityId: selectedTaxEntityId,
                taxYearId: selectedTaxYearId
            )
            try refreshTaxStudio(recomputeFacts: false)
        }
    }

    // MARK: - Scope & Filtering

    func setLedgerTransactionScope(_ scope: LedgerTransactionScope) {
        ledgerTransactionScope = scope
        perform {
            try reconcileTransactionSelection()
        }
    }

    func setDocumentFilterScope(_ scope: DocumentFilterScope) {
        documentFilterScope = scope
        perform {
            try reconcileDocumentSelection()
        }
    }

    func filterDocuments() {
        perform {
            try reconcileDocumentSelection()
        }
    }

    func clearDocumentSearch() {
        documentSearchQuery = ""
        filterDocuments()
    }

    func resetLedgerScope() {
        setLedgerTransactionScope(.all)
    }

    func resetDocumentScope() {
        setDocumentFilterScope(.all)
    }

    // MARK: - Inspector Toggles

    func toggleLedgerInspector() {
        isLedgerInspectorVisible.toggle()
        persistInspectorVisibility(for: .ledger, isVisible: isLedgerInspectorVisible)
    }

    func toggleDocumentsInspector() {
        isDocumentsInspectorVisible.toggle()
        persistInspectorVisibility(for: .documents, isVisible: isDocumentsInspectorVisible)
    }

    func toggleInspectorForActiveSection() {
        switch selectedSection {
        case .ledger:
            toggleLedgerInspector()
        case .documents:
            toggleDocumentsInspector()
        case .overview, .inbox, .copilot, .taxStudio, .settings:
            break
        }
    }

    // MARK: - Selection

    func selectAccount(_ accountId: FinancialAccountID?) {
        selectedAccountId = accountId
        perform {
            try refreshTransactions()
        }
    }

    func selectTransaction(_ transactionId: TransactionID?) {
        selectedTransactionId = transactionId
        perform {
            try refreshSelectionArtifacts()
        }
    }

    func selectDocument(_ documentId: DocumentID?) {
        selectedDocumentId = documentId
        perform {
            try refreshSelectionArtifacts()
        }
    }

    // MARK: - Link Sheets

    func presentDocumentLinkSheet() {
        guard selectedTransactionId != nil else { return }
        isShowingDocumentLinkSheet = true
    }

    func presentTransactionLinkSheet() {
        guard canLinkSelectedTransaction else { return }
        isShowingTransactionLinkSheet = true
    }

    func linkSelectedDocumentToCurrentTransaction(documentId: DocumentID) {
        guard let selectedTransactionId, let session else { return }
        perform {
            try session.documentService.linkDocument(documentId, to: selectedTransactionId)
            isShowingDocumentLinkSheet = false
            try refreshData(recomputeEvidence: true)
        }
    }

    func linkCurrentDocumentToTransaction(transactionId: TransactionID) {
        guard canLinkSelectedTransaction, let selectedDocumentId, let session else { return }
        perform {
            try session.documentService.linkDocument(selectedDocumentId, to: transactionId)
            isShowingTransactionLinkSheet = false
            try refreshData(recomputeEvidence: true)
        }
    }

    // MARK: - Document Metadata Review

    func reviewDocumentMetadata(
        documentId: DocumentID,
        documentType: DocumentType,
        issueDate: Date?
    ) {
        guard selectedSection == .documents, let session else { return }
        perform {
            let reviewed = try session.documentService.reviewDocumentMetadata(
                documentId,
                documentType: documentType,
                issueDate: issueDate
            )
            if documentFilterScope.matches(reviewed) == false {
                documentFilterScope = .all
            }
            try refreshData(recomputeEvidence: true)
            selectedDocumentId = reviewed.id
            try refreshSelectionArtifacts()
        }
    }

    // MARK: - Document Retention

    func archiveSelectedDocumentFromPanel() {
        guard canArchiveSelectedDocument else { return }
        guard let reason = documentRetentionReasonFromPanel(
            title: "Archive Document?",
            message: "Enter a reviewer reason before moving this document out of the active vault.",
            defaultReason: "Archived from document review."
        ) else {
            return
        }
        archiveSelectedDocument(reason: reason)
    }

    func restoreSelectedDocumentFromPanel() {
        guard canRestoreSelectedDocument else { return }
        guard let reason = documentRetentionReasonFromPanel(
            title: "Restore Document?",
            message: "Enter a reviewer reason before returning this document to the active vault.",
            defaultReason: "Restored from archive review."
        ) else {
            return
        }
        restoreSelectedDocument(reason: reason)
    }

    func archiveSelectedDocument(reason: String) {
        guard canArchiveSelectedDocument, let selectedDocumentId, let session else { return }
        perform {
            _ = try session.documentService.archiveDocument(selectedDocumentId, reason: reason)
            documentFilterScope = .archived
            try refreshData(recomputeEvidence: false)
            self.selectedDocumentId = session.archivedDocuments.contains(where: { $0.id == selectedDocumentId })
                ? selectedDocumentId
                : nil
            try refreshSelectionArtifacts()
        }
    }

    func restoreSelectedDocument(reason: String) {
        guard canRestoreSelectedDocument, let selectedDocumentId, let session else { return }
        perform {
            _ = try session.documentService.restoreArchivedDocument(selectedDocumentId, reason: reason)
            documentFilterScope = .all
            try refreshData(recomputeEvidence: false)
            self.selectedDocumentId = session.documents.contains(where: { $0.id == selectedDocumentId })
                ? selectedDocumentId
                : nil
            try refreshSelectionArtifacts()
        }
    }

    // MARK: - Navigation Helpers

    func openLedger(accountId: FinancialAccountID?, transactionId: TransactionID?) {
        selectedSection = .ledger
        selectedAccountId = accountId ?? selectedAccountId
        selectedTransactionId = transactionId

        guard session != nil else {
            if let transactionId, visibleTransactions.contains(where: { $0.id == transactionId }) == false {
                selectedTransactionId = nil
            }
            return
        }

        perform {
            try refreshTransactions()
            if let transactionId, visibleTransactions.contains(where: { $0.id == transactionId }) == false {
                selectedTransactionId = nil
            }
            try refreshSelectionArtifacts()
        }
    }

    func openDocuments(documentId: DocumentID?) {
        selectedSection = .documents
        selectedDocumentId = documentId

        guard session != nil else {
            if let documentId, visibleDocuments.contains(where: { $0.id == documentId }) == false {
                selectedDocumentId = nil
            }
            return
        }

        perform {
            try reconcileDocumentSelection()
            try refreshSelectionArtifacts()
        }
    }

    func openTaxStudio(entityId: LegalEntityID?, taxYearId: TaxYearID?, factId: TaxFactID?) {
        selectedSection = .taxStudio
        if let entityId {
            selectedTaxEntityId = entityId
        }
        if let taxYearId {
            selectedTaxYearId = taxYearId
        }
        selectedTaxFactId = factId
        selectedTaxStudioSelection = factId.map(TaxStudioSelection.fact)

        guard session != nil else { return }

        perform {
            try refreshTaxStudio(recomputeFacts: false)
            if let factId, taxFacts.contains(where: { $0.id == factId }) == false {
                selectedTaxFactId = nil
            }
        }
    }

    private func openCopilotSource(_ ref: ObjectRef) {
        switch ref.kind {
        case .taxYear:
            let taxYearId = UUID(uuidString: ref.id).map(TaxYearID.init(rawValue:))
            let entityId = taxYearId.flatMap { taxYearId in
                taxYears.first(where: { $0.id == taxYearId })?.entityId
            }
            openTaxStudio(
                entityId: entityId ?? selectedTaxEntityId,
                taxYearId: taxYearId ?? selectedTaxYearId,
                factId: nil
            )
        case .requirement:
            selectedSection = .taxStudio
            if let uuid = UUID(uuidString: ref.id) {
                selectedTaxStudioSelection = .requirement(RequirementID(rawValue: uuid))
            }
        case .vatPeriod:
            selectedSection = .taxStudio
            if let uuid = UUID(uuidString: ref.id) {
                selectedTaxStudioSelection = .vatPeriod(VATPeriodID(rawValue: uuid))
            }
        case .legalEntity:
            let entityId = UUID(uuidString: ref.id).map(LegalEntityID.init(rawValue:))
            openTaxStudio(entityId: entityId ?? selectedTaxEntityId, taxYearId: selectedTaxYearId, factId: nil)
        case .statementImport:
            let statementImportId = UUID(uuidString: ref.id).map(StatementImportID.init(rawValue:))
            let transaction = statementImportId.flatMap { statementImportId in
                transactions.first { $0.statementImportId == statementImportId }
            }
            openLedger(accountId: transaction?.accountId ?? selectedAccountId, transactionId: transaction?.id)
        default:
            openObjectRef(ref)
        }
    }

    private func createCopilotTask(from draft: CopilotTaskDraft) {
        guard let session else { return }

        let sourceRef = draft.sourceRef ?? ObjectRef(kind: .workspace, id: session.storage.manifest.workspace.id.rawValue)
        let entityFingerprint = draft.entityId?.rawValue.uuidString.lowercased() ?? "workspace"
        let taxYearFingerprint = draft.taxYearId?.rawValue.uuidString.lowercased() ?? "no-tax-year"
        let fingerprint = [
            "copilot-task",
            draft.answerId,
            entityFingerprint,
            taxYearFingerprint,
            sourceRef.stringValue,
        ].joined(separator: "|")

        perform {
            let input = AgentIssueOpenOrUpdateInput(
                fingerprint: fingerprint,
                entityId: draft.entityId,
                taxYearId: draft.taxYearId,
                issueCode: .copilotTask,
                severity: .warning,
                status: .open,
                summary: draft.summary,
                objectRef: sourceRef
            )
            let result = try session.agentToolService.execute(
                AgentToolInvocation(
                    toolName: "issues.open_or_update",
                    inputJSON: try JSONEncoder.alpenLedger.encode(input),
                    grantedScopes: [.issuesWrite]
                )
            )
            let output = try JSONDecoder.alpenLedger.decode(AgentIssueToolOutput.self, from: result.outputJSON)
            guard output.issueCode == .copilotTask else {
                throw WorkspaceAgentToolError.invalidInput("issues.open_or_update")
            }
            let issueId = output.issueId
            guard try session.storage.issueRepository.fetchIssue(id: issueId) != nil else {
                throw WorkspaceAgentToolError.invalidInput("issues.open_or_update")
            }
            try refreshData(recomputeEvidence: false)
            selectedSection = .inbox
            selectedInboxSelection = .issue(issueId)
        }
    }

    // MARK: - Session Configuration

    private func clearWorkspaceState() {
        session = nil
        entities = []
        taxYears = []
        financialAccounts = []
        transactions = []
        documents = []
        archivedDocuments = []
        importJobs = []
        importDiagnosticsByJobId = [:]
        issues = []
        agentProposals = []
        taxFacts = []
        taxRequirements = []
        taxIssues = []
        filingPackages = []
        vatPeriodReports = []
        taxReadinessSummary = TaxReadinessSummary(
            state: .notStarted,
            openIssueCount: 0,
            pendingRequirementCount: 0,
            currentFactCount: 0,
            missingConceptCodes: []
        )
        linkedDocuments = []
        linkedTransactions = []
        selectedDocumentPreviewURL = nil
        entityDeletionChecks = [:]
        accountBalanceById = [:]
        entityWorkspaces = []
        globalSearchResults = []
        selectedAccountId = nil
        selectedTransactionId = nil
        selectedDocumentId = nil
        selectedInboxSelection = nil
        selectedTaxEntityId = nil
        selectedTaxYearId = nil
        selectedTaxFactId = nil
        selectedTaxStudioSelection = nil
        documentSearchQuery = ""
        globalSearchQuery = ""
        isShowingGlobalSearch = false
        isShowingDocumentLinkSheet = false
        isShowingTransactionLinkSheet = false
        backupStatusMessage = nil
        backupIntegrityResult = nil
        importDefaultsStatusMessage = nil
        diagnosticsStatusMessage = nil
        workspaceLockStatusMessage = nil
        latestDiagnosticsReport = nil
        latestSupportBundle = nil
        databaseHealthReport = nil
        preferredStatementImportAccountId = nil
        selectedSection = .overview
    }

    private func configure(_ storage: WorkspaceStorage) {
        let newSession = ActiveWorkspaceSession(storage: storage, container: container)
        self.session = newSession
        selectedSection = .overview
        documentSearchQuery = ""
        globalSearchQuery = ""
        globalSearchResults = []
        ledgerTransactionScope = .all
        documentFilterScope = .all
        restoreInspectorVisibility(for: storage.manifest.workspace.id)
        reloadRecentWorkspaces()
        perform {
            _ = try newSession.importJobService.recoverInterruptedImports(recoveredAt: container.nowProvider())
            try refreshData(recomputeEvidence: true)
        }
    }

    private func openWorkspace(at url: URL, knownWorkspaceId: WorkspaceID?, workspaceName: String?) {
        let workspaceId = knownWorkspaceId ?? workspaceIdFromManifest(at: url)
        guard let workspaceId,
              uiPreferencesStore.workspaceLockEnabled(workspaceId: workspaceId)
        else {
            openWorkspaceAfterLockGate(at: url)
            return
        }

        let displayName = workspaceName ?? "AlpenLedger workspace"
        container.workspaceLockAuthenticationClient.authenticate(
            "Unlock \(displayName) to open local finance data."
        ) { [weak self] didAuthenticate in
            guard let self else { return }
            if didAuthenticate {
                self.openWorkspaceAfterLockGate(at: url)
            } else {
                self.presentError(
                    title: "Workspace locked",
                    message: "\(displayName) was not opened because Mac authentication did not complete.",
                    recoverySuggestion: "Try opening the workspace again and complete Touch ID, Apple Watch, or Mac password authentication."
                )
            }
        }
    }

    private func openWorkspaceAfterLockGate(at url: URL) {
        perform {
            let openedStorage = try container.workspaceService.openWorkspace(at: url)
            isShowingNewWorkspaceSheet = false
            configure(openedStorage)
        }
    }

    private func workspaceIdFromManifest(at rootURL: URL) -> WorkspaceID? {
        let manifestURL = WorkspacePaths(rootURL: rootURL).manifestURL
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder.alpenLedger.decode(WorkspaceManifest.self, from: data)
        else {
            return nil
        }
        return manifest.workspace.id
    }

    // MARK: - Refresh Methods (Delegating to Session)

    private func refreshData(recomputeEvidence: Bool = false) throws {
        guard let session else { return }
        databaseHealthReport = try session.storage.databaseHealthReport()
        try session.loadEntityWorkspaces()
        let result = try session.refreshCoreData(
            recomputeEvidence: recomputeEvidence,
            selectedAccountId: selectedAccountId,
            selectedTaxEntityId: selectedTaxEntityId,
            selectedTaxYearId: selectedTaxYearId,
            selectedTransactionId: selectedTransactionId,
            selectedDocumentId: selectedDocumentId,
            selectedTaxStudioSelection: selectedTaxStudioSelection,
            selectedInboxSelection: selectedInboxSelection
        )
        copySessionData()
        reconcilePreferredStatementImportAccount()
        if result.shouldClearSelectedAccountId {
            selectedAccountId = nil
        }
    }

    private func refreshTransactions() throws {
        guard let session else {
            transactions = []
            selectedTransactionId = nil
            linkedDocuments = []
            return
        }

        let shouldClear = try session.refreshTransactions(
            accountId: selectedAccountId,
            selectedTransactionId: selectedTransactionId,
            selectedDocumentId: selectedDocumentId,
            selectedTaxStudioSelection: selectedTaxStudioSelection
        )
        copySessionData()
        if shouldClear {
            selectedTransactionId = nil
        }
        try reconcileTransactionSelection()
    }

    private func refreshDocuments() throws {
        guard let session else {
            documents = []
            archivedDocuments = []
            selectedDocumentId = nil
            linkedTransactions = []
            return
        }

        try session.refreshDocuments(
            selectedDocumentId: selectedDocumentId,
            selectedTransactionId: selectedTransactionId,
            selectedTaxStudioSelection: selectedTaxStudioSelection
        )
        copySessionData()
        try reconcileDocumentSelection()
    }

    private func refreshInbox() throws {
        guard let session else { return }
        let shouldClear = try session.refreshInbox(selectedInboxSelection: selectedInboxSelection)
        copySessionData()
        if shouldClear {
            selectedInboxSelection = nil
        }
    }

    private func refreshTaxStudio(recomputeFacts: Bool = false) throws {
        guard let session else {
            taxYears = []
            taxFacts = []
            taxRequirements = []
            taxIssues = []
            filingPackages = []
            vatPeriodReports = []
            taxReadinessSummary = TaxReadinessSummary(
                state: .notStarted,
                openIssueCount: 0,
                pendingRequirementCount: 0,
                currentFactCount: 0,
                missingConceptCodes: []
            )
            return
        }

        let result = try session.refreshTaxStudio(
            recomputeFacts: recomputeFacts,
            selectedTaxEntityId: selectedTaxEntityId,
            selectedTaxYearId: selectedTaxYearId
        )
        copySessionData()
        selectedTaxEntityId = result.selectedTaxEntityId
        selectedTaxYearId = result.selectedTaxYearId
        if result.shouldClearTaxFactId {
            selectedTaxFactId = nil
        }
        if result.shouldClearTaxStudioSelection {
            selectedTaxStudioSelection = nil
        }

        if let selectedTaxFactId, taxFacts.contains(where: { $0.id == selectedTaxFactId }) == false {
            self.selectedTaxFactId = nil
        }
        if let selectedTaxStudioSelection, session.containsTaxStudioSelection(selectedTaxStudioSelection) == false {
            self.selectedTaxStudioSelection = nil
        }
    }

    private func refreshSelectionArtifacts() throws {
        guard let session else { return }
        try session.refreshSelectionArtifacts(
            selectedTransactionId: selectedTransactionId,
            selectedDocumentId: selectedDocumentId,
            selectedTaxStudioSelection: selectedTaxStudioSelection
        )
        copySessionData()

        if let selectedTaxStudioSelection, session.containsTaxStudioSelection(selectedTaxStudioSelection) == false {
            self.selectedTaxStudioSelection = nil
        }
    }

    private func reconcileTransactionSelection() throws {
        if visibleTransactions.contains(where: { $0.id == selectedTransactionId }) == false {
            selectedTransactionId = nil
        }
        try refreshSelectionArtifacts()
    }

    private func reconcileDocumentSelection() throws {
        if visibleDocuments.contains(where: { $0.id == selectedDocumentId }) == false {
            selectedDocumentId = nil
        }
        try refreshSelectionArtifacts()
    }

    private func copySessionData() {
        guard let session else { return }
        entities = session.entities
        taxYears = session.taxYears
        financialAccounts = session.financialAccounts
        transactions = session.transactions
        documents = session.documents
        archivedDocuments = session.archivedDocuments
        importJobs = session.importJobs
        importDiagnosticsByJobId = session.importDiagnosticsByJobId
        issues = session.issues
        agentProposals = session.agentProposals
        taxFacts = session.taxFacts
        taxRequirements = session.taxRequirements
        taxIssues = session.taxIssues
        filingPackages = session.filingPackages
        vatPeriodReports = session.vatPeriodReports
        taxReadinessSummary = session.taxReadinessSummary
        linkedDocuments = session.linkedDocuments
        linkedTransactions = session.linkedTransactions
        selectedDocumentPreviewURL = session.selectedDocumentPreviewURL
        entityDeletionChecks = session.entityDeletionChecks
        accountBalanceById = session.accountBalanceById
        entityWorkspaces = session.entityWorkspaces
    }

    // MARK: - Import Helpers

    private func importCSV(url: URL) {
        guard let session, let selectedAccount = statementImportAccountId() else {
            return
        }
        perform {
            _ = try session.importJobService.importStatement(from: url, accountId: selectedAccount)
            try refreshData(recomputeEvidence: true)
        }
    }

    private func importDocument(url: URL) {
        guard let session else { return }
        perform {
            _ = try session.documentService.importDocument(from: url, entityId: session.activeEntityId)
            try refreshData(recomputeEvidence: true)
        }
    }

    private func importBundledSampleData() throws {
        guard let session, let selectedAccount = statementImportAccountId() else {
            throw DomainError.financialAccountNotFound
        }

        let csvURL = try bundledSampleURL(resource: "sample-bank-statement", pathExtension: "csv")
        let documentURL = try bundledSampleURL(resource: "sample-receipt", pathExtension: "pdf")

        _ = try session.importJobService.importStatement(from: csvURL, accountId: selectedAccount)
        _ = try session.documentService.importDocument(from: documentURL, entityId: session.activeEntityId)
        selectedAccountId = selectedAccount
        try refreshData(recomputeEvidence: true)
    }

    private func createDemoBusinessEntity() throws {
        guard let session else { return }
        let entity = try session.legalEntityService.createSoleProprietor(name: "Demo Sole Proprietor")
        try session.loadEntityWorkspaces()
        if let entityWorkspace = session.entityWorkspaces.first(where: { $0.entityId == entity.id }) {
            try session.switchEntity(to: entityWorkspace.id)
        }
        try refreshData(recomputeEvidence: false)
    }

    private func bundledSampleURL(resource: String, pathExtension: String) throws -> URL {
        guard let url = Bundle.main.url(forResource: resource, withExtension: pathExtension) else {
            throw BundledSampleResourceError(resourceName: "\(resource).\(pathExtension)")
        }
        return url
    }

    private func statementImportAccountId() -> FinancialAccountID? {
        if let preferredStatementImportAccountId,
           financialAccounts.contains(where: { $0.id == preferredStatementImportAccountId }) {
            return preferredStatementImportAccountId
        }

        if let selectedAccountId,
           financialAccounts.contains(where: { $0.id == selectedAccountId }) {
            return selectedAccountId
        }

        return financialAccounts.first?.id
    }

    private func demoWorkspaceName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "AlpenLedger Demo \(formatter.string(from: container.nowProvider()))"
    }

    private func reconcilePreferredStatementImportAccount() {
        guard let workspaceId = session?.storage.manifest.workspace.id else {
            preferredStatementImportAccountId = nil
            importDefaultsStatusMessage = nil
            return
        }

        guard let storedAccountId = uiPreferencesStore.preferredStatementImportAccountId(workspaceId: workspaceId),
              financialAccounts.contains(where: { $0.id == storedAccountId })
        else {
            preferredStatementImportAccountId = nil
            importDefaultsStatusMessage = nil
            return
        }

        preferredStatementImportAccountId = storedAccountId
    }

    // MARK: - Inspector Persistence

    private func restoreInspectorVisibility(for workspaceId: WorkspaceID) {
        isLedgerInspectorVisible = uiPreferencesStore.inspectorVisible(workspaceId: workspaceId, section: .ledger)
        isDocumentsInspectorVisible = uiPreferencesStore.inspectorVisible(workspaceId: workspaceId, section: .documents)
    }

    private func persistInspectorVisibility(for section: AppSection, isVisible: Bool) {
        guard let workspaceId = session?.storage.manifest.workspace.id else { return }
        uiPreferencesStore.setInspectorVisible(isVisible, workspaceId: workspaceId, section: section)
    }

    // MARK: - Error Handling

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            presentError(error)
        }
    }

    func dismissErrorAlert() {
        isShowingErrorAlert = false
        errorTitle = "Action could not be completed"
        errorMessage = nil
        errorRecoverySuggestion = nil
    }

    private func presentError(_ error: Error) {
        if let domainError = error as? DomainError {
            presentError(
                title: domainError.userFacingTitle,
                message: domainError.localizedDescription,
                recoverySuggestion: domainError.recoverySuggestion
            )
            return
        }

        let localizedError = error as? LocalizedError
        let nsError = error as NSError
        presentError(
            title: "Action could not be completed",
            message: localizedError?.errorDescription ?? nsError.localizedDescription,
            recoverySuggestion: localizedError?.recoverySuggestion
                ?? nsError.localizedRecoverySuggestion
                ?? "Try again. If the problem persists, export a support bundle from Settings when a workspace is available."
        )
    }

    private func presentError(title: String, message: String, recoverySuggestion: String?) {
        errorTitle = title
        errorMessage = message
        errorRecoverySuggestion = recoverySuggestion
        isShowingErrorAlert = true
    }

    private func defaultBackupFilename() -> String {
        let safeWorkspaceName = workspaceName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")
        let baseName = safeWorkspaceName.isEmpty ? "AlpenLedger" : safeWorkspaceName
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(baseName)-\(formatter.string(from: container.nowProvider())).alpenledgerbackup"
    }

    private func backupURLWithExpectedExtension(_ url: URL) -> URL {
        guard url.pathExtension != "alpenledgerbackup" else { return url }
        return url.appendingPathExtension("alpenledgerbackup")
    }

    private func defaultDiagnosticsFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "AlpenLedger-Diagnostics-\(formatter.string(from: container.nowProvider())).json"
    }

    private func diagnosticsURLWithExpectedExtension(_ url: URL) -> URL {
        guard url.pathExtension != "json" else { return url }
        return url.appendingPathExtension("json")
    }

    private func defaultSupportBundleFilename() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "AlpenLedger-Support-Bundle-\(formatter.string(from: container.nowProvider())).json"
    }

    private func supportBundleURLWithExpectedExtension(_ url: URL) -> URL {
        guard url.pathExtension != "json" else { return url }
        return url.appendingPathExtension("json")
    }

    // MARK: - Debug / QA

#if DEBUG
    func seedUIStateForTesting(
        entities: [LegalEntity] = [],
        financialAccounts: [FinancialAccount] = [],
        transactions: [Transaction] = [],
        documents: [Document] = [],
        archivedDocuments: [Document] = [],
        issues: [Issue] = [],
        agentProposals: [AgentProposal] = [],
        importJobs: [ImportJob] = [],
        importDiagnosticsByJobId: [ImportJobID: [ImportDiagnostic]] = [:],
        taxYears: [TaxYear] = [],
        taxRequirements: [Requirement] = [],
        taxFacts: [TaxFact] = [],
        filingPackages: [FilingPackage] = [],
        vatPeriodReports: [VATReconciliationReport] = [],
        selectedTaxEntityId: LegalEntityID? = nil,
        selectedTaxYearId: TaxYearID? = nil,
        taxReadinessSummary: TaxReadinessSummary = TaxReadinessSummary(
            state: .notStarted,
            openIssueCount: 0,
            pendingRequirementCount: 0,
            currentFactCount: 0,
            missingConceptCodes: []
        )
    ) {
        self.entities = entities
        self.financialAccounts = financialAccounts
        self.transactions = transactions
        self.documents = documents
        self.archivedDocuments = archivedDocuments
        self.issues = issues
        self.agentProposals = agentProposals
        self.importJobs = importJobs
        self.importDiagnosticsByJobId = importDiagnosticsByJobId
        self.taxYears = taxYears
        self.taxRequirements = taxRequirements
        self.taxFacts = taxFacts
        self.filingPackages = filingPackages
        self.vatPeriodReports = vatPeriodReports
        self.selectedTaxEntityId = selectedTaxEntityId
        self.selectedTaxYearId = selectedTaxYearId
        self.taxReadinessSummary = taxReadinessSummary
        self.accountBalanceById = Dictionary(
            uniqueKeysWithValues: financialAccounts.compactMap { account in
                let balance = account.currentBalanceMinor(
                    transactions: transactions.filter { $0.accountId == account.id }
                )
                return balance.map { (account.id, $0) }
            }
        )
    }
#endif

#if DEBUG
    func importQAValidationFixtures() {
        guard canImportQAValidationFixtures else { return }

        perform {
            let fixtureDirectory = try materializeQAValidationFixtures()
            let bankStatementURL = fixtureDirectory.appendingPathComponent("qa-ledger-stress-bank-statement.csv")
            importCSV(url: bankStatementURL)

            let documentURLs = try FileManager.default.contentsOfDirectory(
                at: fixtureDirectory,
                includingPropertiesForKeys: nil
            )
            .filter { $0.lastPathComponent != bankStatementURL.lastPathComponent }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

            for documentURL in documentURLs {
                importDocument(url: documentURL)
            }
        }
    }
#endif

#if DEBUG
    private func materializeQAValidationFixtures() throws -> URL {
        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AlpenLedger-QAValidationFixtures", isDirectory: true)
        try? FileManager.default.removeItem(at: fixtureDirectory)
        try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)

        let csvContents = """
        booking_date,value_date,amount,currency,counterparty,memo,reference,balance
        2026-01-05,2026-01-05,2500.00,CHF,Acme GmbH,Consulting Invoice,INV-1001,2500.00
        2026-01-08,2026-01-08,-42.50,CHF,Coffee Bar Zurich,Team Coffee,POS-444,2457.50
        2026-01-09,2026-01-09,-120.00,CHF,SBB,Travel Expense,TRV-220,2337.50
        2026-01-12,2026-01-12,-890.00,CHF,Confederation Insurance Cooperative of Zurich and Winterthur,Quarterly premium adjustment,INS-2026-01,1447.50
        2026-01-16,2026-01-16,-245.40,CHF,Swisscom Business Direct,Broadband and mobile bundle January,SCOM-7842,1202.10
        2026-01-20,2026-01-20,6400.00,CHF,Client Project Helvetia AG,Monthly retainer January,RET-2026-01,7602.10
        2026-01-21,2026-01-21,-18.60,CHF,Coffee Bar Zurich,Client meeting espresso bar receipt,POS-512,7583.50
        2026-01-23,2026-01-23,-1320.00,CHF,SBB Business Travel,Intercity half-fare plus meetings across cantons,TRV-449,6263.50
        2026-01-24,2026-01-24,-76.15,CHF,Office World Zürich HB,Archival folders and printer paper,OFF-2201,6187.35
        2026-01-25,2026-01-25,-540.00,CHF,Steuerberatung Muster & Partner AG,Quarterly bookkeeping review,CONS-912,5647.35
        2026-01-28,2026-01-28,-68.90,CHF,Coop City Bahnhofstrasse Zurich,Team lunch and supplies,POS-601,5578.45
        2026-01-30,2026-01-30,1200.00,CHF,Client Reimbursement Long Name Demonstration GmbH,Expense reimbursement batch A,REM-1200,6778.45
        """
        try csvContents.write(
            to: fixtureDirectory.appendingPathComponent("qa-ledger-stress-bank-statement.csv"),
            atomically: true,
            encoding: .utf8
        )

        if let sampleReceiptURL = Bundle.main.url(forResource: "sample-receipt", withExtension: "pdf") {
            let pdfCopies = [
                "2026-01-08 Coffee Bar Zurich receipt with an intentionally long archival filename for narrow-column verification.pdf",
                "2026-01-21 Coffee Bar Zurich second receipt long-name preview validation copy.pdf"
            ]
            for filename in pdfCopies {
                try? FileManager.default.removeItem(at: fixtureDirectory.appendingPathComponent(filename))
                try FileManager.default.copyItem(
                    at: sampleReceiptURL,
                    to: fixtureDirectory.appendingPathComponent(filename)
                )
            }
        }

        let textFixtures: [(String, String)] = [
            (
                "2026 Zurich main operating account statement with long descriptive filename for scope filtering and truncation.txt",
                """
                document_type: bank statement
                tax_year: 2026
                statement period: january 2026
                institution: Zuercher Kantonalbank
                """
            ),
            (
                "2026 Swiss health insurance annual tax certificate long descriptive filename.txt",
                """
                document_type: health insurance certificate
                tax_year: 2026
                health_insurance_premiums_minor: 420000
                currency: CHF
                """
            ),
            (
                "2026 Salary certificate archived with long filename for preview-unavailable validation.txt",
                """
                document_type: salary certificate
                tax_year: 2026
                salary_gross_minor: 9800000
                currency: CHF
                """
            ),
            (
                "2026 Pillar 3a annual contribution certificate with long filename.txt",
                """
                document_type: pillar 3a certificate
                tax_year: 2026
                pillar3a_contributions_minor: 705600
                currency: CHF
                """
            ),
            (
                "2026 supplier invoice exceptionally long filename for invoice grouping and search scope checks.txt",
                """
                document_type: invoice
                tax_year: 2026
                vendor: Swisscom Business Direct
                currency: CHF
                """
            )
        ]

        for (filename, contents) in textFixtures {
            try contents.write(
                to: fixtureDirectory.appendingPathComponent(filename),
                atomically: true,
                encoding: .utf8
            )
        }

        return fixtureDirectory
    }
#endif
}

private struct BundledSampleResourceError: LocalizedError {
    let resourceName: String

    var errorDescription: String? {
        "Bundled sample resource is missing: \(resourceName)."
    }

    var recoverySuggestion: String? {
        "Reinstall the app or verify that the sample resources are included in the app bundle."
    }
}
