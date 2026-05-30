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
func issueServiceResolveAndDismissTransitionsPersist() throws {
    let harness = try IssueProposalHarness()
    let entity = try #require(
        try harness.storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: harness.storage.manifest.workspace.id)
            .first
    )
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)

    let issue = try harness.issueService.syncIssue(
        fingerprint: "issue-service-transition",
        entityId: entity.id,
        taxYearId: taxYear.id,
        code: .missingExpenseEvidence,
        severity: .blocking,
        status: .open,
        summary: "Receipt missing for client lunch",
        objectRef: ObjectRef(kind: .transaction, id: UUID()),
        now: harness.fixedNow
    )
    let resolved = try harness.issueService.resolveIssue(issue.id, now: harness.fixedNow.addingTimeInterval(60))
    #expect(resolved.status == .resolved)

    let secondIssue = try harness.issueService.syncIssue(
        fingerprint: "issue-service-dismiss",
        entityId: entity.id,
        taxYearId: taxYear.id,
        code: .missingStatementCoverage,
        severity: .warning,
        status: .open,
        summary: "Statement missing for February 2026",
        objectRef: ObjectRef(kind: .financialAccount, id: UUID()),
        now: harness.fixedNow
    )
    let dismissed = try harness.issueService.dismissIssue(secondIssue.id, now: harness.fixedNow.addingTimeInterval(120))
    #expect(dismissed.status == .dismissed)

    let resynced = try harness.issueService.syncIssue(
        fingerprint: "issue-service-dismiss",
        entityId: entity.id,
        taxYearId: taxYear.id,
        code: .missingStatementCoverage,
        severity: .warning,
        status: .open,
        summary: "Statement missing for February 2026",
        objectRef: ObjectRef(kind: .financialAccount, id: UUID()),
        now: harness.fixedNow.addingTimeInterval(180)
    )
    #expect(resynced.status == .dismissed)

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: nil
    )
    #expect(auditEvents.contains(where: { $0.eventType == .issueResolved }))
    #expect(auditEvents.contains(where: { $0.eventType == .issueDismissed }))
}

@Test
func reconciliationServiceRejectPreservesRejectedProposalOnResync() throws {
    let harness = try IssueProposalHarness()
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))

    let proposal = try harness.reconciliationService.syncDocumentLinkProposal(
        for: document,
        hasConfirmedLink: false,
        now: harness.fixedNow
    )
    #expect(proposal.status == .pending)

    let rejected = try harness.reconciliationService.rejectProposal(
        proposal.id,
        actorId: "reviewer",
        reason: "Receipt does not match the suggested review path.",
        now: harness.fixedNow.addingTimeInterval(60)
    )
    #expect(rejected.status == .rejected)
    #expect(rejected.decidedAt == harness.fixedNow.addingTimeInterval(60))
    #expect(rejected.decidedBy == "reviewer")
    #expect(rejected.decisionReason == "Receipt does not match the suggested review path.")

    let resynced = try harness.reconciliationService.syncDocumentLinkProposal(
        for: document,
        hasConfirmedLink: false,
        now: harness.fixedNow.addingTimeInterval(120)
    )
    #expect(resynced.status == .rejected)
    #expect(resynced.decidedAt == rejected.decidedAt)
    #expect(resynced.decidedBy == "reviewer")
    #expect(resynced.decisionReason == "Receipt does not match the suggested review path.")

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: nil
    )
    #expect(auditEvents.contains(where: { $0.eventType == .proposalRejected }))
}

