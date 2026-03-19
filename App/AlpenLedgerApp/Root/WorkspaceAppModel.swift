import AppKit
import Foundation
import Observation
import ALDomain
import ALAudit
import ALDocuments
import ALFeatures
import ALImports
import ALLedger
import ALStorage
import ALWorkspace

@MainActor
@Observable
final class WorkspaceAppModel {
    private let container: DependencyContainer

    var recentWorkspaces: [RecentWorkspaceReference] = []
    var newWorkspaceName = ""
    var newSolePropName = ""
    var documentSearchQuery = ""
    var selectedSection: AppSection = .overview
    var selectedAccountId: FinancialAccountID?
    var selectedTransactionId: TransactionID?
    var selectedDocumentId: DocumentID?
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

    private(set) var entities: [LegalEntity] = []
    private(set) var financialAccounts: [FinancialAccount] = []
    private(set) var transactions: [Transaction] = []
    private(set) var documents: [Document] = []
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

    var transactionCount: Int { transactions.count }
    var documentCount: Int { documents.count }

    func reloadRecentWorkspaces() {
        recentWorkspaces = container.workspaceService.recentWorkspaces()
    }

    func createWorkspace() {
        perform {
            let openedStorage = try container.workspaceService.createWorkspace(named: newWorkspaceName)
            newWorkspaceName = ""
            configure(openedStorage)
        }
    }

    func openWorkspace(_ reference: RecentWorkspaceReference) {
        perform {
            let openedStorage = try container.workspaceService.openWorkspace(at: URL(fileURLWithPath: reference.path))
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
                configure(openedStorage)
            }
        }
    }

    func createSoleProp() {
        guard let legalEntityService else { return }
        perform {
            _ = try legalEntityService.createSoleProprietor(name: newSolePropName)
            newSolePropName = ""
            try refreshData()
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
            try refreshSelectionArtifacts()
        }
    }

    func linkCurrentDocumentToTransaction(transactionId: TransactionID) {
        guard let selectedDocumentId, let documentService else { return }
        perform {
            try documentService.linkDocument(selectedDocumentId, to: transactionId)
            isShowingTransactionLinkSheet = false
            try refreshSelectionArtifacts()
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

    private func importCSV(url: URL) {
        guard let importJobService, let selectedAccount = selectedAccountId ?? financialAccounts.first?.id else {
            return
        }
        perform {
            _ = try importJobService.importStatement(from: url, accountId: selectedAccount)
            try refreshTransactions()
        }
    }

    private func importDocument(url: URL) {
        guard let documentService else { return }
        perform {
            _ = try documentService.importDocument(from: url)
            try refreshDocuments()
        }
    }

    private func configure(_ storage: WorkspaceStorage) {
        self.storage = storage
        let auditLogger = AuditLogger(storage: storage)
        self.auditLogger = auditLogger
        provenanceTraceService = ProvenanceTraceService(storage: storage)
        legalEntityService = LegalEntityService(storage: storage, auditLogger: auditLogger)
        taxYearService = TaxYearService(storage: storage)
        ledgerAccountService = LedgerAccountService(storage: storage)
        financialAccountService = FinancialAccountService(storage: storage)
        transactionService = TransactionService(storage: storage)
        documentService = DocumentService(storage: storage, auditLogger: auditLogger)
        documentQueryService = DocumentQueryService(storage: storage)
        importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
        reloadRecentWorkspaces()
        perform {
            try refreshData()
        }
    }

    private func refreshData() throws {
        guard let legalEntityService, let financialAccountService else { return }
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
            let documentIds = try transactionService.linkedDocumentIDs(for: selectedTransactionId)
            linkedDocuments = try storage.documentRepository.fetchDocuments(ids: documentIds)
        } else {
            linkedDocuments = []
        }

        if let selectedDocumentId {
            let transactionIds = try documentService.linkedTransactionIDs(for: selectedDocumentId)
            linkedTransactions = try storage.transactionRepository.fetchTransactions(ids: transactionIds)
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

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
