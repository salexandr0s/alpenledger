import Foundation
import Observation
import ALAudit
import ALDocuments
import ALFeatures
import ALDomain
import ALEvidence
import ALImports
import ALLedger
import ALStorage
import ALTaxCH
import ALTaxCore
import ALWorkspace

@MainActor
@Observable
final class ActiveWorkspaceSession {

    // MARK: - Refresh Result Types

    struct CoreDataRefreshResult {
        let shouldClearSelectedAccountId: Bool
    }

    struct TaxStudioRefreshResult {
        var selectedTaxEntityId: LegalEntityID?
        var selectedTaxYearId: TaxYearID?
        var shouldClearTaxFactId: Bool
        var shouldClearTaxStudioSelection: Bool
    }

    // MARK: - Storage & Services

    let storage: WorkspaceStorage
    let auditLogger: AuditLogger
    let provenanceTraceService: ProvenanceTraceService
    let legalEntityService: LegalEntityService
    let taxYearService: TaxYearService
    let ledgerAccountService: LedgerAccountService
    let financialAccountService: FinancialAccountService
    let transactionService: TransactionService
    let documentService: DocumentService
    let documentQueryService: DocumentQueryService
    let importJobService: ImportJobService
    let evidenceRefreshService: EvidenceRefreshService
    let issueService: IssueService
    let reconciliationService: ReconciliationService
    let taxFactService: TaxFactService
    let taxComputationService: TaxComputationService
    let taxValidationService: TaxValidationService
    let entityWorkspaceService: EntityWorkspaceService

    // MARK: - Active Entity

    private(set) var activeEntityId: LegalEntityID?
    private(set) var entityWorkspaces: [EntityWorkspace] = []

    // MARK: - Data Cache

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

    // MARK: - Derived Properties

    var workspaceName: String { storage.manifest.workspace.name }

    // MARK: - Private

    private let nowProvider: @Sendable () -> Date

    // MARK: - Initializer

    init(storage: WorkspaceStorage, container: DependencyContainer) {
        self.storage = storage
        self.nowProvider = container.nowProvider

        let auditLogger = AuditLogger(storage: storage)
        self.auditLogger = auditLogger
        self.provenanceTraceService = ProvenanceTraceService(storage: storage)
        self.legalEntityService = LegalEntityService(
            storage: storage,
            auditLogger: auditLogger,
            nowProvider: container.nowProvider
        )
        self.taxYearService = TaxYearService(storage: storage)
        self.ledgerAccountService = LedgerAccountService(storage: storage)
        self.financialAccountService = FinancialAccountService(storage: storage)
        self.transactionService = TransactionService(storage: storage)
        self.documentService = DocumentService(storage: storage, auditLogger: auditLogger)
        self.documentQueryService = DocumentQueryService(storage: storage)
        self.importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
        self.evidenceRefreshService = EvidenceRefreshService(
            storage: storage,
            auditLogger: auditLogger,
            nowProvider: container.nowProvider
        )
        self.issueService = IssueService(storage: storage, auditLogger: auditLogger)
        self.reconciliationService = ReconciliationService(storage: storage, auditLogger: auditLogger)

        let rulePackRegistry = RulePackRegistry()
        rulePackRegistry.registerPersonalTaxRulePack(ZurichPersonalTaxAdapter2026())

        let taxFactService = TaxFactService(storage: storage)
        self.taxFactService = taxFactService
        self.taxComputationService = TaxComputationService(
            storage: storage,
            rulePackRegistry: rulePackRegistry,
            factService: taxFactService,
            nowProvider: container.nowProvider
        )
        self.taxValidationService = TaxValidationService(
            storage: storage,
            rulePackRegistry: rulePackRegistry
        )
        self.entityWorkspaceService = EntityWorkspaceService(
            storage: storage,
            auditLogger: auditLogger,
            nowProvider: container.nowProvider
        )
    }

    // MARK: - Entity Switching

    func loadEntityWorkspaces() throws {
        entityWorkspaces = try entityWorkspaceService.listEntityWorkspaces()
        if activeEntityId == nil {
            let active = try entityWorkspaceService.activeEntityWorkspace()
            activeEntityId = active?.entityId
        }
    }

    func switchEntity(to entityWorkspaceId: EntityWorkspaceID) throws {
        try entityWorkspaceService.setActiveEntityWorkspace(entityWorkspaceId)
        if let ew = try entityWorkspaceService.activeEntityWorkspace() {
            activeEntityId = ew.entityId
        }
        entityWorkspaces = try entityWorkspaceService.listEntityWorkspaces()
    }

