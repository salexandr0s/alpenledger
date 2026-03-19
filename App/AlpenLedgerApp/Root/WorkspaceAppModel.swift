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
    enum ToolbarAction: Hashable {
        case openInbox
        case importCSV
        case importDocument

        var title: String {
            switch self {
            case .openInbox:
                return "Open Inbox"
            case .importCSV:
                return "Import CSV"
            case .importDocument:
                return "Import Document"
            }
        }

        var systemImage: String {
            switch self {
            case .openInbox:
                return "tray.full"
            case .importCSV:
                return "tablecells"
            case .importDocument:
                return "plus"
            }
        }
    }

    private let container: DependencyContainer

    var recentWorkspaces: [RecentWorkspaceReference] = []
    var newWorkspaceName = ""
    var newSolePropName = ""
    var documentSearchQuery = ""
    var selectedSection: AppSection = .overview
    var selectedAccountId: FinancialAccountID?
    var selectedTransactionId: TransactionID?
    var selectedDocumentId: DocumentID?
    var selectedInboxSelection: InboxSelection?
    var selectedTaxEntityId: LegalEntityID?
    var selectedTaxYearId: TaxYearID?
    var selectedTaxFactId: TaxFactID?
    var isShowingNewWorkspaceSheet = false
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

    init(container: DependencyContainer) {
        self.container = container
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

    var contextualToolbarAction: ToolbarAction? {
        guard hasWorkspace else { return nil }

        switch selectedSection {
        case .overview:
            return .openInbox
        case .ledger:
            return .importCSV
        case .documents:
            return .importDocument
        case .inbox, .taxStudio, .settings:
            return nil
        }
    }

    var overviewSnapshot: OverviewSnapshot {
        OverviewSnapshot(
            workspaceName: workspaceName,
            workspaceSubtitle: workspaceSummarySubtitle,
            healthItems: overviewHealthItems,
            nextSteps: overviewNextSteps,
            recentImports: overviewRecentImports,
            reviewQueue: overviewReviewQueue,
            taxReadiness: overviewTaxReadiness,
            workspaceFacts: overviewWorkspaceFacts
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
            try refreshData(recomputeEvidence: true)
        }
    }

    func openInbox() {
        selectedSection = .inbox
    }

    func navigate(to section: AppSection) {
        selectedSection = section
    }

    func performOverviewAction(_ action: OverviewAction) {
        switch action {
        case .openInbox:
            openInbox()
        case .openLedger:
            selectedSection = .ledger
        case .openDocuments:
            selectedSection = .documents
        case .openTaxStudio:
            selectedSection = .taxStudio
        case .importSampleCSV:
            importSampleCSV()
        case .importSampleDocument:
            importSampleDocument()
        }
    }

    func performToolbarAction(_ action: ToolbarAction) {
        switch action {
        case .openInbox:
            openInbox()
        case .importCSV:
            importCSVFromPanel()
        case .importDocument:
            importDocumentFromPanel()
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
        perform {
            try refreshTaxStudio(recomputeFacts: true)
        }
    }

    func selectTaxYear(_ taxYearId: TaxYearID?) {
        selectedTaxYearId = taxYearId
        selectedTaxFactId = nil
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
            try refreshDocuments()
        }
    }

    func sidebarBadgeText(for section: AppSection) -> String? {
        switch section {
        case .inbox:
            let total = openIssueCount + pendingProposalCount
            return total > 0 ? total.formatted() : nil
        case .ledger:
            return transactions.isEmpty ? nil : transactions.count.formatted()
        case .documents:
            return documents.isEmpty ? nil : documents.count.formatted()
        case .taxStudio:
            let total = taxReadinessSummary.openIssueCount + taxReadinessSummary.pendingRequirementCount
            return total > 0 ? total.formatted() : nil
        case .overview, .settings:
            return nil
        }
    }

    func canPerform(_ action: ToolbarAction) -> Bool {
        switch action {
        case .openInbox:
            return hasWorkspace
        case .importCSV:
            return canImportCSV
        case .importDocument:
            return canImportDocument
        }
    }

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
        perform {
            try refreshData(recomputeEvidence: true)
        }
    }

    private func refreshData(recomputeEvidence: Bool = false) throws {
        guard let legalEntityService, let financialAccountService else { return }
        if recomputeEvidence {
            try evidenceRefreshService?.refresh()
        }

        entities = try legalEntityService.listEntities()
        let sortedAccounts = try entities
            .flatMap { try financialAccountService.listAccounts(entityId: $0.id) }
            .sorted { $0.displayName < $1.displayName }
        financialAccounts = sortedAccounts

        if selectedAccountId == nil {
            selectedAccountId = sortedAccounts.first?.id
        } else if sortedAccounts.contains(where: { $0.id == selectedAccountId }) == false {
            selectedAccountId = sortedAccounts.first?.id
        }

        try refreshTransactions()
        try refreshDocuments()
        try refreshInbox()
        try refreshTaxStudio(recomputeFacts: recomputeEvidence)
    }

    private func refreshTransactions() throws {
        guard let transactionService, let selectedAccount = selectedAccountId else {
            transactions = []
            linkedDocuments = []
            return
        }

        transactions = try transactionService.listTransactions(accountId: selectedAccount)
        if transactions.contains(where: { $0.id == selectedTransactionId }) == false {
            selectedTransactionId = transactions.first?.id
        }
        try refreshSelectionArtifacts()
    }

    private func refreshDocuments() throws {
        guard let documentQueryService else {
            documents = []
            linkedTransactions = []
            return
        }

        documents = try documentQueryService.listDocuments(query: documentSearchQuery)
        if documents.contains(where: { $0.id == selectedDocumentId }) == false {
            selectedDocumentId = documents.first?.id
        }
        try refreshSelectionArtifacts()
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
    }

    private func refreshInbox() throws {
        importJobs = try importJobService?.listImportJobs() ?? []
        issues = try evidenceRefreshService?.listIssues() ?? []
        agentProposals = try evidenceRefreshService?.listProposals() ?? []

        if let selection = selectedInboxSelection, containsInboxSelection(selection) == false {
            selectedInboxSelection = defaultInboxSelection()
        } else if selectedInboxSelection == nil {
            selectedInboxSelection = defaultInboxSelection()
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
            self.selectedTaxFactId = taxFacts.first?.id
        } else if self.selectedTaxFactId == nil {
            self.selectedTaxFactId = taxFacts.first?.id
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

    private func defaultInboxSelection() -> InboxSelection? {
        if let importJob = importJobs.first {
            return .importJob(importJob.id)
        }
        if let proposal = agentProposals.first {
            return .proposal(proposal.id)
        }
        if let issue = issues.first {
            return .issue(issue.id)
        }
        return nil
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

    private var overviewHealthItems: [OverviewSnapshot.HealthItem] {
        [
            OverviewSnapshot.HealthItem(
                id: "issues",
                title: "Open Issues",
                value: openIssueCount.formatted(),
                subtitle: openIssueCount == 0 ? "Clear" : "Need review",
                tone: openIssueCount == 0 ? .success : .critical,
                systemImage: "exclamationmark.bubble"
            ),
            OverviewSnapshot.HealthItem(
                id: "proposals",
                title: "Pending Proposals",
                value: pendingProposalCount.formatted(),
                subtitle: pendingProposalCount == 0 ? "Clear" : "Awaiting review",
                tone: pendingProposalCount == 0 ? .success : .warning,
                systemImage: "wand.and.stars"
            ),
            OverviewSnapshot.HealthItem(
                id: "imports",
                title: "Import Jobs",
                value: importJobs.count.formatted(),
                subtitle: latestImportSummary,
                tone: importJobs.isEmpty ? .neutral : .info,
                systemImage: "tray.full"
            ),
            OverviewSnapshot.HealthItem(
                id: "tax",
                title: "Tax Readiness",
                value: overviewTaxReadiness.summary,
                subtitle: overviewTaxReadiness.detail,
                tone: overviewTaxReadiness.tone,
                systemImage: "checkmark.shield"
            ),
        ]
    }

    private var overviewNextSteps: [OverviewSnapshot.NextStep] {
        var steps: [OverviewSnapshot.NextStep] = []

        if openIssueCount > 0 {
            steps.append(
                OverviewSnapshot.NextStep(
                    id: "issues",
                    title: "Resolve open issues",
                    subtitle: "\(openIssueCount) issue\(openIssueCount == 1 ? "" : "s") currently need attention.",
                    systemImage: "tray.full",
                    action: .openInbox
                )
            )
        }

        if pendingProposalCount > 0 {
            steps.append(
                OverviewSnapshot.NextStep(
                    id: "proposals",
                    title: "Review pending proposals",
                    subtitle: "\(pendingProposalCount) suggestion\(pendingProposalCount == 1 ? "" : "s") still need review.",
                    systemImage: "wand.and.stars",
                    action: .openInbox
                )
            )
        }

        if taxReadinessSummary.state != .readyForReview {
            steps.append(
                OverviewSnapshot.NextStep(
                    id: "tax",
                    title: "Check tax readiness",
                    subtitle: "\(taxReadinessSummary.pendingRequirementCount) pending requirements and \(taxReadinessSummary.missingConceptCodes.count) missing facts remain.",
                    systemImage: "checklist.checked",
                    action: .openTaxStudio
                )
            )
        }

        if documents.isEmpty == false {
            steps.append(
                OverviewSnapshot.NextStep(
                    id: "documents",
                    title: "Review imported documents",
                    subtitle: "Inspect the latest evidence in the document vault.",
                    systemImage: "doc.text.image",
                    action: .openDocuments
                )
            )
        } else if transactions.isEmpty == false {
            steps.append(
                OverviewSnapshot.NextStep(
                    id: "ledger",
                    title: "Review imported transactions",
                    subtitle: "Classify and link transactions in the ledger.",
                    systemImage: "list.bullet.rectangle.portrait",
                    action: .openLedger
                )
            )
        }

        if steps.isEmpty {
            steps.append(
                OverviewSnapshot.NextStep(
                    id: "ready",
                    title: "Workspace looks healthy",
                    subtitle: "Use the sidebar to inspect details or import more data.",
                    systemImage: "checkmark.circle",
                    action: .openDocuments
                )
            )
        }

        return Array(steps.prefix(4))
    }

    private var overviewRecentImports: [OverviewSnapshot.RecentImportItem] {
        importJobs
            .sorted(by: importSortOrder)
            .prefix(4)
            .map { job in
                OverviewSnapshot.RecentImportItem(
                    id: job.id.rawValue.uuidString,
                    title: job.source,
                    subtitle: "\(importKindLabel(job.kind)) • \(importTimestampLabel(job))",
                    detail: importStatusLabel(job.status),
                    tone: tone(for: job.status)
                )
            }
    }

    private var overviewReviewQueue: [OverviewSnapshot.ReviewQueueItem] {
        let issueItems = issues
            .filter { $0.status == .open }
            .sorted { lhs, rhs in
                issuePriority(lhs.severity) > issuePriority(rhs.severity)
            }
            .prefix(3)
            .map { issue in
                OverviewSnapshot.ReviewQueueItem(
                    id: issue.id.rawValue.uuidString,
                    title: issue.summary,
                    subtitle: issue.severity == .blocking ? "Blocking issue" : "Open issue",
                    tone: issue.severity == .blocking ? .critical : .warning
                )
            }

        let proposalItems = agentProposals
            .filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map { proposal in
                OverviewSnapshot.ReviewQueueItem(
                    id: proposal.id.rawValue.uuidString,
                    title: proposal.summary,
                    subtitle: "Proposal • \(Int(proposal.confidence * 100))% confidence",
                    tone: .info
                )
            }

        return Array((issueItems + proposalItems).prefix(5))
    }

    private var overviewTaxReadiness: OverviewSnapshot.TaxReadinessCard {
        OverviewSnapshot.TaxReadinessCard(
            title: readinessTitle(taxReadinessSummary.state),
            summary: readinessTitle(taxReadinessSummary.state),
            detail: "\(taxReadinessSummary.openIssueCount) open issues • \(taxReadinessSummary.pendingRequirementCount) pending requirements",
            tone: readinessTone(taxReadinessSummary.state),
            missingFacts: Array(taxReadinessSummary.missingConceptCodes.prefix(4))
        )
    }

    private var overviewWorkspaceFacts: [OverviewSnapshot.WorkspaceFact] {
        [
            OverviewSnapshot.WorkspaceFact(
                id: "entities",
                title: "Entities",
                value: entities.count.formatted(),
                subtitle: entities.first?.displayName,
                systemImage: "person.2"
            ),
            OverviewSnapshot.WorkspaceFact(
                id: "accounts",
                title: "Accounts",
                value: financialAccounts.count.formatted(),
                subtitle: selectedAccountName,
                systemImage: "creditcard"
            ),
            OverviewSnapshot.WorkspaceFact(
                id: "documents",
                title: "Documents",
                value: documents.count.formatted(),
                subtitle: documents.first?.originalFilename,
                systemImage: "doc.on.doc"
            ),
            OverviewSnapshot.WorkspaceFact(
                id: "facts",
                title: "Tax Facts",
                value: taxFacts.count.formatted(),
                subtitle: readinessTitle(taxReadinessSummary.state),
                systemImage: "text.document"
            ),
        ]
    }

    private var latestImportSummary: String? {
        guard let latest = importJobs.sorted(by: importSortOrder).first else {
            return "No imports yet"
        }

        return importTimestampLabel(latest)
    }

    private var selectedAccountName: String? {
        financialAccounts.first(where: { $0.id == selectedAccountId })?.displayName ?? financialAccounts.first?.displayName
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
}
