import Foundation
import Testing
@testable import ALAudit
@testable import ALDocuments
@testable import ALEvidence
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
        now: harness.fixedNow.addingTimeInterval(60)
    )
    #expect(rejected.status == .rejected)

    let resynced = try harness.reconciliationService.syncDocumentLinkProposal(
        for: document,
        hasConfirmedLink: false,
        now: harness.fixedNow.addingTimeInterval(120)
    )
    #expect(resynced.status == .rejected)

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: nil
    )
    #expect(auditEvents.contains(where: { $0.eventType == .proposalRejected }))
}

private struct IssueProposalHarness {
    let fixedNow = try! #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let storage: WorkspaceStorage
    let documentService: DocumentService
    let issueService: IssueService
    let reconciliationService: ReconciliationService

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
        issueService = IssueService(storage: storage, auditLogger: auditLogger)
        reconciliationService = ReconciliationService(storage: storage, auditLogger: auditLogger)
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
