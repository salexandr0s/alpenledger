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

    let container: DependencyContainer
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
    var isShowingErrorAlert = false

    private(set) var session: ActiveWorkspaceSession?

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
    private(set) var entityWorkspaces: [EntityWorkspace] = []
    var activeEntityId: LegalEntityID? { session?.activeEntityId }

    init(container: DependencyContainer) {
        self.container = container
        self.uiPreferencesStore = container.uiPreferencesStore
        reloadRecentWorkspaces()
    }

    // MARK: - Workspace Lifecycle

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
                errorMessage = blockedEntityDeletionMessage(for: deletionCheck)
                isShowingErrorAlert = true
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
        importSampleCSV()
        importSampleDocument()
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
        case .overview, .inbox, .taxStudio, .settings:
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
        guard selectedDocumentId != nil else { return }
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
        guard let selectedDocumentId, let session else { return }
        perform {
            try session.documentService.linkDocument(selectedDocumentId, to: transactionId)
            isShowingTransactionLinkSheet = false
            try refreshData(recomputeEvidence: true)
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

    // MARK: - Session Configuration

    private func configure(_ storage: WorkspaceStorage) {
        let newSession = ActiveWorkspaceSession(storage: storage, container: container)
        self.session = newSession
        selectedSection = .overview
        documentSearchQuery = ""
        ledgerTransactionScope = .all
        documentFilterScope = .all
        restoreInspectorVisibility(for: storage.manifest.workspace.id)
        reloadRecentWorkspaces()
        perform {
            try refreshData(recomputeEvidence: true)
        }
    }

    // MARK: - Refresh Methods (Delegating to Session)

    private func refreshData(recomputeEvidence: Bool = false) throws {
        guard let session else { return }
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
        importJobs = session.importJobs
        issues = session.issues
        agentProposals = session.agentProposals
        taxFacts = session.taxFacts
        taxRequirements = session.taxRequirements
        taxIssues = session.taxIssues
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
        guard let session, let selectedAccount = selectedAccountId ?? financialAccounts.first?.id else {
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
            errorMessage = error.localizedDescription
            isShowingErrorAlert = true
        }
    }

    // MARK: - Debug / QA

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
    func importQAValidationFixtures() {
        guard session != nil else { return }

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
