import Foundation
import Testing
@testable import ALAudit
@testable import ALDocuments
@testable import ALEvidence
@testable import ALImports
@testable import ALLedger
@testable import ALDomain
@testable import ALStorage
@testable import ALWorkspace

@Test
func documentImportCreatesDocumentIntakeImportJob() throws {
    let harness = try EvidenceHarness()

    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    let importJobs = try harness.storage.importJobRepository.fetchImportJobs(workspaceId: harness.storage.manifest.workspace.id)

    #expect(importJobs.count == 1)
    #expect(importJobs.first?.kind == .documentIntake)
    #expect(document.importJobId == importJobs.first?.id)
}

@Test
func evidenceRefreshIsIdempotent() throws {
    let harness = try EvidenceHarness()

    try harness.importFixtureStatement()
    _ = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))

    try harness.evidenceRefreshService.refresh()
    let firstRequirements = try harness.storage.requirementRepository.fetchRequirements(entityId: harness.entity.id)
    let firstIssues = try harness.storage.issueRepository.fetchIssues(workspaceId: harness.storage.manifest.workspace.id, status: nil)
    let firstProposals = try harness.storage.agentProposalRepository.fetchAgentProposals(workspaceId: harness.storage.manifest.workspace.id, status: nil)

    try harness.evidenceRefreshService.refresh()
    let secondRequirements = try harness.storage.requirementRepository.fetchRequirements(entityId: harness.entity.id)
    let secondIssues = try harness.storage.issueRepository.fetchIssues(workspaceId: harness.storage.manifest.workspace.id, status: nil)
    let secondProposals = try harness.storage.agentProposalRepository.fetchAgentProposals(workspaceId: harness.storage.manifest.workspace.id, status: nil)

    #expect(firstRequirements.count == 4)
    #expect(firstRequirements.count == secondRequirements.count)
    #expect(firstIssues.count == secondIssues.count)
    #expect(firstProposals.count == secondProposals.count)
}

@Test
func statementCoverageRefreshCreatesSingleMissingFebruaryIssue() throws {
    let harness = try EvidenceHarness()

    try harness.importFixtureStatement()
    try harness.evidenceRefreshService.refresh()

    let issues = try harness.evidenceRefreshService.listIssues(status: .open)
        .filter { $0.issueCode == .missingStatementCoverage }

    #expect(issues.count == 1)
    #expect(issues.first?.summary.contains("February 2026") == true)
}

@Test
func missingExpenseEvidenceDropsAfterConfirmedLink() throws {
    let harness = try EvidenceHarness()

    try harness.importFixtureStatement()
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    try harness.evidenceRefreshService.refresh()

    let beforeIssues = try harness.evidenceRefreshService.listIssues(status: .open)
        .filter { $0.issueCode == .missingExpenseEvidence }
    #expect(beforeIssues.count == 2)

    let coffeeTransaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "Coffee Bar Zurich" })
    )

    try harness.documentService.linkDocument(document.id, to: coffeeTransaction.id)
    try harness.evidenceRefreshService.refresh()

    let afterIssues = try harness.evidenceRefreshService.listIssues(status: .open)
        .filter { $0.issueCode == .missingExpenseEvidence }
    #expect(afterIssues.count == 1)
}

@Test
func documentLinkProposalResolvesAfterConfirmedLink() throws {
    let harness = try EvidenceHarness()

    try harness.importFixtureStatement()
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    try harness.evidenceRefreshService.refresh()

    let pendingBefore = try harness.evidenceRefreshService.listProposals(status: .pending)
    #expect(pendingBefore.count == 1)
    #expect(pendingBefore.first?.targetRef == ObjectRef(kind: .document, id: document.id.rawValue))

    let coffeeTransaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "Coffee Bar Zurich" })
    )
    try harness.documentService.linkDocument(document.id, to: coffeeTransaction.id)
    try harness.evidenceRefreshService.refresh()

    let pendingAfter = try harness.evidenceRefreshService.listProposals(status: .pending)
    let resolved = try harness.evidenceRefreshService.listProposals(status: .resolved)
    #expect(pendingAfter.isEmpty)
    #expect(resolved.count == 1)
}

private struct EvidenceHarness {
    let fixedNow = try! #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let storage: WorkspaceStorage
    let entity: LegalEntity
    let account: FinancialAccount
    let documentService: DocumentService
    let importJobService: ImportJobService
    let transactionService: TransactionService
    let evidenceRefreshService: EvidenceRefreshService

    init() throws {
        let fixedNow = self.fixedNow
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storageManager = WorkspaceStorageManager(
            secretStore: InMemorySecretStore(),
            workspacesRootURL: tempRoot
        )
        let recentStore = RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let workspaceService = WorkspaceService(
            storageManager: storageManager,
            recentStore: recentStore,
            nowProvider: { fixedNow }
        )
        storage = try workspaceService.createWorkspace(named: "Evidence Workspace")

        let auditLogger = AuditLogger(storage: storage)
        documentService = DocumentService(storage: storage, auditLogger: auditLogger)
        importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
        transactionService = TransactionService(storage: storage)
        evidenceRefreshService = EvidenceRefreshService(
            storage: storage,
            auditLogger: auditLogger,
            nowProvider: { fixedNow }
        )

        entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
        account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    }

    func importFixtureStatement() throws {
        _ = try importJobService.importStatement(
            from: try fixtureURL("Fixtures/Bank/sample-bank-statement.csv"),
            accountId: account.id
        )
    }
}

private func fixtureURL(_ relativePath: String) throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return packageRoot.appendingPathComponent(relativePath)
}