@Test
func reconciliationServiceApproveDocumentMatchProposalConfirmsEvidenceAndResolves() throws {
    let harness = try IssueProposalHarness()
    try harness.importFixtureStatement()
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "Coffee Bar Zurich" })
    )
    let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)
    let transactionRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
    let proposal = AgentProposal(
        fingerprint: "document-match-approval",
        workspaceId: harness.storage.manifest.workspace.id,
        agentKind: .systemHeuristics,
        proposalType: .documentLinkReview,
        targetRef: documentRef,
        relatedRef: transactionRef,
        summary: "Review receipt match",
        rationale: "The receipt amount and date match the coffee transaction.",
        confidence: 0.91,
        status: .pending,
        createdAt: harness.fixedNow
    )
    try harness.storage.agentProposalRepository.saveAgentProposal(proposal)

    let approved = try harness.reconciliationService.approveDocumentMatchProposal(
        proposal.id,
        actorId: "reviewer",
        reason: "Reviewer confirmed receipt and transaction match.",
        now: harness.fixedNow.addingTimeInterval(60)
    )

    #expect(approved.status == .resolved)
    #expect(approved.decidedAt == harness.fixedNow.addingTimeInterval(60))
    #expect(approved.decidedBy == "reviewer")
    #expect(approved.decisionReason == "Reviewer confirmed receipt and transaction match.")

    let links = try harness.storage.evidenceLinkRepository.fetchEvidenceLinks(for: documentRef)
    let link = try #require(links.first)
    #expect(link.sourceRef == documentRef)
    #expect(link.targetRef == transactionRef)
    #expect(link.status == .confirmed)
    #expect(link.createdByKind == .user)
    #expect(link.approvalRequired == false)
    #expect(link.reason == "Reviewer confirmed receipt and transaction match.")
    #expect(try harness.storage.documentRepository.fetchDocument(id: document.id)?.entityId == harness.entity.id)

    _ = try harness.reconciliationService.approveDocumentMatchProposal(
        proposal.id,
        actorId: "reviewer",
        reason: "Reviewer confirmed receipt and transaction match.",
        now: harness.fixedNow.addingTimeInterval(120)
    )
    let linksAfterSecondApproval = try harness.storage.evidenceLinkRepository.fetchEvidenceLinks(for: documentRef)
    #expect(linksAfterSecondApproval.count == 1)

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: nil
    )
    #expect(auditEvents.contains(where: { $0.eventType == .proposalResolved }))
    #expect(auditEvents.contains(where: { $0.eventType == .evidenceLinked }))
}

@Test
func reconciliationServiceRevokeDocumentMatchProposalApprovalRevokesEvidenceLink() throws {
    let harness = try IssueProposalHarness()
    try harness.importFixtureStatement()
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "Coffee Bar Zurich" })
    )
    let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)
    let transactionRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
    let proposal = AgentProposal(
        fingerprint: "document-match-revoke",
        workspaceId: harness.storage.manifest.workspace.id,
        agentKind: .systemHeuristics,
        proposalType: .documentLinkReview,
        targetRef: documentRef,
        relatedRef: transactionRef,
        summary: "Review receipt match",
        rationale: "The receipt amount and date match the coffee transaction.",
        confidence: 0.91,
        status: .pending,
        createdAt: harness.fixedNow
    )
    try harness.storage.agentProposalRepository.saveAgentProposal(proposal)

    _ = try harness.reconciliationService.approveDocumentMatchProposal(
        proposal.id,
        actorId: "reviewer",
        reason: "Reviewer confirmed receipt and transaction match.",
        now: harness.fixedNow.addingTimeInterval(60)
    )
    #expect(try harness.transactionService.linkedDocumentIDs(for: transaction.id) == [document.id])
    #expect(try harness.documentService.linkedTransactionIDs(for: document.id) == [transaction.id])

    let revoked = try harness.reconciliationService.revokeDocumentMatchProposalApproval(
        proposal.id,
        actorId: "reviewer",
        reason: "Reviewer found the receipt belongs to another transaction.",
        now: harness.fixedNow.addingTimeInterval(120)
    )

    #expect(revoked.status == .rejected)
    #expect(revoked.decidedAt == harness.fixedNow.addingTimeInterval(120))
    #expect(revoked.decidedBy == "reviewer")
    #expect(revoked.decisionReason == "Reviewer found the receipt belongs to another transaction.")

    let links = try harness.storage.evidenceLinkRepository.fetchEvidenceLinks(for: documentRef)
    let link = try #require(links.first)
    #expect(link.status == .revoked)
    #expect(link.reason == "Reviewer found the receipt belongs to another transaction.")
    #expect(try harness.reconciliationService.hasConfirmedDocumentLink(for: transaction.id) == nil)
    #expect(try harness.reconciliationService.hasConfirmedTransactionLink(for: document.id) == false)
    #expect(try harness.transactionService.linkedDocumentIDs(for: transaction.id).isEmpty)
    #expect(try harness.documentService.linkedTransactionIDs(for: document.id).isEmpty)
    #expect(throws: DomainError.self) {
        _ = try harness.reconciliationService.approveDocumentMatchProposal(
            proposal.id,
            actorId: "reviewer",
            reason: "Approve again",
            now: harness.fixedNow.addingTimeInterval(180)
        )
    }

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: nil
    )
    #expect(auditEvents.contains(where: { $0.eventType == .proposalRejected }))
    #expect(auditEvents.contains(where: { $0.eventType == .evidenceLinkRevoked }))
}

