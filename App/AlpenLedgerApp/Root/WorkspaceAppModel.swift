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

    private let container: DependencyContainer
    private let uiPreferencesStore: WorkspaceUIPreferencesStore

    var recentWorkspaces: [RecentWorkspaceReference] = []
    var newWorkspaceName = ""
    var newSolePropName = ""
    var documentSearchQuery = ""
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
    var isLedgerInspectorVisible = true
    var isDocumentsInspectorVisible = true
    var isShowingDocumentLinkSheet = false
    var isShowingTransactionLinkSheet = false
    var errorMessage: String?

    private(set) var storage: WorkspaceStorage?
    private(set) var auditLogger: AuditLogger?
    private(set) var provenanceTraceService: ProvenanceTraceService?
    private(set) var legalEntityService: LegalEntityService?
    private(set) var taxYearService: TaxYearService?
    private(set) var ledgerAccountService: LedgerAccountService?
    private(set) var financialAccountService: FinancialAccountService?
    private(set) var transactionService: TransactionService?
    private(set) var documentService: DocumentService?
    private(set) var documentQueryService: DocumentQueryService?
    private(set) var importJobService: ImportJobService?
    private(set) var evidenceRefreshService: EvidenceRefreshService?
    private(set) var issueService: IssueService?
    private(set) var reconciliationService: ReconciliationService?
    private(set) var taxFactService: TaxFactService?
    private(set) var taxComputationService: TaxComputationService?
    private(set) var taxValidationService: TaxValidationService?

    private(set) var entities: [LegalEntity] = []
    private(set) var taxYears: [TaxYear] = []
    private(set) var financialAccounts: [FinancialAccount] = []
    private(set) var transactions: [Transaction] = []
    private(set) var documents: [Document] = []
    private(set) var importJobs: [ImportJob] = []
    private(set) var issues: [Issue] = []
    private(set) var agentProposals: [AgentProposal] = []
    private(set) var taxFacts: [TaxFact] = []
    private(set) var taxRequirements: [Requirement] = []
    private(set) var taxIssues: [Issue] = []
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

    init(container: DependencyContainer) {
        self.container = container
        self.uiPreferencesStore = container.uiPreferencesStore
        reloadRecentWorkspaces()
    }

    var workspaceName: String {
        storage?.manifest.workspace.name ?? "AlpenLedger"
    }

    var hasWorkspace: Bool { storage != nil }
    var transactionCount: Int { transactions.count }
    var documentCount: Int { documents.count }
    var openIssueCount: Int { issues.filter { $0.status == .open }.count }
    var pendingProposalCount: Int { agentProposals.filter { $0.status == .pending }.count }
    var canImportCSV: Bool { hasWorkspace && (selectedAccountId != nil || financialAccounts.isEmpty == false) }
    var canImportDocument: Bool { hasWorkspace }
    var canImportSampleData: Bool { hasWorkspace }
    var currentSectionSubtitle: String { selectedSection.subtitle }
    var visibleTransactions: [Transaction] { transactions.filter { ledgerTransactionScope.matches($0) } }
    var visibleDocuments: [Document] {
        documents.filter { documentFilterScope.matches($0) && documentMatchesSearch($0) }
    }
    var ledgerInspectorButtonTitle: String { isLedgerInspectorVisible ? "Hide Inspector" : "Show Inspector" }
    var documentsInspectorButtonTitle: String { isDocumentsInspectorVisible ? "Hide Inspector" : "Show Inspector" }
    var activeInspectorToggleTitle: String {
        switch selectedSection {
        case .ledger:
            return ledgerInspectorButtonTitle
        case .documents:
            return documentsInspectorButtonTitle
        case .overview, .inbox, .taxStudio, .settings:
            return "Toggle Inspector"
        }
    }
    var selectedAccountTitle: String? { selectedAccountName }
    var selectedDocumentName: String? {
        documents.first(where: { $0.id == selectedDocumentId })?.originalFilename
    }
    var canToggleActiveInspector: Bool {
        hasWorkspace && (selectedSection == .ledger || selectedSection == .documents)
    }
    var canLinkSelectedDocument: Bool {
        selectedSection == .ledger && selectedTransactionId != nil
    }
    var canLinkSelectedTransaction: Bool {
        selectedSection == .documents && selectedDocumentId != nil
    }

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
        case .overview, .inbox, .taxStudio, .settings:
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
            recentWorkspaces: recentWorkspaces.map { reference in
                WorkspaceChooserSnapshot.RecentWorkspace(
                    reference: reference,
                    title: reference.name,
                    lastOpenedText: relativeDateString(for: reference.lastOpenedAt)
                )
            }
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
                typeLabel: documentTypeLabel(document.documentType),
                dateLabel: formattedDate(document.issueDate),
                statusText: metadataLabel(document.metadataStatus),
                tone: document.metadataStatus == .confirmed ? .success : .warning,
                systemImage: documentSymbol(document.documentType),
                issueDate: document.issueDate,
                mediaType: document.mediaType
            )
        }
    }

    var taxStudioSnapshot: TaxStudioSnapshot {
        TaxStudioSnapshot(
            readinessTitle: readinessTitle(taxReadinessSummary.state),
            readinessSummary: "\(taxReadinessSummary.openIssueCount) open issues • \(taxReadinessSummary.pendingRequirementCount) pending requirements",
            readinessTone: readinessTone(taxReadinessSummary.state),
            checklistItems: taxChecklistItems,
            factCategories: taxFactCategories,
            inspector: taxInspector
        )
    }

    var settingsSnapshot: SettingsSnapshot {
        SettingsSnapshot(
            workspace: SettingsSnapshot.WorkspaceDetails(
                name: workspaceName,
                type: "Local encrypted workspace",
                location: storage?.paths.rootURL.path ?? "Not available",
                encryptionStatus: "Encrypted locally",
                createdAt: formattedDate(storage?.manifest.workspace.createdAt)
            ),
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

    func reloadRecentWorkspaces() {
        recentWorkspaces = container.workspaceService.recentWorkspaces()
    }

    func createWorkspace() {
        perform {
            let openedStorage = try container.workspaceService.createWorkspace(named: newWorkspaceName)
            newWorkspaceName = ""
            isShowingNewWorkspaceSheet = false
            configure(openedStorage)
        }
    }

    func openWorkspace(_ reference: RecentWorkspaceReference) {
        perform {
            let openedStorage = try container.workspaceService.openWorkspace(at: URL(fileURLWithPath: reference.path))
            isShowingNewWorkspaceSheet = false
            configure(openedStorage)
        }
    }

    func openExistingWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Workspace"
        if panel.runModal() == .OK, let url = panel.url {
            perform {
                let openedStorage = try container.workspaceService.openWorkspace(at: url)
                isShowingNewWorkspaceSheet = false
                configure(openedStorage)
            }
        }
    }

    func presentNewWorkspaceSheet() {
        newWorkspaceName = ""
        isShowingNewWorkspaceSheet = true
    }

    func dismissNewWorkspaceSheet() {
        isShowingNewWorkspaceSheet = false
    }

    func createSoleProp() {
        guard let legalEntityService else { return }
        perform {
            _ = try legalEntityService.createSoleProprietor(name: newSolePropName)
            newSolePropName = ""
            try refreshData(recomputeEvidence: false)
        }
    }

    func renameWorkspace(to name: String) {
        guard let storage else { return }
        perform {
            let reopenedStorage = try container.workspaceService.renameWorkspace(storage, name: name)
            bindStorage(reopenedStorage)
            try refreshData(recomputeEvidence: false)
        }
    }

    func updateEntityName(_ entityId: LegalEntityID, name: String) {
        guard let legalEntityService,
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
            try legalEntityService.updateEntity(updatedEntity)
            try refreshData(recomputeEvidence: false)
        }
    }

    func removeEntity(_ entityId: LegalEntityID) {
        guard let legalEntityService else { return }
        perform {
            let deletionCheck = try legalEntityService.deleteEntity(entityId)
            if deletionCheck.canDelete == false {
                errorMessage = blockedEntityDeletionMessage(for: deletionCheck)
                return
            }

            if selectedTaxEntityId == entityId {
                selectedTaxEntityId = nil
            }
            try refreshData(recomputeEvidence: false)
        }
    }

    func openInbox() {
        selectedSection = .inbox
    }

    func navigate(to section: AppSection) {
        selectedSection = section
    }

    func performShellToolbarInspectorAction() {
        toggleInspectorForActiveSection()
    }

    func performInboxAction(_ action: InboxAction) {
        switch action {
        case let .resolveIssue(issueId):
            guard let issueService else { return }
            perform {
                _ = try issueService.resolveIssue(issueId, now: container.nowProvider())
                try refreshData(recomputeEvidence: false)
            }
        case let .dismissIssue(issueId):
            guard let issueService else { return }
            perform {
                _ = try issueService.dismissIssue(issueId, now: container.nowProvider())
                try refreshData(recomputeEvidence: false)
            }
        case let .importStatement(accountId):
            if let accountId {
                selectedAccountId = accountId
            }
            selectedSection = .ledger
            importCSVFromPanel()
        case let .linkDocument(transactionId):
            guard let transaction = transactionById(transactionId) else { return }
            openLedger(accountId: transaction.accountId, transactionId: transaction.id)
            presentDocumentLinkSheet()
        case let .linkTransaction(documentId):
            openDocuments(documentId: documentId)
            presentTransactionLinkSheet()
        case let .openProposalTarget(objectRef):
            openObjectRef(objectRef)
        case let .rejectProposal(proposalId):
            guard let reconciliationService else { return }
            perform {
                _ = try reconciliationService.rejectProposal(proposalId, now: container.nowProvider())
                try refreshData(recomputeEvidence: false)
            }
        }
    }

    func importDocumentURLs(_ urls: [URL]) {
        guard let documentService, urls.isEmpty == false else { return }
        perform {
            for url in urls {
                _ = try documentService.importDocument(from: url)
            }
            try refreshData(recomputeEvidence: true)
        }
    }

    func selectTaxStudioSelection(_ selection: TaxStudioSelection?) {
        selectedTaxStudioSelection = selection
        if case let .fact(factId) = selection {
            selectedTaxFactId = factId
        } else {
            selectedTaxFactId = nil
        }
    }

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
        case .overview, .inbox, .taxStudio, .settings:
            break
        }
    }

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

    private func openLedger(accountId: FinancialAccountID?, transactionId: TransactionID?) {
        selectedSection = .ledger
        selectedAccountId = accountId ?? selectedAccountId
        selectedTransactionId = transactionId

        guard transactionService != nil else {
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

    private func openDocuments(documentId: DocumentID?) {
        selectedSection = .documents
        selectedDocumentId = documentId

        guard documentQueryService != nil else {
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

    private func openTaxStudio(entityId: LegalEntityID?, taxYearId: TaxYearID?, factId: TaxFactID?) {
        selectedSection = .taxStudio
        if let entityId {
            selectedTaxEntityId = entityId
        }
        if let taxYearId {
            selectedTaxYearId = taxYearId
        }
        selectedTaxFactId = factId
        selectedTaxStudioSelection = factId.map(TaxStudioSelection.fact)

        guard storage != nil else { return }

        perform {
            try refreshTaxStudio(recomputeFacts: false)
            if let factId, taxFacts.contains(where: { $0.id == factId }) == false {
                selectedTaxFactId = nil
            }
        }
    }

    func importSampleData() {
        importSampleCSV()
        importSampleDocument()
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

    func presentDocumentLinkSheet() {
        guard selectedTransactionId != nil else { return }
        isShowingDocumentLinkSheet = true
    }

    func presentTransactionLinkSheet() {
        guard selectedDocumentId != nil else { return }
        isShowingTransactionLinkSheet = true
    }

    func linkSelectedDocumentToCurrentTransaction(documentId: DocumentID) {
        guard let selectedTransactionId, let documentService else { return }
        perform {
            try documentService.linkDocument(documentId, to: selectedTransactionId)
            isShowingDocumentLinkSheet = false
            try refreshData(recomputeEvidence: true)
        }
    }

    func linkCurrentDocumentToTransaction(transactionId: TransactionID) {
        guard let selectedDocumentId, let documentService else { return }
        perform {
            try documentService.linkDocument(selectedDocumentId, to: transactionId)
            isShowingTransactionLinkSheet = false
            try refreshData(recomputeEvidence: true)
        }
    }

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
        case .overview, .settings:
            return nil
        }
    }

#if DEBUG
    func importQAValidationFixtures() {
        guard hasWorkspace else { return }

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

    private func importCSV(url: URL) {
        guard let importJobService, let selectedAccount = selectedAccountId ?? financialAccounts.first?.id else {
            return
        }
        perform {
            _ = try importJobService.importStatement(from: url, accountId: selectedAccount)
            try refreshData(recomputeEvidence: true)
        }
    }

    private func importDocument(url: URL) {
        guard let documentService else { return }
        perform {
            _ = try documentService.importDocument(from: url)
            try refreshData(recomputeEvidence: true)
        }
    }

    private func configure(_ storage: WorkspaceStorage) {
        self.storage = storage
        selectedSection = .overview
        documentSearchQuery = ""
        ledgerTransactionScope = .all
        documentFilterScope = .all
        restoreInspectorVisibility(for: storage.manifest.workspace.id)
        bindStorage(storage)
        perform {
            try refreshData(recomputeEvidence: true)
        }
    }

    private func bindStorage(_ storage: WorkspaceStorage) {
        self.storage = storage

        let auditLogger = AuditLogger(storage: storage)
        self.auditLogger = auditLogger
        provenanceTraceService = ProvenanceTraceService(storage: storage)
        legalEntityService = LegalEntityService(storage: storage, auditLogger: auditLogger, nowProvider: container.nowProvider)
        taxYearService = TaxYearService(storage: storage)
        ledgerAccountService = LedgerAccountService(storage: storage)
        financialAccountService = FinancialAccountService(storage: storage)
        transactionService = TransactionService(storage: storage)
        documentService = DocumentService(storage: storage, auditLogger: auditLogger)
        documentQueryService = DocumentQueryService(storage: storage)
        importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
        evidenceRefreshService = EvidenceRefreshService(storage: storage, auditLogger: auditLogger, nowProvider: container.nowProvider)
        issueService = IssueService(storage: storage, auditLogger: auditLogger)
        reconciliationService = ReconciliationService(storage: storage, auditLogger: auditLogger)

        let rulePackRegistry = RulePackRegistry()
        rulePackRegistry.registerPersonalTaxRulePack(ZurichPersonalTaxAdapter2026())

        let taxFactService = TaxFactService(storage: storage)
        self.taxFactService = taxFactService
        taxComputationService = TaxComputationService(
            storage: storage,
            rulePackRegistry: rulePackRegistry,
            factService: taxFactService,
            nowProvider: container.nowProvider
        )
        taxValidationService = TaxValidationService(storage: storage, rulePackRegistry: rulePackRegistry)

        reloadRecentWorkspaces()
    }

    private func refreshData(recomputeEvidence: Bool = false) throws {
        guard let storage, let legalEntityService, let financialAccountService else { return }
        if recomputeEvidence {
            try evidenceRefreshService?.refresh()
        }

        entities = try legalEntityService.listEntities()
        entityDeletionChecks = try entities.reduce(into: [:]) { checks, entity in
            checks[entity.id] = try legalEntityService.deletionCheck(for: entity.id)
        }
        let sortedAccounts = try entities
            .flatMap { try financialAccountService.listAccounts(entityId: $0.id) }
            .sorted { $0.displayName < $1.displayName }
        financialAccounts = sortedAccounts
        accountBalanceById = try sortedAccounts.reduce(into: [:]) { balances, account in
            let accountTransactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)
            if let latestBalance = accountTransactions.first(where: { $0.balanceAfterMinor != nil })?.balanceAfterMinor {
                balances[account.id] = latestBalance
            }
        }

        if let selectedAccountId, sortedAccounts.contains(where: { $0.id == selectedAccountId }) == false {
            self.selectedAccountId = nil
        }

        try refreshTransactions()
        try refreshDocuments()
        try refreshInbox()
        try refreshTaxStudio(recomputeFacts: recomputeEvidence)
    }

    private func refreshTransactions() throws {
        guard let transactionService, let selectedAccount = selectedAccountId else {
            transactions = []
            selectedTransactionId = nil
            linkedDocuments = []
            return
        }

        transactions = try transactionService.listTransactions(accountId: selectedAccount)
        try reconcileTransactionSelection()
    }

    private func refreshDocuments() throws {
        guard let documentQueryService else {
            documents = []
            selectedDocumentId = nil
            linkedTransactions = []
            return
        }

        documents = try documentQueryService.listDocuments()
        try reconcileDocumentSelection()
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

    private func documentMatchesSearch(_ document: Document) -> Bool {
        let trimmedQuery = documentSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return true }

        let searchableContent = [
            document.originalFilename,
            document.extractedText ?? "",
            document.mediaType,
            document.documentType.rawValue
        ]
        .joined(separator: "\n")

        return searchableContent.localizedCaseInsensitiveContains(trimmedQuery)
    }

    private func refreshSelectionArtifacts() throws {
        guard let storage, let documentService, let transactionService else { return }

        if let selectedTransactionId {
            let documentIDs = try transactionService.linkedDocumentIDs(for: selectedTransactionId)
            linkedDocuments = try storage.documentRepository.fetchDocuments(ids: documentIDs)
        } else {
            linkedDocuments = []
        }

        if let selectedDocumentId {
            let transactionIDs = try documentService.linkedTransactionIDs(for: selectedDocumentId)
            linkedTransactions = try storage.transactionRepository.fetchTransactions(ids: transactionIDs)
            if let document = try storage.documentRepository.fetchDocument(id: selectedDocumentId) {
                selectedDocumentPreviewURL = try documentService.binaryRef(for: document).fileURL
            } else {
                selectedDocumentPreviewURL = nil
            }
        } else {
            linkedTransactions = []
            selectedDocumentPreviewURL = nil
        }

        if let selectedTaxStudioSelection, containsTaxStudioSelection(selectedTaxStudioSelection) == false {
            self.selectedTaxStudioSelection = nil
        }
    }

    private func restoreInspectorVisibility(for workspaceId: WorkspaceID) {
        isLedgerInspectorVisible = uiPreferencesStore.inspectorVisible(workspaceId: workspaceId, section: .ledger)
        isDocumentsInspectorVisible = uiPreferencesStore.inspectorVisible(workspaceId: workspaceId, section: .documents)
    }

    private func persistInspectorVisibility(for section: AppSection, isVisible: Bool) {
        guard let workspaceId = storage?.manifest.workspace.id else { return }
        uiPreferencesStore.setInspectorVisible(isVisible, workspaceId: workspaceId, section: section)
    }

#if DEBUG
    func seedUIStateForTesting(
        financialAccounts: [FinancialAccount] = [],
        transactions: [Transaction] = [],
        documents: [Document] = [],
        issues: [Issue] = [],
        agentProposals: [AgentProposal] = [],
        taxRequirements: [Requirement] = [],
        taxFacts: [TaxFact] = [],
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
        self.financialAccounts = financialAccounts
        self.transactions = transactions
        self.documents = documents
        self.issues = issues
        self.agentProposals = agentProposals
        self.taxRequirements = taxRequirements
        self.taxFacts = taxFacts
        self.selectedTaxEntityId = selectedTaxEntityId
        self.selectedTaxYearId = selectedTaxYearId
        self.taxReadinessSummary = taxReadinessSummary
        self.accountBalanceById = Dictionary(
            uniqueKeysWithValues: financialAccounts.compactMap { account in
                let latestBalance = transactions
                    .filter { $0.accountId == account.id }
                    .sorted { $0.bookingDate > $1.bookingDate }
                    .compactMap(\.balanceAfterMinor)
                    .first
                return latestBalance.map { (account.id, $0) }
            }
        )
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

    private func refreshInbox() throws {
        importJobs = try importJobService?.listImportJobs() ?? []
        issues = try evidenceRefreshService?.listIssues(status: .open) ?? []
        agentProposals = try evidenceRefreshService?.listProposals(status: .pending) ?? []

        if let selection = selectedInboxSelection, containsInboxSelection(selection) == false {
            selectedInboxSelection = nil
        }
    }

    private func refreshTaxStudio(recomputeFacts: Bool = false) throws {
        guard let storage else {
            taxYears = []
            taxFacts = []
            taxRequirements = []
            taxIssues = []
            taxReadinessSummary = TaxReadinessSummary(
                state: .notStarted,
                openIssueCount: 0,
                pendingRequirementCount: 0,
                currentFactCount: 0,
                missingConceptCodes: []
            )
            return
        }

        if let selectedTaxEntityId, entities.contains(where: { $0.id == selectedTaxEntityId }) == false {
            self.selectedTaxEntityId = nil
        }
        if self.selectedTaxEntityId == nil {
            self.selectedTaxEntityId = entities.first(where: { $0.kind == .naturalPerson })?.id ?? entities.first?.id
        }
        guard let selectedTaxEntityId,
              let selectedEntity = entities.first(where: { $0.id == selectedTaxEntityId })
        else {
            taxYears = []
            taxFacts = []
            taxRequirements = []
            taxIssues = []
            return
        }

        taxYears = try taxYearService?.listTaxYears(entityId: selectedTaxEntityId) ?? []
        if let selectedTaxYearId, taxYears.contains(where: { $0.id == selectedTaxYearId }) == false {
            self.selectedTaxYearId = nil
        }
        if self.selectedTaxYearId == nil {
            self.selectedTaxYearId = taxYears.first?.id
        }
        guard let selectedTaxYearId,
              let selectedTaxYear = taxYears.first(where: { $0.id == selectedTaxYearId })
        else {
            taxFacts = []
            taxRequirements = []
            taxIssues = []
            taxReadinessSummary = TaxReadinessSummary(
                state: .notStarted,
                openIssueCount: 0,
                pendingRequirementCount: 0,
                currentFactCount: 0,
                missingConceptCodes: []
            )
            return
        }

        if recomputeFacts {
            _ = try taxComputationService?.refreshFacts(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
        }

        taxFacts = try taxFactService?.listTaxFacts(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId) ?? []
        taxRequirements = try storage.requirementRepository
            .fetchRequirements(entityId: selectedTaxEntityId, taxYearId: selectedTaxYearId)
            .filter { $0.status == .pending }
        taxIssues = try storage.issueRepository.fetchIssues(
            workspaceId: storage.manifest.workspace.id,
            entityId: selectedTaxEntityId,
            taxYearId: selectedTaxYearId,
            status: .open
        )
        taxReadinessSummary = try taxValidationService?.readinessSummary(
            entity: selectedEntity,
            taxYear: selectedTaxYear,
            currentFacts: taxFacts
        ) ?? TaxReadinessSummary(
            state: .notStarted,
            openIssueCount: 0,
            pendingRequirementCount: 0,
            currentFactCount: 0,
            missingConceptCodes: []
        )

        if let selectedTaxFactId, taxFacts.contains(where: { $0.id == selectedTaxFactId }) == false {
            self.selectedTaxFactId = nil
        }
        if let selectedTaxStudioSelection, containsTaxStudioSelection(selectedTaxStudioSelection) == false {
            self.selectedTaxStudioSelection = nil
        }
    }

    private func containsInboxSelection(_ selection: InboxSelection) -> Bool {
        switch selection {
        case let .importJob(importJobId):
            return importJobs.contains { $0.id == importJobId }
        case let .proposal(proposalId):
            return agentProposals.contains { $0.id == proposalId }
        case let .issue(issueId):
            return issues.contains { $0.id == issueId }
        }
    }

    private func containsTaxStudioSelection(_ selection: TaxStudioSelection) -> Bool {
        switch selection {
        case let .issue(issueId):
            return taxIssues.contains { $0.id == issueId }
        case let .requirement(requirementId):
            return taxRequirements.contains { $0.id == requirementId }
        case let .fact(factId):
            return taxFacts.contains { $0.id == factId }
        case let .missingConcept(conceptCode):
            return taxReadinessSummary.missingConceptCodes.contains(conceptCode)
        }
    }

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var workspaceSummarySubtitle: String {
        let entityLabel = "\(entities.count) \(entities.count == 1 ? "entity" : "entities")"
        let accountLabel = "\(financialAccounts.count) \(financialAccounts.count == 1 ? "account" : "accounts")"
        let documentLabel = "\(documents.count) \(documents.count == 1 ? "document" : "documents")"
        return [entityLabel, accountLabel, documentLabel].joined(separator: " • ")
    }

    private var overviewMetrics: [OverviewSnapshot.MetricItem] {
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

    private var overviewActionItems: [OverviewSnapshot.ActionItem] {
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

    private var overviewPriorityAction: OverviewSnapshot.ActionItem? {
        overviewActionItems.first
    }

    private var overviewSecondaryActions: [OverviewSnapshot.ActionItem] {
        Array(overviewActionItems.dropFirst().prefix(2))
    }

    private var overviewAttentionItems: [OverviewSnapshot.AttentionItem] {
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
                    statusText: "Proposal",
                    tone: .info,
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

    private var overviewRecentActivityItems: [OverviewSnapshot.RecentActivityItem] {
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

    private var inboxRows: [InboxRowModel] {
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
                    statusText: "\(Int(proposal.confidence * 100))%",
                    tone: .info,
                    systemImage: "wand.and.stars",
                    searchText: [proposal.summary, proposal.rationale, proposal.targetRef.stringValue].joined(separator: "\n")
                )
            }

        let importRows = importJobs.map { job in
            InboxRowModel(
                id: job.id.rawValue.uuidString,
                selection: .importJob(job.id),
                tab: .imports,
                groupTitle: importKindLabel(job.kind),
                title: job.source,
                subtitle: importKindLabel(job.kind),
                meta: importTimestampLabel(job),
                statusText: importStatusLabel(job.status),
                tone: tone(for: job.status),
                systemImage: "tray.full",
                searchText: [job.source, importKindLabel(job.kind), importStatusLabel(job.status)].joined(separator: "\n")
            )
        }

        return issueRows + proposalRows + importRows
    }

    private var inboxInspector: InboxInspectorModel? {
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
                actions: issueInspectorActions(issue)
            )
        case let .proposal(proposalId):
            guard let proposal = agentProposals.first(where: { $0.id == proposalId }) else { return nil }
            return InboxInspectorModel(
                title: proposal.summary,
                subtitle: "Proposal",
                statusText: "Pending",
                tone: .info,
                description: proposal.rationale,
                details: [
                    InboxInspectorDetail(id: "confidence", label: "Confidence", value: "\(Int(proposal.confidence * 100))%"),
                    InboxInspectorDetail(id: "target", label: "Target", value: proposal.targetRef.stringValue),
                ],
                actions: proposalInspectorActions(proposal)
            )
        case let .importJob(importJobId):
            guard let job = importJobs.first(where: { $0.id == importJobId }) else { return nil }
            return InboxInspectorModel(
                title: job.source,
                subtitle: importKindLabel(job.kind),
                statusText: importStatusLabel(job.status),
                tone: tone(for: job.status),
                description: "Import jobs are read-only. Use the document or ledger views to continue review.",
                details: [
                    InboxInspectorDetail(id: "kind", label: "Kind", value: importKindLabel(job.kind)),
                    InboxInspectorDetail(id: "parser", label: "Parser", value: "\(job.parserKey) \(job.parserVersion)"),
                    InboxInspectorDetail(id: "warnings", label: "Warnings", value: job.warningCount.formatted()),
                ],
                actions: []
            )
        }
    }

    private var taxChecklistItems: [TaxChecklistItem] {
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

        return issueItems + requirementItems + missingFactItems
    }

    private var taxFactCategories: [TaxFactCategoryModel] {
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

    private var taxInspector: TaxInspectorModel? {
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
        }
    }

    private var latestImportSummary: String? {
        guard let latest = importJobs.sorted(by: importSortOrder).first else {
            return nil
        }
        return importTimestampLabel(latest)
    }

    private var selectedAccountName: String? {
        financialAccounts.first(where: { $0.id == selectedAccountId })?.displayName
    }

    private var firstOpenIssueSelection: InboxSelection? {
        issues
            .sorted { lhs, rhs in
                issuePriority(lhs.severity) > issuePriority(rhs.severity)
            }
            .first
            .map { .issue($0.id) }
    }

    private var firstPendingProposalSelection: InboxSelection? {
        agentProposals
            .filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
            .first
            .map { .proposal($0.id) }
    }

    private func issueInspectorDetails(_ issue: Issue) -> [InboxInspectorDetail] {
        var details = [
            InboxInspectorDetail(id: "status", label: "Status", value: issue.status.rawValue.capitalized),
            InboxInspectorDetail(id: "object", label: "Object", value: issue.objectRef.stringValue),
        ]
        if let relatedRef = issue.relatedRef {
            details.append(InboxInspectorDetail(id: "related", label: "Related", value: relatedRef.stringValue))
        }
        return details
    }

    private func issueInspectorActions(_ issue: Issue) -> [InboxInspectorAction] {
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
        }

        return actions
    }

    private func proposalInspectorActions(_ proposal: AgentProposal) -> [InboxInspectorAction] {
        var actions = [
            InboxInspectorAction(
                id: "open-\(proposal.id.rawValue.uuidString)",
                title: "Open",
                role: .primary,
                action: .openProposalTarget(proposal.targetRef)
            ),
            InboxInspectorAction(
                id: "reject-\(proposal.id.rawValue.uuidString)",
                title: "Reject",
                role: .destructive,
                action: .rejectProposal(proposal.id)
            ),
        ]

        if proposal.targetRef.kind == .document, let documentId = documentId(from: proposal.targetRef) {
            actions.insert(
                InboxInspectorAction(
                    id: "link-\(proposal.id.rawValue.uuidString)",
                    title: "Link Transaction…",
                    role: .secondary,
                    action: .linkTransaction(documentId)
                ),
                at: 1
            )
        }

        return actions
    }

    private func makeTaxFactCategory(id: String, title: String, prefix: String) -> TaxFactCategoryModel {
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

    private func openObjectRef(_ objectRef: ObjectRef) {
        switch objectRef.kind {
        case .document:
            openDocuments(documentId: documentId(from: objectRef))
        case .transaction:
            if let transactionId = transactionId(from: objectRef),
               let transaction = transactionById(transactionId) {
                openLedger(accountId: transaction.accountId, transactionId: transaction.id)
            }
        case .financialAccount:
            openLedger(accountId: financialAccountId(from: objectRef), transactionId: nil)
        case .issue:
            selectedSection = .inbox
            if let issueId = issueId(from: objectRef) {
                selectedInboxSelection = .issue(issueId)
            }
        default:
            break
        }
    }

    private func blockedEntityDeletionMessage(for check: LegalEntityService.DeletionCheck) -> String {
        var reasons: [String] = []
        if check.statementImportCount > 0 {
            reasons.append("\(check.statementImportCount) statement import\(check.statementImportCount == 1 ? "" : "s")")
        }
        if check.transactionCount > 0 {
            reasons.append("\(check.transactionCount) transaction\(check.transactionCount == 1 ? "" : "s")")
        }
        if check.documentCount > 0 {
            reasons.append("\(check.documentCount) document\(check.documentCount == 1 ? "" : "s")")
        }
        if check.taxFactCount > 0 {
            reasons.append("\(check.taxFactCount) tax fact\(check.taxFactCount == 1 ? "" : "s")")
        }
        if check.issueCount > 0 {
            reasons.append("\(check.issueCount) issue\(check.issueCount == 1 ? "" : "s")")
        }
        if check.requirementCount > 0 {
            reasons.append("\(check.requirementCount) requirement\(check.requirementCount == 1 ? "" : "s")")
        }
        return "This entity still has dependent data: \(reasons.joined(separator: ", "))."
    }

    private func deletionRemovalHint(_ check: LegalEntityService.DeletionCheck?) -> String? {
        guard let check, check.canDelete == false else { return nil }
        return blockedEntityDeletionMessage(for: check)
    }

    private func importSortOrder(lhs: ImportJob, rhs: ImportJob) -> Bool {
        let lhsDate = lhs.completedAt ?? lhs.startedAt
        let rhsDate = rhs.completedAt ?? rhs.startedAt
        return lhsDate > rhsDate
    }

    private func importKindLabel(_ kind: ImportJobKind) -> String {
        switch kind {
        case .bankStatementCSV:
            return "Bank Statement"
        case .documentIntake:
            return "Document Intake"
        }
    }

    private func importStatusLabel(_ status: ImportJobStatus) -> String {
        switch status {
        case .started:
            return "Started"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    private func importTimestampLabel(_ job: ImportJob) -> String {
        let timestamp = job.completedAt ?? job.startedAt
        return timestamp.formatted(date: .abbreviated, time: .shortened)
    }

    private func tone(for status: ImportJobStatus) -> StatusBadge.Tone {
        switch status {
        case .started:
            return .warning
        case .completed:
            return .success
        case .failed:
            return .critical
        }
    }

    private func issuePriority(_ severity: IssueSeverity) -> Int {
        switch severity {
        case .blocking:
            return 2
        case .warning:
            return 1
        }
    }

    private func readinessTone(_ state: TaxReadinessState) -> StatusBadge.Tone {
        switch state {
        case .notStarted:
            return .neutral
        case .needsAttention:
            return .warning
        case .readyForReview:
            return .success
        }
    }

    private func readinessTitle(_ state: TaxReadinessState) -> String {
        switch state {
        case .notStarted:
            return "Not Started"
        case .needsAttention:
            return "Needs Attention"
        case .readyForReview:
            return "Ready for Review"
        }
    }

    private func shortIssueTitle(_ issue: Issue) -> String {
        switch issue.issueCode {
        case .missingStatementCoverage:
            return "Statement missing"
        case .missingExpenseEvidence:
            return "Expense evidence missing"
        }
    }

    private func shortRequirementTitle(_ requirement: Requirement) -> String {
        switch requirement.requirementCode {
        case .statementCoverage:
            return "Statement coverage required"
        case .expenseEvidence:
            return "Supporting evidence required"
        }
    }

    private func entityName(for entityId: LegalEntityID?) -> String? {
        guard let entityId else { return nil }
        return entities.first(where: { $0.id == entityId })?.displayName
    }

    private func financialAccountId(from ref: ObjectRef) -> FinancialAccountID? {
        guard ref.kind == .financialAccount, let uuid = UUID(uuidString: ref.id) else { return nil }
        return FinancialAccountID(rawValue: uuid)
    }

    private func transactionId(from ref: ObjectRef) -> TransactionID? {
        guard ref.kind == .transaction, let uuid = UUID(uuidString: ref.id) else { return nil }
        return TransactionID(rawValue: uuid)
    }

    private func documentId(from ref: ObjectRef) -> DocumentID? {
        guard ref.kind == .document, let uuid = UUID(uuidString: ref.id) else { return nil }
        return DocumentID(rawValue: uuid)
    }

    private func issueId(from ref: ObjectRef) -> IssueID? {
        guard ref.kind == .issue, let uuid = UUID(uuidString: ref.id) else { return nil }
        return IssueID(rawValue: uuid)
    }

    private func transactionById(_ transactionId: TransactionID) -> Transaction? {
        transactions.first(where: { $0.id == transactionId })
            ?? linkedTransactions.first(where: { $0.id == transactionId })
    }

    private func coverageLabel(start: Date?, end: Date?) -> String {
        let startText = formattedDate(start)
        let endText = formattedDate(end)
        if start == nil && end == nil {
            return "n/a"
        }
        return "\(startText) to \(endText)"
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "n/a" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: container.nowProvider())
    }

    private func amountString(_ amountMinor: Int64, currency: String) -> String {
        let value = Decimal(amountMinor) / 100
        return "\(NSDecimalNumber(decimal: value).stringValue) \(currency)"
    }

    private func accountTypeLabel(_ accountType: FinancialAccountType) -> String {
        switch accountType {
        case .bank:
            return "Bank"
        case .card:
            return "Card"
        case .cash:
            return "Cash"
        case .receivable:
            return "Receivable"
        case .payable:
            return "Payable"
        case .loan:
            return "Loan"
        }
    }

    private func symbol(for accountType: FinancialAccountType) -> String {
        switch accountType {
        case .bank:
            return "building.columns"
        case .card:
            return "creditcard"
        case .cash:
            return "banknote"
        case .receivable:
            return "arrow.down.circle"
        case .payable:
            return "arrow.up.circle"
        case .loan:
            return "chart.bar.doc.horizontal"
        }
    }

    private func documentTypeLabel(_ documentType: DocumentType) -> String {
        switch documentType {
        case .unknown:
            return "Unsorted"
        case .receipt:
            return "Receipt"
        case .invoice:
            return "Invoice"
        case .bankStatement:
            return "Statement"
        case .salaryCertificate:
            return "Salary Certificate"
        case .healthInsuranceCertificate:
            return "Health Insurance"
        case .pillar3aCertificate:
            return "Pillar 3a"
        }
    }

    private func metadataLabel(_ status: MetadataStatus) -> String {
        switch status {
        case .proposed:
            return "Proposed"
        case .confirmed:
            return "Confirmed"
        }
    }

    private func documentSymbol(_ documentType: DocumentType) -> String {
        switch documentType {
        case .bankStatement:
            return "doc.text"
        case .salaryCertificate:
            return "doc.badge.gearshape"
        case .healthInsuranceCertificate:
            return "cross.case"
        case .pillar3aCertificate:
            return "leaf"
        case .receipt, .invoice:
            return "doc.richtext"
        case .unknown:
            return "doc"
        }
    }

    private func entityKindLabel(_ kind: LegalEntityKind) -> String {
        switch kind {
        case .naturalPerson:
            return "Natural Person"
        case .soleProprietor:
            return "Sole Proprietor"
        case .corporation:
            return "Corporation"
        }
    }

    private func factLabel(for conceptCode: String) -> String {
        switch conceptCode {
        case "personal.income.salary_gross":
            return "Salary Gross"
        case "personal.deduction.health_insurance_premiums":
            return "Health Insurance Premiums"
        case "personal.deduction.pillar3a_contributions":
            return "Pillar 3a Contributions"
        case "personal.self_employment.revenue_gross":
            return "Revenue Gross"
        case "personal.self_employment.expense_total":
            return "Expense Total"
        case "personal.self_employment.net_profit":
            return "Net Profit"
        default:
            return conceptCode
        }
    }

    private func valueString(for fact: TaxFact) -> String {
        switch fact.valueType {
        case .money:
            let amount = Decimal(fact.moneyMinor ?? 0) / 100
            let number = NSDecimalNumber(decimal: amount).stringValue
            return "\(number) \(fact.currency ?? "CHF")"
        case .text:
            return fact.textValue ?? "n/a"
        case .bool:
            return (fact.boolValue ?? false) ? "Yes" : "No"
        case .date:
            guard let dateValue = fact.dateValue else {
                return "n/a"
            }
            return DateFormatter.localizedString(from: dateValue, dateStyle: .medium, timeStyle: .none)
        }
    }

    private func statusTone(_ status: TaxFactStatus) -> StatusBadge.Tone {
        switch status {
        case .observed:
            return .info
        case .derived:
            return .success
        case .overridden:
            return .warning
        }
    }

    private func symbol(for status: TaxFactStatus) -> String {
        switch status {
        case .observed:
            return "eye"
        case .derived:
            return "function"
        case .overridden:
            return "slider.horizontal.3"
        }
    }

    private func provenanceTitle(for ref: ObjectRef) -> String {
        switch ref.kind {
        case .document:
            return "Source document"
        case .transaction:
            return "Linked transaction"
        case .requirement:
            return "Requirement"
        case .issue:
            return "Issue"
        default:
            return ref.kind.rawValue.capitalized
        }
    }

    private func provenanceSymbol(for ref: ObjectRef) -> String {
        switch ref.kind {
        case .document:
            return "doc.text"
        case .transaction:
            return "list.bullet.rectangle"
        case .requirement:
            return "list.bullet.clipboard"
        case .issue:
            return "exclamationmark.triangle"
        default:
            return "link"
        }
    }
}
