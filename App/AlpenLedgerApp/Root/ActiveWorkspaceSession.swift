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
    let agentToolService: WorkspaceAgentToolService
    let taxFactService: TaxFactService
    let taxComputationService: TaxComputationService
    let taxValidationService: TaxValidationService
    let vatPeriodService: VATPeriodService
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
        self.taxYearService = TaxYearService(storage: storage, auditLogger: auditLogger)
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
        let vatCodeBook = SwissVATCodeBook.current2026()
        let nowProvider = container.nowProvider
        let applicationVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let taxValidationService = TaxValidationService(
            storage: storage,
            rulePackRegistry: rulePackRegistry
        )
        self.agentToolService = WorkspaceAgentToolService(
            storage: storage,
            auditLogger: auditLogger,
            taxStatusProvider: { entityId, taxYearId in
                let summary = try taxValidationService.readinessSummary(
                    entityId: entityId,
                    taxYearId: taxYearId
                )
                return AgentTaxReadinessToolOutput(
                    state: AgentTaxReadinessState(rawValue: summary.state.rawValue) ?? .needsAttention,
                    openIssueCount: summary.openIssueCount,
                    pendingRequirementCount: summary.pendingRequirementCount,
                    currentFactCount: summary.currentFactCount,
                    missingConceptCodes: summary.missingConceptCodes
                )
            },
            exportValidationProvider: { input in
                guard input.exportFormat == SwissVATDeclarationExportService.exportFormat,
                      let vatPeriodId = input.vatPeriodId,
                      let typeOfSubmission = SwissVATDeclarationSubmissionType(
                        rawValue: input.typeOfSubmission ?? SwissVATDeclarationSubmissionType.initial.rawValue
                      ),
                      let formOfReporting = SwissVATDeclarationFormOfReporting(
                        rawValue: input.formOfReporting ?? SwissVATDeclarationFormOfReporting.agreedConsideration.rawValue
                      )
                else {
                    throw WorkspaceAgentToolError.invalidInput("exports.validate")
                }

                let metadata = SwissVATDeclarationMetadata(
                    uid: input.uid ?? "",
                    organisationName: input.organisationName ?? "",
                    generationTime: input.generationTime ?? nowProvider(),
                    typeOfSubmission: typeOfSubmission,
                    formOfReporting: formOfReporting,
                    businessReferenceId: input.businessReferenceId ?? "",
                    sendingApplication: SwissVATDeclarationSendingApplication(
                        productVersion: input.applicationProductVersion ?? applicationVersion
                    )
                )
                let report = try VATPeriodService(storage: storage, codeBook: vatCodeBook)
                    .reconcileVATPeriod(vatPeriodId)
                let validator = SwissVATDeclarationExportService(codeBook: vatCodeBook)
                let reportIssues = validator.validate(report: report, metadata: metadata)
                let issues: [SwissVATDeclarationValidationIssue]
                if reportIssues.contains(where: { $0.severity == .blocker }) {
                    issues = reportIssues
                } else {
                    do {
                        issues = try validator
                            .generateEffectiveReportingMethodExport(report: report, metadata: metadata)
                            .validationIssues
                    } catch let error as SwissVATDeclarationExportError {
                        switch error {
                        case let .validationFailed(validationIssues):
                            issues = validationIssues
                        }
                    }
                }

                return AgentExportValidationProviderResult(
                    schemaVersion: SwissVATDeclarationExportService.schemaVersion,
                    issues: issues.map {
                        AgentExportValidationIssueToolOutput(
                            severity: $0.severity,
                            code: $0.code,
                            message: $0.message,
                            sourceRef: $0.sourceRef
                        )
                    }
                )
            },
            exportPackageProvider: { input in
                guard input.exportFormat == SwissVATDeclarationExportService.exportFormat,
                      let vatPeriodId = input.vatPeriodId,
                      let typeOfSubmission = SwissVATDeclarationSubmissionType(
                        rawValue: input.typeOfSubmission ?? SwissVATDeclarationSubmissionType.initial.rawValue
                      ),
                      let formOfReporting = SwissVATDeclarationFormOfReporting(
                        rawValue: input.formOfReporting ?? SwissVATDeclarationFormOfReporting.agreedConsideration.rawValue
                      )
                else {
                    throw WorkspaceAgentToolError.invalidInput("exports.generate_package")
                }

                let metadata = SwissVATDeclarationMetadata(
                    uid: input.uid ?? "",
                    organisationName: input.organisationName ?? "",
                    generationTime: input.generationTime ?? nowProvider(),
                    typeOfSubmission: typeOfSubmission,
                    formOfReporting: formOfReporting,
                    businessReferenceId: input.businessReferenceId ?? "",
                    sendingApplication: SwissVATDeclarationSendingApplication(
                        productVersion: input.applicationProductVersion ?? applicationVersion
                    )
                )
                let report = try VATPeriodService(storage: storage, codeBook: vatCodeBook)
                    .reconcileVATPeriod(vatPeriodId)
                let export = try SwissVATDeclarationExportService(codeBook: vatCodeBook)
                    .generateEffectiveReportingMethodExport(report: report, metadata: metadata)
                let businessReference = input.businessReferenceId?.isEmpty == false
                    ? input.businessReferenceId!
                    : vatPeriodId.rawValue.uuidString.lowercased()
                return AgentExportPackageProviderResult(
                    schemaVersion: export.schemaVersion,
                    artifactFilename: "\(businessReference).xml",
                    mediaType: "application/xml",
                    artifactData: Data(export.xmlString.utf8),
                    issues: export.validationIssues.map {
                        AgentExportValidationIssueToolOutput(
                            severity: $0.severity,
                            code: $0.code,
                            message: $0.message,
                            sourceRef: $0.sourceRef
                        )
                    },
                    sourceRefs: export.sourceRefs
                )
            },
            nowProvider: container.nowProvider
        )

        let taxFactService = TaxFactService(storage: storage)
        self.taxFactService = taxFactService
        self.taxComputationService = TaxComputationService(
            storage: storage,
            rulePackRegistry: rulePackRegistry,
            factService: taxFactService,
            nowProvider: container.nowProvider
        )
        self.taxValidationService = taxValidationService
        self.vatPeriodService = VATPeriodService(
            storage: storage,
            codeBook: vatCodeBook,
            auditLogger: auditLogger
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
            if let balance = account.currentBalanceMinor(transactions: accountTransactions) {
                balances[account.id] = balance
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
            archivedDocuments = try documentQueryService.listArchivedDocuments(entityId: activeEntityId)
        } else {
            documents = try documentQueryService.listDocuments()
            archivedDocuments = try documentQueryService.listArchivedDocuments()
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
        importDiagnosticsByJobId = Dictionary(
            grouping: try importJobService.listImportDiagnostics(),
            by: \.importJobId
        )
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
            filingPackages = []
            vatPeriodReports = []
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
            filingPackages = []
            vatPeriodReports = []
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
        if recomputeFacts && selectedTaxYear.status == .open {
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
        filingPackages = try storage.filingPackageRepository
            .fetchFilingPackages(entityId: resolvedEntityId)
            .filter { $0.taxYearId == resolvedYearId }
        taxReadinessSummary = try taxValidationService.readinessSummary(
            entity: selectedEntity,
            taxYear: selectedTaxYear,
            currentFacts: taxFacts
        )
        vatPeriodReports = try vatPeriodService
            .listVATPeriods(entityId: resolvedEntityId)
            .filter { selectedTaxYear.periodStart <= $0.periodEnd && $0.periodStart <= selectedTaxYear.periodEnd }
            .map { try vatPeriodService.reconcileVATPeriod($0.id) }

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
        case let .vatPeriod(periodId):
            return vatPeriodReports.contains { $0.period.id == periodId }
        case let .vatIssue(issueId):
            return vatPeriodReports.contains { report in
                report.issues.enumerated().contains { index, issue in
                    Self.vatIssueSelectionID(periodId: report.period.id, index: index, issue: issue) == issueId
                }
            }
        case let .filingPackage(packageId):
            return filingPackages.contains { $0.id == packageId }
        }
    }

    static func vatIssueSelectionID(periodId: VATPeriodID, index: Int, issue: VATReconciliationIssue) -> String {
        [
            periodId.rawValue.uuidString,
            index.formatted(),
            issue.code,
            issue.sourceRef?.stringValue ?? "period",
        ]
        .joined(separator: "-")
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { $0.isEmpty == false }
        .joined(separator: "-")
        .lowercased()
    }
}