    // MARK: - Refresh: Core Data

    /// Refreshes entities, financial accounts, balances, and all downstream data.
    ///
    /// The caller passes the current `selectedAccountId` so this method can determine
    /// whether that selection is still valid. The returned result tells the caller
    /// whether to clear its own `selectedAccountId`.
    func refreshCoreData(
        recomputeEvidence: Bool,
        selectedAccountId: FinancialAccountID?,
        selectedTaxEntityId: LegalEntityID?,
        selectedTaxYearId: TaxYearID?,
        selectedTransactionId: TransactionID?,
        selectedDocumentId: DocumentID?,
        selectedTaxStudioSelection: TaxStudioSelection?,
        selectedInboxSelection: InboxSelection?
    ) throws -> CoreDataRefreshResult {
        if recomputeEvidence {
            try evidenceRefreshService.refresh()
        }

        entities = try legalEntityService.listEntities()
        entityDeletionChecks = try entities.reduce(into: [:]) { checks, entity in
            checks[entity.id] = try legalEntityService.deletionCheck(for: entity.id)
        }
        let scopedEntities = activeEntityId.map { eid in entities.filter { $0.id == eid } } ?? entities
        let sortedAccounts = try scopedEntities
            .flatMap { try financialAccountService.listAccounts(entityId: $0.id) }
            .sorted { $0.displayName < $1.displayName }
        financialAccounts = sortedAccounts
        accountBalanceById = try sortedAccounts.reduce(into: [:]) { balances, account in
            let accountTransactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)
            if let latestBalance = accountTransactions.first(where: { $0.balanceAfterMinor != nil })?.balanceAfterMinor {
                balances[account.id] = latestBalance
            }
        }

        let shouldClearAccount: Bool
        if let selectedAccountId, sortedAccounts.contains(where: { $0.id == selectedAccountId }) == false {
            shouldClearAccount = true
        } else {
            shouldClearAccount = false
        }

        let effectiveAccountId = shouldClearAccount ? nil : selectedAccountId
        try refreshTransactions(
            accountId: effectiveAccountId,
            selectedTransactionId: selectedTransactionId,
            selectedDocumentId: selectedDocumentId,
            selectedTaxStudioSelection: selectedTaxStudioSelection
        )
        try refreshDocuments(
            selectedDocumentId: selectedDocumentId,
            selectedTransactionId: shouldClearAccount ? nil : selectedTransactionId,
            selectedTaxStudioSelection: selectedTaxStudioSelection
        )
        try refreshInbox(selectedInboxSelection: selectedInboxSelection)
        _ = try refreshTaxStudio(
            recomputeFacts: recomputeEvidence,
            selectedTaxEntityId: selectedTaxEntityId,
            selectedTaxYearId: selectedTaxYearId
        )