@Test
func reconciliationServiceRejectsCrossEntityDocumentMatchApproval() throws {
    let harness = try IssueProposalHarness()
    try harness.importFixtureStatement()
    let business = try harness.createBusinessEntity(name: "Proposal Scope Business")
    let document = try harness.documentService.importDocument(
        from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"),
        entityId: business.entity.id
    )
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "Coffee Bar Zurich" })
    )
    let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)
    let transactionRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
    let proposal = AgentProposal(
        fingerprint: "document-match-cross-entity-approval",
        workspaceId: harness.storage.manifest.workspace.id,
        agentKind: .systemHeuristics,
        proposalType: .documentLinkReview,
        targetRef: documentRef,
        relatedRef: transactionRef,
        summary: "Review cross-entity receipt match",
        rationale: "Synthetic stale proposal with mismatched entity refs.",
        confidence: 0.91,
        status: .pending,
        createdAt: harness.fixedNow
    )
    try harness.storage.agentProposalRepository.saveAgentProposal(proposal)

    do {
        _ = try harness.reconciliationService.approveDocumentMatchProposal(
            proposal.id,
            actorId: "reviewer",
            reason: "Reviewer should not be able to cross-link entities.",
            now: harness.fixedNow.addingTimeInterval(60)
        )
        Issue.record("Expected cross-entity document-match approval to be rejected.")
    } catch let error as DomainError {
        #expect(error == .invalidEvidenceLink)
    }

    let persistedProposal = try #require(try harness.storage.agentProposalRepository.fetchAgentProposal(id: proposal.id))
    #expect(persistedProposal.status == .pending)
    #expect(try harness.storage.evidenceLinkRepository.fetchEvidenceLinks(for: documentRef).isEmpty)
    #expect(try harness.storage.evidenceLinkRepository.fetchEvidenceLinks(for: transactionRef).isEmpty)
}

private struct IssueProposalHarness {
    let fixedNow = try! #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let storage: WorkspaceStorage
    let account: FinancialAccount
    let documentService: DocumentService
    let importJobService: ImportJobService
    let transactionService: TransactionService
    let issueService: IssueService
    let reconciliationService: ReconciliationService
    let legalEntityService: LegalEntityService
    let entity: LegalEntity

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
        storage = try workspaceService.createWorkspace(named: "Issue Proposal Harness")

        let auditLogger = AuditLogger(storage: storage)
        documentService = DocumentService(storage: storage, auditLogger: auditLogger)
        importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
        transactionService = TransactionService(storage: storage)
        issueService = IssueService(storage: storage, auditLogger: auditLogger)
        reconciliationService = ReconciliationService(storage: storage, auditLogger: auditLogger)
        legalEntityService = LegalEntityService(storage: storage, auditLogger: auditLogger, nowProvider: { fixedNow })
        entity = try #require(try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first)
        account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    }

    func importFixtureStatement() throws {
        _ = try importJobService.importStatement(
            from: try fixtureURL("Fixtures/Bank/sample-bank-statement.csv"),
            accountId: account.id
        )
    }

    func createBusinessEntity(name: String) throws -> (entity: LegalEntity, account: FinancialAccount) {
        let entity = try legalEntityService.createSoleProprietor(name: name)
        let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
        return (entity, account)
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