        return CoreDataRefreshResult(shouldClearSelectedAccountId: shouldClearAccount)
    }

    // MARK: - Refresh: Transactions

    /// Refreshes the transaction list for the given account.
    ///
    /// Returns `true` if the previously selected transaction is no longer visible
    /// and the caller should clear its `selectedTransactionId`.
    @discardableResult
    func refreshTransactions(
        accountId: FinancialAccountID?,
        selectedTransactionId: TransactionID?,
        selectedDocumentId: DocumentID?,
        selectedTaxStudioSelection: TaxStudioSelection?
    ) throws -> Bool {
        guard let accountId else {
            transactions = []
            linkedDocuments = []
            return true
        }

        transactions = try transactionService.listTransactions(accountId: accountId)
        try refreshSelectionArtifacts(
            selectedTransactionId: selectedTransactionId,
            selectedDocumentId: selectedDocumentId,
            selectedTaxStudioSelection: selectedTaxStudioSelection
        )
        return false
    }

    // MARK: - Refresh: Documents

    /// Refreshes the full document list.
    func refreshDocuments(
        selectedDocumentId: DocumentID?,
        selectedTransactionId: TransactionID?,
        selectedTaxStudioSelection: TaxStudioSelection?
    ) throws {
        if let activeEntityId {
            documents = try documentQueryService.listDocuments(entityId: activeEntityId)
        } else {
            documents = try documentQueryService.listDocuments()
        }
        try refreshSelectionArtifacts(
            selectedTransactionId: selectedTransactionId,
            selectedDocumentId: selectedDocumentId,
            selectedTaxStudioSelection: selectedTaxStudioSelection
        )
    }

    // MARK: - Refresh: Inbox

    /// Refreshes inbox data (import jobs, issues, agent proposals).
    ///
    /// Returns `true` if the currently selected inbox item is no longer present
    /// and the caller should clear `selectedInboxSelection`.
    @discardableResult
    func refreshInbox(selectedInboxSelection: InboxSelection?) throws -> Bool {
        importJobs = try importJobService.listImportJobs()
        let allIssues = try evidenceRefreshService.listIssues(status: .open)
        if let activeEntityId {
            issues = allIssues.filter { $0.entityId == activeEntityId }
        } else {
            issues = allIssues
        }
        agentProposals = try evidenceRefreshService.listProposals(status: .pending)

        if let selection = selectedInboxSelection, containsInboxSelection(selection) == false {
            return true
        }
        return false
    }

    // MARK: - Refresh: Tax Studio

    /// Refreshes tax studio state for the given entity and year selections.
    ///
    /// The caller passes its current tax entity and year selections. This method
    /// auto-selects defaults when the current selection is invalid, and returns
    /// the resolved selections so the caller can update its own state.
    func refreshTaxStudio(
        recomputeFacts: Bool,
        selectedTaxEntityId: LegalEntityID?,
        selectedTaxYearId: TaxYearID?
    ) throws -> TaxStudioRefreshResult {
        var result = TaxStudioRefreshResult(
            selectedTaxEntityId: selectedTaxEntityId,
            selectedTaxYearId: selectedTaxYearId,
            shouldClearTaxFactId: false,
            shouldClearTaxStudioSelection: false
        )

        // Validate entity selection
        if let entityId = result.selectedTaxEntityId,
           entities.contains(where: { $0.id == entityId }) == false {
            result.selectedTaxEntityId = nil
        }
        if result.selectedTaxEntityId == nil {
            result.selectedTaxEntityId = entities.first(where: { $0.kind == .naturalPerson })?.id ?? entities.first?.id
        }

        guard let resolvedEntityId = result.selectedTaxEntityId,
              let selectedEntity = entities.first(where: { $0.id == resolvedEntityId })
        else {
            taxYears = []
            taxFacts = []
            taxRequirements = []
            taxIssues = []
            return result
        }

        // Validate tax year selection
        taxYears = try taxYearService.listTaxYears(entityId: resolvedEntityId)
        if let yearId = result.selectedTaxYearId,
           taxYears.contains(where: { $0.id == yearId }) == false {
            result.selectedTaxYearId = nil
        }
        if result.selectedTaxYearId == nil {
            result.selectedTaxYearId = taxYears.first?.id
        }

        guard let resolvedYearId = result.selectedTaxYearId,
              let selectedTaxYear = taxYears.first(where: { $0.id == resolvedYearId })
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
            return result
        }

        // Recompute facts if needed
        if recomputeFacts {
            _ = try taxComputationService.refreshFacts(entityId: resolvedEntityId, taxYearId: resolvedYearId)
        }

        // Fetch tax data
        taxFacts = try taxFactService.listTaxFacts(entityId: resolvedEntityId, taxYearId: resolvedYearId)
        taxRequirements = try storage.requirementRepository
            .fetchRequirements(entityId: resolvedEntityId, taxYearId: resolvedYearId)
            .filter { $0.status == .pending }
        taxIssues = try storage.issueRepository.fetchIssues(
            workspaceId: storage.manifest.workspace.id,
            entityId: resolvedEntityId,
            taxYearId: resolvedYearId,
            status: .open
        )
        taxReadinessSummary = try taxValidationService.readinessSummary(
            entity: selectedEntity,
            taxYear: selectedTaxYear,
            currentFacts: taxFacts
        )

        return result
    }

    // MARK: - Refresh: Selection Artifacts

    /// Refreshes linked documents/transactions and the document preview URL
    /// based on current selection state.
    func refreshSelectionArtifacts(
        selectedTransactionId: TransactionID?,
        selectedDocumentId: DocumentID?,
        selectedTaxStudioSelection: TaxStudioSelection?
    ) throws {
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
    }

    // MARK: - Selection Containment Checks

    func containsInboxSelection(_ selection: InboxSelection) -> Bool {
        switch selection {
        case let .importJob(importJobId):
            return importJobs.contains { $0.id == importJobId }
        case let .proposal(proposalId):
            return agentProposals.contains { $0.id == proposalId }
        case let .issue(issueId):
            return issues.contains { $0.id == issueId }
        }
    }

    func containsTaxStudioSelection(_ selection: TaxStudioSelection) -> Bool {
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
}
