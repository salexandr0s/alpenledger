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
func statementImportPreservesRawSourceBlobAfterSourceFileChanges() throws {
    let harness = try EvidenceHarness()
    let sourceURL = try mutableFixtureCopy(
        relativePath: "Fixtures/Bank/sample-bank-statement.csv",
        filename: "mutable-bank-statement.csv"
    )
    let originalData = try Data(contentsOf: sourceURL)

    _ = try harness.importJobService.importStatement(from: sourceURL, accountId: harness.account.id)
    let statementImport = try #require(
        try harness.storage.statementImportRepository
            .fetchStatementImports(accountId: harness.account.id)
            .first
    )

    try Data("booking_date,value_date,amount,currency,counterparty,memo,reference,balance\n".utf8)
        .write(to: sourceURL, options: .atomic)

    #expect(try harness.storage.blobStore.read(hash: statementImport.sourceBlobHash) == originalData)
}

@Test
func statementImportRejectsLockedTaxYearTransactions() throws {
    let harness = try EvidenceHarness()
    var taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    taxYear.status = .locked
    try harness.storage.taxYearRepository.saveTaxYear(taxYear)

    do {
        _ = try harness.importJobService.importStatement(
            from: try fixtureURL("Fixtures/Bank/sample-bank-statement.csv"),
            accountId: harness.account.id
        )
        Issue.record("Expected locked period import to be rejected.")
    } catch let error as DomainError {
        #expect(error == .lockedPeriod)
    }

    #expect(try harness.transactionService.listTransactions(accountId: harness.account.id).isEmpty)
    #expect(try harness.storage.statementImportRepository.fetchStatementImports(accountId: harness.account.id).isEmpty)
    let importJobs = try harness.storage.importJobRepository.fetchImportJobs(workspaceId: harness.storage.manifest.workspace.id)
    #expect(importJobs.first?.status == .failed)
}

@Test
func documentImportPreservesRawSourceBlobAfterSourceFileChanges() throws {
    let harness = try EvidenceHarness()
    let sourceURL = try mutableFixtureCopy(
        relativePath: "Fixtures/Documents/sample-receipt.pdf",
        filename: "mutable-receipt.pdf"
    )
    let originalData = try Data(contentsOf: sourceURL)

    let document = try harness.documentService.importDocument(from: sourceURL)

    try Data("changed after import".utf8).write(to: sourceURL, options: .atomic)

    #expect(try harness.storage.blobStore.read(hash: document.blobHash) == originalData)
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
    #expect(try harness.storage.databaseHealthReport().isHealthy)

    try harness.evidenceRefreshService.refresh()
    let secondRequirements = try harness.storage.requirementRepository.fetchRequirements(entityId: harness.entity.id)
    let secondIssues = try harness.storage.issueRepository.fetchIssues(workspaceId: harness.storage.manifest.workspace.id, status: nil)
    let secondProposals = try harness.storage.agentProposalRepository.fetchAgentProposals(workspaceId: harness.storage.manifest.workspace.id, status: nil)
    #expect(try harness.storage.databaseHealthReport().isHealthy)

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
func businessExpenseEvidenceLinkSatisfiesMissingEvidenceRequirement() throws {
    let harness = try EvidenceHarness()
    let business = try harness.createBusinessEntity(name: "Evidence Linked Business")
    let transaction = Transaction(
        accountId: business.account.id,
        originKind: .imported,
        sourceLineRef: "business-expense-1",
        bookingDate: date("2026-03-01T00:00:00Z"),
        amountMinor: -12_990,
        currency: .chf,
        counterpartyName: "Studio Supplier",
        memo: "Business materials"
    )
    try harness.storage.transactionRepository.saveTransactions([transaction])
    let document = try harness.documentService.importDocument(
        from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"),
        entityId: business.entity.id
    )
    let transactionRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
    let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)

    try harness.evidenceRefreshService.refresh()

    let openIssue = try #require(
        try harness.evidenceRefreshService.listIssues(status: .open)
            .first {
                $0.entityId == business.entity.id &&
                    $0.issueCode == .missingExpenseEvidence &&
                    $0.objectRef == transactionRef
            }
    )
    let pendingRequirement = try #require(
        try harness.storage.requirementRepository.fetchRequirement(
            fingerprint: "expense-evidence|\(transaction.id)"
        )
    )
    #expect(openIssue.summary == "Missing supporting evidence for Studio Supplier")
    #expect(openIssue.severity == .warning)
    #expect(pendingRequirement.entityId == business.entity.id)
    #expect(pendingRequirement.status == .pending)
    #expect(pendingRequirement.satisfiedByRef == nil)

    try harness.documentService.linkDocument(document.id, to: transaction.id)
    try harness.evidenceRefreshService.refresh()

    let remainingOpenIssues = try harness.evidenceRefreshService.listIssues(status: .open)
        .filter {
            $0.entityId == business.entity.id &&
                $0.issueCode == .missingExpenseEvidence &&
                $0.objectRef == transactionRef
        }
    let resolvedIssue = try #require(
        try harness.storage.issueRepository.fetchIssue(
            fingerprint: "missing-expense-evidence|\(transaction.id)"
        )
    )
    let satisfiedRequirement = try #require(
        try harness.storage.requirementRepository.fetchRequirement(
            fingerprint: "expense-evidence|\(transaction.id)"
        )
    )

    #expect(remainingOpenIssues.isEmpty)
    #expect(resolvedIssue.status == .resolved)
    #expect(satisfiedRequirement.status == .satisfied)
    #expect(satisfiedRequirement.satisfiedByRef == documentRef)
    #expect(try harness.transactionService.linkedDocumentIDs(for: transaction.id) == [document.id])
    #expect(try harness.documentService.linkedTransactionIDs(for: document.id) == [transaction.id])
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
    #expect(resolved.first?.decidedAt == harness.fixedNow)
    #expect(resolved.first?.decidedBy == "system")
    #expect(resolved.first?.decisionReason == "Confirmed document-to-transaction link exists.")
}

@Test
func agentToolWorkflowRequiresScopeBeforeOpeningIssue() throws {
    let harness = try EvidenceHarness()
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentIssueOpenOrUpdateInput(
        fingerprint: "agent-tool|missing-statement",
        entityId: harness.entity.id,
        issueCode: .missingStatementCoverage,
        severity: .blocking,
        summary: "Missing February statement",
        objectRef: ObjectRef(kind: .financialAccount, id: harness.account.id.rawValue)
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "issues.open_or_update",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: []
            )
        )
        Issue.record("Expected missing issue-write scope to reject before the handler ran.")
    } catch let error as AgentToolExecutionError {
        #expect(error == .missingScopes(
            toolName: "issues.open_or_update",
            required: [.issuesWrite],
            granted: []
        ))
    }

    #expect(try harness.issueService.listIssues(status: nil).isEmpty)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "issues.open_or_update")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .issueUpdate)
    #expect(auditPayload.requiredScopes == [.issuesWrite])
    #expect(auditPayload.grantedScopes == [])
    #expect(auditPayload.confirmationProvided == false)
    #expect(auditPayload.provenanceRefs.isEmpty)
    #expect(auditPayload.errorCode == "missingScopes")
}

@Test
func agentToolWorkflowOpensIssueThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let objectRef = ObjectRef(kind: .financialAccount, id: harness.account.id.rawValue)
    let input = AgentIssueOpenOrUpdateInput(
        fingerprint: "agent-tool|missing-statement",
        entityId: harness.entity.id,
        issueCode: .missingStatementCoverage,
        severity: .blocking,
        summary: "Missing February statement",
        objectRef: objectRef
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "issues.open_or_update",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.issuesWrite]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentIssueToolOutput.self, from: result.outputJSON)
    let issue = try #require(try harness.storage.issueRepository.fetchIssue(fingerprint: input.fingerprint))
    #expect(output.issueId == issue.id)
    #expect(issue.status == .open)
    #expect(issue.objectRef == objectRef)
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .issue, id: issue.id.rawValue)))
    #expect(result.provenanceRefs.contains(objectRef))
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .issue, id: issue.id.rawValue)
    )
    #expect(auditEvents.contains { $0.eventType == .issueOpened })
}

@Test
func agentToolWorkflowRejectsIssueOpenForCrossEntityObjectRef() throws {
    let harness = try EvidenceHarness()
    let business = try harness.createBusinessEntity(name: "Issue Scope Business")
    let businessTransaction = Transaction(
        accountId: business.account.id,
        originKind: .manual,
        sourceLineRef: "business-office-supplies",
        bookingDate: date("2026-03-05T00:00:00Z"),
        amountMinor: -8_450,
        currency: .chf,
        counterpartyName: "Office Supplier",
        memo: "Business office supplies"
    )
    try harness.storage.transactionRepository.saveTransactions([businessTransaction])
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let fingerprint = "agent-tool|cross-entity-issue"
    let input = AgentIssueOpenOrUpdateInput(
        fingerprint: fingerprint,
        entityId: harness.entity.id,
        issueCode: .missingExpenseEvidence,
        severity: .warning,
        summary: "Missing evidence for a transaction outside the active entity.",
        objectRef: ObjectRef(kind: .transaction, id: businessTransaction.id.rawValue)
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "issues.open_or_update",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.issuesWrite]
            )
        )
        Issue.record("Expected cross-entity issue source ref to be rejected.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("issues.open_or_update"))
    }

    #expect(try harness.storage.issueRepository.fetchIssue(fingerprint: fingerprint) == nil)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "issues.open_or_update")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.errorCode == "invalidInput")
}

@Test
func agentToolWorkflowAuditsSuccessfulToolExecutionWithoutRawInputOrOutput() throws {
    let harness = try EvidenceHarness()
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentFinanceListAccountsInput(entityId: harness.entity.id)

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "finance.list_accounts",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.financeRead]
        )
    )

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let executedEvent = try #require(auditEvents.first { $0.eventType == .agentToolExecuted })
    let auditPayload = try agentToolAuditPayload(from: executedEvent)
    #expect(auditPayload.toolName == "finance.list_accounts")
    #expect(auditPayload.outcome == .executed)
    #expect(auditPayload.sideEffect == .readOnly)
    #expect(auditPayload.requiredScopes == [.financeRead])
    #expect(auditPayload.grantedScopes == [.financeRead])
    #expect(auditPayload.confirmationProvided == false)
    #expect(auditPayload.provenanceRefs == result.provenanceRefs)
    #expect(auditPayload.errorCode == nil)
    #expect(auditPayload.durationMilliseconds == 0)
    #expect(executedEvent.payload?.contains(harness.account.displayName) == false)
    #expect(executedEvent.payload?.contains(harness.entity.displayName) == false)
}

@Test
func agentToolWorkflowListsOpenIssuesThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    try harness.evidenceRefreshService.refresh()
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentIssueListInput(entityId: harness.entity.id)

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "issues.list_open",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.reconcileRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentIssueListOutput.self, from: result.outputJSON)
    #expect(output.issues.count == 3)
    #expect(output.issues.allSatisfy { $0.status == .open })
    #expect(output.issues.contains { $0.summary.contains("February 2026") })
    for issue in output.issues {
        #expect(result.provenanceRefs.contains(ObjectRef(kind: .issue, id: issue.issueId.rawValue)))
    }
}

@Test
func agentToolWorkflowListsFinancialAccountsThroughExecutor() throws {
    let harness = try EvidenceHarness()
    let business = try harness.createBusinessEntity(name: "Tool Listed Business")
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentFinanceListAccountsInput(entityId: business.entity.id)

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "finance.list_accounts",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.financeRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentFinanceListAccountsOutput.self, from: result.outputJSON)
    #expect(output.accounts.map(\.accountId) == [business.account.id])
    #expect(output.accounts.first?.entityId == business.entity.id)
    #expect(result.provenanceRefs == [ObjectRef(kind: .financialAccount, id: business.account.id.rawValue)])
}

@Test
func agentReadOnlyToolsRejectMissingEntityScopeBeforeReturningEmptyProvenance() throws {
    let harness = try EvidenceHarness()
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let missingEntityId = LegalEntityID(rawValue: UUID())

    func expectEntityNotFound(
        toolName: String,
        inputJSON: Data,
        grantedScopes: Set<AgentToolScope>
    ) throws {
        do {
            _ = try agentToolService.execute(
                AgentToolInvocation(
                    toolName: toolName,
                    inputJSON: inputJSON,
                    grantedScopes: grantedScopes
                )
            )
            Issue.record("Expected \(toolName) to reject a missing entity scope.")
        } catch let error as DomainError {
            #expect(error == .entityNotFound)
        }
    }

    try expectEntityNotFound(
        toolName: "finance.list_accounts",
        inputJSON: try JSONEncoder.alpenLedger.encode(AgentFinanceListAccountsInput(entityId: missingEntityId)),
        grantedScopes: [.financeRead]
    )
    try expectEntityNotFound(
        toolName: "finance.search_transactions",
        inputJSON: try JSONEncoder.alpenLedger.encode(AgentFinanceSearchTransactionsInput(entityId: missingEntityId)),
        grantedScopes: [.financeRead]
    )
    try expectEntityNotFound(
        toolName: "docs.search",
        inputJSON: try JSONEncoder.alpenLedger.encode(AgentDocsSearchInput(entityId: missingEntityId)),
        grantedScopes: [.documentsRead]
    )
    try expectEntityNotFound(
        toolName: "reconcile.statement_coverage",
        inputJSON: try JSONEncoder.alpenLedger.encode(AgentReconcileStatementCoverageInput(entityId: missingEntityId)),
        grantedScopes: [.reconcileRead]
    )
    try expectEntityNotFound(
        toolName: "issues.list_open",
        inputJSON: try JSONEncoder.alpenLedger.encode(AgentIssueListInput(entityId: missingEntityId)),
        grantedScopes: [.reconcileRead]
    )

    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "issues.list_open",
                inputJSON: try JSONEncoder.alpenLedger.encode(
                    AgentIssueListInput(entityId: nil, taxYearId: taxYear.id)
                ),
                grantedScopes: [.reconcileRead]
            )
        )
        Issue.record("Expected tax-year issue lookup without entity scope to be rejected.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("issues.list_open"))
    }

    let rejectedEvents = try harness.storage.auditEventRepository
        .fetchAuditEvents(
            workspaceId: harness.storage.manifest.workspace.id,
            objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
        )
        .filter { $0.eventType == .agentToolRejected }
    let payloads = try rejectedEvents.map { try agentToolAuditPayload(from: $0) }
    #expect(payloads.contains {
        $0.toolName == "finance.list_accounts" &&
            $0.outcome == .rejected &&
            $0.errorCode == "entityNotFound"
    })
    #expect(payloads.contains {
        $0.toolName == "issues.list_open" &&
            $0.outcome == .rejected &&
            $0.errorCode == "invalidInput"
    })
}

@Test
func agentToolWorkflowExplainsAccountSummaryThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    let statementImport = try #require(
        try harness.storage.statementImportRepository
            .fetchStatementImports(accountId: harness.account.id)
            .first
    )
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentFinanceAccountSummaryInput(entityId: harness.entity.id, accountId: harness.account.id)

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "finance.account_summary",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.financeRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(
        AgentFinanceAccountSummaryOutput.self,
        from: result.outputJSON
    )
    #expect(output.account.accountId == harness.account.id)
    #expect(output.transactionCount == 3)
    #expect(output.latestBalanceMinor == 233_750)
    #expect(output.statementImportCount == 1)
    #expect(output.latestStatementImportId == statementImport.id)
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .financialAccount, id: harness.account.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .statementImport, id: statementImport.id.rawValue)))
    #expect(output.latestBalanceSourceTransactionId.map {
        result.provenanceRefs.contains(ObjectRef(kind: .transaction, id: $0.rawValue))
    } == true)
}

@Test
func agentToolWorkflowAccountSummaryUsesOpeningBalanceWhenRunningBalanceIsMissing() throws {
    let harness = try EvidenceHarness()
    var account = harness.account
    account.openingBalanceMinor = 100_000
    account.openingBalanceDate = date("2026-01-01T00:00:00Z")
    try harness.storage.financialAccountRepository.saveFinancialAccount(account)
    try harness.storage.transactionRepository.saveTransactions([
        Transaction(
            accountId: account.id,
            originKind: .manual,
            sourceLineRef: "manual-opening-balance-check",
            bookingDate: date("2026-01-05T00:00:00Z"),
            amountMinor: -12_500,
            currency: .chf,
            counterpartyName: "Supplier",
            memo: "Supplies after opening balance"
        )
    ])
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "finance.account_summary",
            inputJSON: try JSONEncoder.alpenLedger.encode(
                AgentFinanceAccountSummaryInput(entityId: harness.entity.id, accountId: account.id)
            ),
            grantedScopes: [.financeRead]
        )
    )
    let output = try JSONDecoder.alpenLedger.decode(
        AgentFinanceAccountSummaryOutput.self,
        from: result.outputJSON
    )

    #expect(output.account.openingBalanceMinor == 100_000)
    #expect(output.latestBalanceMinor == 87_500)
    #expect(output.latestBalanceSourceTransactionId == nil)
}

@Test
func agentToolWorkflowSearchesTransactionsThroughExecutorWithScopedProvenance() throws {
    let harness = try EvidenceHarness()
    let business = try harness.createBusinessEntity(name: "Tool Search Business")
    let personalTransaction = Transaction(
        accountId: harness.account.id,
        originKind: .manual,
        sourceLineRef: "personal-studio",
        bookingDate: date("2026-03-03T00:00:00Z"),
        amountMinor: -7_500,
        currency: .chf,
        counterpartyName: "Studio Supplier",
        memo: "Personal materials"
    )
    let businessTransaction = Transaction(
        accountId: business.account.id,
        originKind: .manual,
        sourceLineRef: "business-studio",
        bookingDate: date("2026-03-04T00:00:00Z"),
        amountMinor: -12_990,
        currency: .chf,
        counterpartyName: "Studio Supplier",
        memo: "Business materials",
        reference: "INV-2026-003"
    )
    try harness.storage.transactionRepository.saveTransactions([personalTransaction, businessTransaction])
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentFinanceSearchTransactionsInput(
        entityId: business.entity.id,
        query: "studio",
        from: date("2026-03-01T00:00:00Z"),
        through: date("2026-03-31T00:00:00Z"),
        maximumAmountMinor: -1,
        limit: 10
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "finance.search_transactions",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.financeRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(
        AgentFinanceSearchTransactionsOutput.self,
        from: result.outputJSON
    )
    #expect(output.transactions.map(\.transactionId) == [businessTransaction.id])
    #expect(output.transactions.first?.accountDisplayName == business.account.displayName)
    #expect(result.provenanceRefs == [ObjectRef(kind: .transaction, id: businessTransaction.id.rawValue)])

    let crossEntityInput = AgentFinanceSearchTransactionsInput(
        entityId: business.entity.id,
        accountId: harness.account.id,
        query: "studio"
    )
    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "finance.search_transactions",
                inputJSON: try JSONEncoder.alpenLedger.encode(crossEntityInput),
                grantedScopes: [.financeRead]
            )
        )
        Issue.record("Expected cross-entity account search to be rejected.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("finance.search_transactions"))
    }
}

@Test
func agentToolWorkflowGetsDocumentSummaryThroughExecutorWithBoundedSnippet() throws {
    let harness = try EvidenceHarness()
    let documentURL = try uniqueTextFixtureCopy(
        relativePath: "Fixtures/Documents/sample-qr-bill.txt",
        filename: "summary-assigned.txt",
        suffix: "Assigned document summary scope."
    )
    let document = try harness.documentService.importDocument(
        from: documentURL,
        entityId: harness.entity.id
    )
    #expect(document.entityId == harness.entity.id)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentDocsGetSummaryInput(
        documentId: document.id,
        entityId: harness.entity.id,
        maximumSnippetCharacters: 80
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "docs.get_summary",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.documentsRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentDocsGetSummaryOutput.self, from: result.outputJSON)
    #expect(output.document.documentId == document.id)
    #expect(output.document.documentType == .qrBill)
    #expect(output.textSnippet?.contains("Alpine Utilities") == true)
    #expect((output.textSnippet?.count ?? 0) <= 80)
    #expect(output.snippetTruncated)
    #expect(result.provenanceRefs == [ObjectRef(kind: .document, id: document.id.rawValue)])

    let invalidInput = AgentDocsGetSummaryInput(
        documentId: document.id,
        entityId: harness.entity.id,
        maximumSnippetCharacters: 0
    )
    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "docs.get_summary",
                inputJSON: try JSONEncoder.alpenLedger.encode(invalidInput),
                grantedScopes: [.documentsRead]
            )
        )
        Issue.record("Expected invalid document summary snippet limit to be rejected.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("docs.get_summary"))
    }

    let business = try harness.createBusinessEntity(name: "Document Summary Scope Business")
    let businessDocumentURL = try uniqueTextFixtureCopy(
        relativePath: "Fixtures/Documents/sample-qr-bill.txt",
        filename: "summary-business.txt",
        suffix: "Business document summary scope."
    )
    let businessDocument = try harness.documentService.importDocument(
        from: businessDocumentURL,
        entityId: business.entity.id
    )
    #expect(businessDocument.entityId == business.entity.id)

    let unscopedAssignedInput = AgentDocsGetSummaryInput(documentId: businessDocument.id)
    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "docs.get_summary",
                inputJSON: try JSONEncoder.alpenLedger.encode(unscopedAssignedInput),
                grantedScopes: [.documentsRead]
            )
        )
        Issue.record("Expected assigned document summary without entity scope to be rejected.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("docs.get_summary"))
    }

    let crossEntityInput = AgentDocsGetSummaryInput(
        documentId: businessDocument.id,
        entityId: harness.entity.id,
        maximumSnippetCharacters: 80
    )
    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "docs.get_summary",
                inputJSON: try JSONEncoder.alpenLedger.encode(crossEntityInput),
                grantedScopes: [.documentsRead]
            )
        )
        Issue.record("Expected cross-entity document summary to be rejected.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("docs.get_summary"))
    }

    let unassignedDocumentURL = try uniqueTextFixtureCopy(
        relativePath: "Fixtures/Documents/sample-qr-bill.txt",
        filename: "summary-unassigned.txt",
        suffix: "Unassigned document summary scope."
    )
    let unassignedDocument = try harness.documentService.importDocument(
        from: unassignedDocumentURL
    )
    #expect(unassignedDocument.entityId == nil)
    let unassignedResult = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "docs.get_summary",
            inputJSON: try JSONEncoder.alpenLedger.encode(
                AgentDocsGetSummaryInput(documentId: unassignedDocument.id, maximumSnippetCharacters: 80)
            ),
            grantedScopes: [.documentsRead]
        )
    )
    let unassignedOutput = try JSONDecoder.alpenLedger.decode(
        AgentDocsGetSummaryOutput.self,
        from: unassignedResult.outputJSON
    )
    #expect(unassignedOutput.document.documentId == unassignedDocument.id)
    #expect(unassignedOutput.document.entityId == nil)

    _ = try harness.documentService.archiveDocument(
        document.id,
        actorId: "reviewer",
        reason: "Remove duplicate source from active document tools.",
        now: harness.fixedNow
    )
    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "docs.get_summary",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.documentsRead]
            )
        )
        Issue.record("Expected archived document summaries to be rejected.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("docs.get_summary"))
    }
}

@Test
func agentToolWorkflowSearchesDocumentsThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    let documentURL = try uniqueTextFixtureCopy(
        relativePath: "Fixtures/Documents/sample-qr-bill.txt",
        filename: "search-assigned.txt",
        suffix: "Assigned document search scope."
    )
    let document = try harness.documentService.importDocument(
        from: documentURL,
        entityId: harness.entity.id
    )
    let business = try harness.createBusinessEntity(name: "Document Search Scope Business")
    let businessDocumentURL = try uniqueTextFixtureCopy(
        relativePath: "Fixtures/Documents/sample-qr-bill.txt",
        filename: "search-business.txt",
        suffix: "Business document search scope."
    )
    let businessDocument = try harness.documentService.importDocument(
        from: businessDocumentURL,
        entityId: business.entity.id
    )
    let unassignedDocumentURL = try uniqueTextFixtureCopy(
        relativePath: "Fixtures/Documents/sample-qr-bill.txt",
        filename: "search-unassigned.txt",
        suffix: "Unassigned document search scope."
    )
    let unassignedDocument = try harness.documentService.importDocument(from: unassignedDocumentURL)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentDocsSearchInput(
        entityId: harness.entity.id,
        query: "Alpine Utilities",
        documentType: .qrBill,
        limit: 5
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "docs.search",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.documentsRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentDocsSearchOutput.self, from: result.outputJSON)
    #expect(output.documents.map(\.documentId) == [document.id])
    #expect(output.documents.first?.documentType == .qrBill)
    #expect(result.provenanceRefs == [ObjectRef(kind: .document, id: document.id.rawValue)])

    _ = try harness.documentService.archiveDocument(
        document.id,
        actorId: "reviewer",
        reason: "Hide duplicate source from active document search.",
        now: harness.fixedNow
    )
    let archivedSearchResult = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "docs.search",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.documentsRead]
        )
    )
    let archivedSearchOutput = try JSONDecoder.alpenLedger.decode(
        AgentDocsSearchOutput.self,
        from: archivedSearchResult.outputJSON
    )
    #expect(archivedSearchOutput.documents.isEmpty)

    let businessResult = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "docs.search",
            inputJSON: try JSONEncoder.alpenLedger.encode(
                AgentDocsSearchInput(entityId: business.entity.id, query: "Alpine Utilities", limit: 5)
            ),
            grantedScopes: [.documentsRead]
        )
    )
    let businessOutput = try JSONDecoder.alpenLedger.decode(
        AgentDocsSearchOutput.self,
        from: businessResult.outputJSON
    )
    #expect(businessOutput.documents.map(\.documentId) == [businessDocument.id])
    #expect(businessOutput.documents.first?.entityId == business.entity.id)

    let unscopedResult = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "docs.search",
            inputJSON: try JSONEncoder.alpenLedger.encode(
                AgentDocsSearchInput(query: "Alpine Utilities", documentType: .qrBill, limit: 10)
            ),
            grantedScopes: [.documentsRead]
        )
    )
    let unscopedOutput = try JSONDecoder.alpenLedger.decode(
        AgentDocsSearchOutput.self,
        from: unscopedResult.outputJSON
    )
    #expect(unscopedOutput.documents.map(\.documentId) == [unassignedDocument.id])
    #expect(unscopedOutput.documents.first?.entityId == nil)
    #expect(unscopedResult.provenanceRefs == [ObjectRef(kind: .document, id: unassignedDocument.id.rawValue)])

    let unscopedListResult = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "docs.search",
            inputJSON: try JSONEncoder.alpenLedger.encode(
                AgentDocsSearchInput(documentType: .qrBill, limit: 10)
            ),
            grantedScopes: [.documentsRead]
        )
    )
    let unscopedListOutput = try JSONDecoder.alpenLedger.decode(
        AgentDocsSearchOutput.self,
        from: unscopedListResult.outputJSON
    )
    #expect(unscopedListOutput.documents.map(\.documentId) == [unassignedDocument.id])

    let invalidInput = AgentDocsSearchInput(entityId: harness.entity.id, query: "Alpine", limit: 0)
    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "docs.search",
                inputJSON: try JSONEncoder.alpenLedger.encode(invalidInput),
                grantedScopes: [.documentsRead]
            )
        )
        Issue.record("Expected invalid document search limit to be rejected.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("docs.search"))
    }
}

@Test
func agentToolWorkflowReportsStatementCoverageThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    try harness.evidenceRefreshService.refresh()
    let missingRequirement = try #require(
        try harness.storage.requirementRepository
            .fetchRequirements(entityId: harness.entity.id)
            .first {
                $0.requirementCode == .statementCoverage &&
                    $0.status == .pending &&
                    $0.summary.contains("February 2026")
            }
    )
    let missingIssue = try #require(
        try harness.evidenceRefreshService.listIssues(status: .open)
            .first { $0.issueCode == .missingStatementCoverage }
    )
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentReconcileStatementCoverageInput(
        entityId: harness.entity.id,
        accountId: harness.account.id,
        includeSatisfied: false
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "reconcile.statement_coverage",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.reconcileRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(
        AgentReconcileStatementCoverageOutput.self,
        from: result.outputJSON
    )
    #expect(output.rows.count == 1)
    #expect(output.rows.first?.accountId == harness.account.id)
    #expect(output.rows.first?.requirementId == missingRequirement.id)
    #expect(output.rows.first?.requirementStatus == .pending)
    #expect(output.rows.first?.issueId == missingIssue.id)
    #expect(output.rows.first?.issueSeverity == .blocking)
    #expect(output.rows.first?.issueStatus == .open)
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .financialAccount, id: harness.account.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .requirement, id: missingRequirement.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .issue, id: missingIssue.id.rawValue)))
}

@Test
func agentToolWorkflowListsTaxRequirementsThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let requirement = try RequirementService(storage: harness.storage).syncRequirement(
        fingerprint: "tax.list.requirements|\(taxYear.id.rawValue)",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        code: .expenseEvidence,
        subjectRef: ObjectRef(kind: .taxYear, id: taxYear.id.rawValue),
        summary: "Upload salary certificate for 2026.",
        coverageStart: taxYear.periodStart,
        coverageEnd: taxYear.periodEnd,
        status: .pending,
        satisfiedByRef: nil,
        now: harness.fixedNow
    )
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentTaxListRequirementsInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        requirementCode: .expenseEvidence,
        status: .pending
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "tax.list_requirements",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.taxRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentTaxListRequirementsOutput.self, from: result.outputJSON)
    #expect(output.requirements.map(\.requirementId) == [requirement.id])
    #expect(output.requirements.first?.status == .pending)
    #expect(result.provenanceRefs == [ObjectRef(kind: .requirement, id: requirement.id.rawValue)])
}

@Test
func agentToolWorkflowPreviewsTaxStatusThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let requirement = try RequirementService(storage: harness.storage).syncRequirement(
        fingerprint: "tax.preview.requirement|\(taxYear.id.rawValue)",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        code: .expenseEvidence,
        subjectRef: ObjectRef(kind: .taxYear, id: taxYear.id.rawValue),
        summary: "Upload salary certificate for preview.",
        coverageStart: taxYear.periodStart,
        coverageEnd: taxYear.periodEnd,
        status: .pending,
        satisfiedByRef: nil,
        now: harness.fixedNow
    )
    let issue = try harness.issueService.syncIssue(
        fingerprint: "tax.preview.issue|\(requirement.id.rawValue)",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        code: .missingExpenseEvidence,
        severity: .blocking,
        status: .open,
        summary: "Salary certificate is missing.",
        objectRef: requirement.subjectRef,
        relatedRef: ObjectRef(kind: .requirement, id: requirement.id.rawValue),
        now: harness.fixedNow
    )
    let fact = TaxFact(
        fingerprint: "tax.preview.fact|\(taxYear.id.rawValue)",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "salary.gross",
        valueType: .money,
        moneyMinor: 12_000_000,
        currency: .chf,
        status: .observed,
        rulesetVersion: taxYear.rulesetVersion,
        provenanceRefs: [],
        confidence: 1,
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.taxFactRepository.saveTaxFact(fact)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentTaxPreviewStatusInput(entityId: harness.entity.id, taxYearId: taxYear.id)

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "tax.preview_status",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.taxRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentTaxPreviewStatusOutput.self, from: result.outputJSON)
    #expect(output.entityId == harness.entity.id)
    #expect(output.taxYearId == taxYear.id)
    #expect(output.readiness.state == .needsAttention)
    #expect(output.readiness.currentFactCount == 1)
    #expect(output.readiness.pendingRequirementCount == 1)
    #expect(output.readiness.openIssueCount == 1)
    #expect(output.currentFacts.map(\.taxFactId) == [fact.id])
    #expect(output.pendingRequirements.map(\.requirementId) == [requirement.id])
    #expect(output.openIssues.map(\.issueId) == [issue.id])
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .legalEntity, id: harness.entity.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .taxYear, id: taxYear.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .taxFact, id: fact.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .requirement, id: requirement.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .issue, id: issue.id.rawValue)))
}

@Test
func agentToolWorkflowExplainsTaxFactThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)
    let missingTransactionRef = ObjectRef(kind: .transaction, id: UUID())
    let fact = TaxFact(
        fingerprint: "tax.explain.fact|\(taxYear.id.rawValue)",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "deduction.professionalExpenses",
        valueType: .money,
        moneyMinor: 321_00,
        currency: .chf,
        status: .observed,
        rulesetVersion: taxYear.rulesetVersion,
        provenanceRefs: [documentRef, missingTransactionRef],
        confidence: 0.92,
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.taxFactRepository.saveTaxFact(fact)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentTaxExplainFactInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        factId: fact.id
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "tax.explain_fact",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.taxRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentTaxExplainFactOutput.self, from: result.outputJSON)
    #expect(output.fact.taxFactId == fact.id)
    #expect(output.summary.contains("deduction.professionalExpenses"))
    #expect(output.sourceSummaries.map(\.sourceRef) == [documentRef])
    #expect(output.sourceSummaries.first?.title == document.originalFilename)
    #expect(output.missingSourceRefs == [missingTransactionRef])
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .taxFact, id: fact.id.rawValue)))
    #expect(result.provenanceRefs.contains(documentRef))
    #expect(result.provenanceRefs.contains(missingTransactionRef) == false)
}

@Test
func agentToolWorkflowProposesTaxOverrideReasonWithoutMutatingTaxFact() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let fact = TaxFact(
        fingerprint: "tax.override.proposal|\(taxYear.id.rawValue)",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "salary.gross",
        valueType: .money,
        moneyMinor: 12_000_000,
        currency: .chf,
        status: .observed,
        rulesetVersion: taxYear.rulesetVersion,
        provenanceRefs: [],
        confidence: 1,
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.taxFactRepository.saveTaxFact(fact)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentTaxOverrideReasonProposalInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        factId: fact.id,
        proposedReason: "Employer corrected the annual certificate after the original import.",
        confidence: 0.72,
        rationale: "The source certificate was corrected by the employer, so a reviewer should decide whether to override this tax fact."
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "tax.propose_override_reason",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.taxPropose]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentProposalToolOutput.self, from: result.outputJSON)
    let proposal = try #require(try harness.storage.agentProposalRepository.fetchAgentProposal(id: output.proposalId))
    let unchangedFact = try #require(try harness.storage.taxFactRepository.fetchTaxFact(id: fact.id))
    #expect(proposal.proposalType == .taxOverrideReview)
    #expect(proposal.status == .pending)
    #expect(proposal.targetRef == ObjectRef(kind: .taxFact, id: fact.id.rawValue))
    #expect(proposal.relatedRef == nil)
    #expect(proposal.summary == "Review override reason for salary.gross")
    #expect(proposal.rationale == input.rationale)
    #expect(proposal.confidence == 0.72)
    #expect(output.targetRef == ObjectRef(kind: .taxFact, id: fact.id.rawValue))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .taxFact, id: fact.id.rawValue)))
    #expect(unchangedFact.status == .observed)
    #expect(unchangedFact.overrideReason == nil)
    #expect(unchangedFact.moneyMinor == fact.moneyMinor)

    let proposalEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)
    )
    #expect(proposalEvents.contains { $0.eventType == .proposalCreated })
    let factEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .taxFact, id: fact.id.rawValue)
    )
    #expect(factEvents.contains { $0.eventType == .taxFactOverridden } == false)
}

@Test
func agentToolWorkflowRejectsTaxOverrideProposalForMissingFact() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentTaxOverrideReasonProposalInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        factId: TaxFactID(),
        proposedReason: "The tax fact should be changed.",
        confidence: 0.6
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "tax.propose_override_reason",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.taxPropose]
            )
        )
        Issue.record("Expected missing tax fact to reject before creating a proposal.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .taxFactNotFound(input.factId))
    }

    let proposals = try harness.storage.agentProposalRepository.fetchAgentProposals(
        workspaceId: harness.storage.manifest.workspace.id,
        status: nil
    )
    #expect(proposals.isEmpty)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "tax.propose_override_reason")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .proposal)
    #expect(auditPayload.requiredScopes == [.taxPropose])
    #expect(auditPayload.errorCode == "taxFactNotFound")
}

@Test
func agentToolWorkflowAcceptsTaxOverrideWithExplicitConfirmation() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let sourceRef = ObjectRef(kind: .document, id: DocumentID().rawValue)
    let fact = TaxFact(
        fingerprint: "tax.override.accept|\(taxYear.id.rawValue)",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "salary.gross",
        valueType: .money,
        moneyMinor: 12_000_000,
        currency: .chf,
        status: .observed,
        rulesetVersion: taxYear.rulesetVersion,
        provenanceRefs: [sourceRef],
        confidence: 1,
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.taxFactRepository.saveTaxFact(fact)
    let proposalService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let proposalInput = AgentTaxOverrideReasonProposalInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        factId: fact.id,
        proposedReason: "Employer corrected the annual certificate after the original import.",
        confidence: 0.72,
        rationale: "The source certificate was corrected by the employer, so a reviewer should decide whether to override this tax fact."
    )
    let proposalResult = try proposalService.execute(
        AgentToolInvocation(
            toolName: "tax.propose_override_reason",
            inputJSON: try JSONEncoder.alpenLedger.encode(proposalInput),
            grantedScopes: [.taxPropose]
        )
    )
    let proposalOutput = try JSONDecoder.alpenLedger.decode(AgentProposalToolOutput.self, from: proposalResult.outputJSON)
    let approvedAt = harness.fixedNow.addingTimeInterval(60)
    let acceptService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { approvedAt }
    )
    let acceptInput = AgentRulesAcceptOverrideInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        factId: fact.id,
        proposalId: proposalOutput.proposalId,
        overrideReason: proposalInput.proposedReason
    )

    let result = try acceptService.execute(
        confirmedAgentToolInvocation(
            toolName: "rules.accept_override",
            inputJSON: try JSONEncoder.alpenLedger.encode(acceptInput),
            grantedScopes: [.rulesWrite],
            approvedBy: "reviewer",
            approvedAt: approvedAt,
            reason: "Reviewed the corrected source certificate."
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentRulesAcceptOverrideOutput.self, from: result.outputJSON)
    let updatedFact = try #require(try harness.storage.taxFactRepository.fetchTaxFact(id: fact.id))
    let resolvedProposal = try #require(try harness.storage.agentProposalRepository.fetchAgentProposal(id: proposalOutput.proposalId))
    #expect(output.fact.taxFactId == fact.id)
    #expect(output.fact.status == .overridden)
    #expect(output.fact.overrideReason == proposalInput.proposedReason)
    #expect(output.proposal?.proposalId == proposalOutput.proposalId)
    #expect(output.proposal?.status == .resolved)
    #expect(output.approvedBy == "reviewer")
    #expect(output.approvedAt == approvedAt)
    #expect(updatedFact.status == .overridden)
    #expect(updatedFact.overrideReason == proposalInput.proposedReason)
    #expect(updatedFact.moneyMinor == fact.moneyMinor)
    #expect(updatedFact.updatedAt == approvedAt)
    #expect(resolvedProposal.status == .resolved)
    #expect(resolvedProposal.decidedAt == approvedAt)
    #expect(resolvedProposal.decidedBy == "reviewer")
    #expect(resolvedProposal.decisionReason == "Reviewed the corrected source certificate.")
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .taxFact, id: fact.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .agentProposal, id: proposalOutput.proposalId.rawValue)))
    #expect(result.provenanceRefs.contains(sourceRef))

    let factEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .taxFact, id: fact.id.rawValue)
    )
    let overrideEvent = try #require(factEvents.first { $0.eventType == .taxFactOverridden })
    #expect(overrideEvent.actorType == .user)
    #expect(overrideEvent.actorId == "reviewer")
    #expect(overrideEvent.payload == proposalInput.proposedReason)
    let proposalEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .agentProposal, id: proposalOutput.proposalId.rawValue)
    )
    #expect(proposalEvents.contains { $0.eventType == .proposalResolved && $0.actorId == "reviewer" })
    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let auditPayloads = try workspaceEvents
        .filter { $0.eventType == .agentToolExecuted }
        .map(agentToolAuditPayload)
    let auditPayload = try #require(auditPayloads.first { $0.toolName == "rules.accept_override" })
    #expect(auditPayload.outcome == .executed)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.rulesWrite])
    #expect(auditPayload.confirmationProvided == true)
    #expect(auditPayload.provenanceRefs.contains(ObjectRef(kind: .taxFact, id: fact.id.rawValue)))
    #expect(auditPayload.provenanceRefs.contains(ObjectRef(kind: .agentProposal, id: proposalOutput.proposalId.rawValue)))
    #expect(auditPayload.errorCode == nil)
}

@Test
func agentToolWorkflowRejectsTaxOverrideAcceptanceWithoutConfirmation() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let fact = TaxFact(
        fingerprint: "tax.override.no-confirmation|\(taxYear.id.rawValue)",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "salary.gross",
        valueType: .money,
        moneyMinor: 12_000_000,
        currency: .chf,
        status: .observed,
        rulesetVersion: taxYear.rulesetVersion,
        provenanceRefs: [],
        confidence: 1,
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.taxFactRepository.saveTaxFact(fact)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow.addingTimeInterval(60) }
    )
    let input = AgentRulesAcceptOverrideInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        factId: fact.id,
        overrideReason: "Employer corrected the annual certificate after the original import."
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "rules.accept_override",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.rulesWrite]
            )
        )
        Issue.record("Expected tax override acceptance to require explicit confirmation.")
    } catch let error as AgentToolExecutionError {
        #expect(error == .confirmationRequired("rules.accept_override"))
    }

    let unchangedFact = try #require(try harness.storage.taxFactRepository.fetchTaxFact(id: fact.id))
    #expect(unchangedFact.status == .observed)
    #expect(unchangedFact.overrideReason == nil)
    #expect(unchangedFact.updatedAt == harness.fixedNow)
    let factEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .taxFact, id: fact.id.rawValue)
    )
    #expect(factEvents.contains { $0.eventType == .taxFactOverridden } == false)
    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(workspaceEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "rules.accept_override")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.rulesWrite])
    #expect(auditPayload.confirmationProvided == false)
    #expect(auditPayload.errorCode == "confirmationRequired")
}

@Test
func agentToolWorkflowProposesLedgerMappingWithoutMutatingTransaction() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "SBB" })
    )
    let category = TransactionCategory(
        entityId: harness.entity.id,
        code: "expense.travel.rail",
        displayName: "Rail travel",
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.categoryRepository.saveTransactionCategory(category)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentLedgerMappingProposalInput(
        transactionId: transaction.id,
        categoryId: category.id,
        taxCode: "travel",
        confidence: 0.88,
        rationale: "The counterparty is a rail operator and the memo identifies a business trip."
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "ledger.propose_mapping",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.ledgerPropose]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentLedgerMappingProposalOutput.self, from: result.outputJSON)
    let proposal = try #require(try harness.storage.agentProposalRepository.fetchAgentProposal(id: output.proposal.proposalId))
    let unchangedTransaction = try #require(
        try harness.storage.transactionRepository.fetchTransactions(ids: [transaction.id]).first
    )
    #expect(proposal.proposalType == .transactionMappingReview)
    #expect(proposal.status == .pending)
    #expect(proposal.targetRef == ObjectRef(kind: .transaction, id: transaction.id.rawValue))
    #expect(proposal.relatedRef == ObjectRef(kind: .transactionCategory, id: category.id.rawValue))
    #expect(proposal.summary == "Review mapping for SBB")
    #expect(proposal.rationale.contains("Category: expense.travel.rail"))
    #expect(proposal.rationale.contains("Tax code: travel"))
    #expect(proposal.confidence == 0.88)
    #expect(output.transaction.transactionId == transaction.id)
    #expect(output.categoryCode == "expense.travel.rail")
    #expect(output.categoryDisplayName == "Rail travel")
    #expect(output.taxCode == "travel")
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .transaction, id: transaction.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .financialAccount, id: harness.account.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .transactionCategory, id: category.id.rawValue)))
    #expect(unchangedTransaction == transaction)
    #expect(try harness.transactionService.listTransactions(accountId: harness.account.id).count == 3)

    let proposalEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)
    )
    #expect(proposalEvents.contains { $0.eventType == .proposalCreated })
}

@Test
func agentToolWorkflowRejectsLedgerMappingForForeignCategory() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "SBB" })
    )
    let business = try harness.createBusinessEntity(name: "Foreign Category Business")
    let foreignCategory = TransactionCategory(
        entityId: business.entity.id,
        code: "expense.foreign",
        displayName: "Foreign category",
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.categoryRepository.saveTransactionCategory(foreignCategory)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentLedgerMappingProposalInput(
        transactionId: transaction.id,
        categoryId: foreignCategory.id,
        taxCode: "travel",
        confidence: 0.7,
        rationale: "This should reject because the category belongs to another entity."
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "ledger.propose_mapping",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.ledgerPropose]
            )
        )
        Issue.record("Expected foreign category mapping to reject before creating a proposal.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("ledger.propose_mapping"))
    }

    let proposals = try harness.storage.agentProposalRepository.fetchAgentProposals(
        workspaceId: harness.storage.manifest.workspace.id,
        status: nil
    )
    #expect(proposals.isEmpty)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "ledger.propose_mapping")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .proposal)
    #expect(auditPayload.requiredScopes == [.ledgerPropose])
    #expect(auditPayload.errorCode == "invalidInput")
}

@Test
func agentToolWorkflowProposesLedgerSplitWithoutMutatingTransaction() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "SBB" })
    )
    let travelCategory = TransactionCategory(
        entityId: harness.entity.id,
        code: "expense.travel.rail",
        displayName: "Rail travel",
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    let clientCategory = TransactionCategory(
        entityId: harness.entity.id,
        code: "expense.client",
        displayName: "Client reimbursable",
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.categoryRepository.saveTransactionCategory(travelCategory)
    try harness.storage.categoryRepository.saveTransactionCategory(clientCategory)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentLedgerSplitProposalInput(
        transactionId: transaction.id,
        lines: [
            AgentLedgerSplitLineInput(
                amountMinor: -7_000,
                categoryId: travelCategory.id,
                taxCode: "travel",
                memo: "Train fare"
            ),
            AgentLedgerSplitLineInput(
                amountMinor: -5_000,
                categoryId: clientCategory.id,
                taxCode: "reimbursable",
                memo: "Client project share"
            ),
        ],
        confidence: 0.83,
        rationale: "The memo and amount suggest one trip should be split between internal travel and a client-reimbursable share."
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "ledger.propose_split",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.ledgerPropose]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentLedgerSplitProposalOutput.self, from: result.outputJSON)
    let proposal = try #require(try harness.storage.agentProposalRepository.fetchAgentProposal(id: output.proposal.proposalId))
    let unchangedTransaction = try #require(
        try harness.storage.transactionRepository.fetchTransactions(ids: [transaction.id]).first
    )
    #expect(proposal.proposalType == .transactionSplitReview)
    #expect(proposal.status == .pending)
    #expect(proposal.targetRef == ObjectRef(kind: .transaction, id: transaction.id.rawValue))
    #expect(proposal.relatedRef == ObjectRef(kind: .financialAccount, id: harness.account.id.rawValue))
    #expect(proposal.summary == "Review split for SBB")
    #expect(proposal.confidence == 0.83)
    #expect(proposal.rationale.contains("Proposed split lines:"))
    #expect(output.transaction.transactionId == transaction.id)
    #expect(output.splitLines.map(\.amountMinor) == [-7_000, -5_000])
    #expect(output.splitLines.map(\.categoryCode) == ["expense.travel.rail", "expense.client"])
    #expect(output.totalAmountMinor == transaction.amountMinor)
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .transaction, id: transaction.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .financialAccount, id: harness.account.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .transactionCategory, id: travelCategory.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .transactionCategory, id: clientCategory.id.rawValue)))
    #expect(unchangedTransaction == transaction)
    #expect(try harness.transactionService.listTransactions(accountId: harness.account.id).count == 3)

    let proposalEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)
    )
    #expect(proposalEvents.contains { $0.eventType == .proposalCreated })
}

@Test
func agentToolWorkflowRejectsLedgerSplitWhenLinesDoNotBalance() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "SBB" })
    )
    let category = TransactionCategory(
        entityId: harness.entity.id,
        code: "expense.travel.rail",
        displayName: "Rail travel",
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.categoryRepository.saveTransactionCategory(category)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentLedgerSplitProposalInput(
        transactionId: transaction.id,
        lines: [
            AgentLedgerSplitLineInput(amountMinor: -6_000, categoryId: category.id),
            AgentLedgerSplitLineInput(amountMinor: -5_000, categoryId: category.id),
        ],
        confidence: 0.8,
        rationale: "This should be rejected because the split total does not equal the transaction amount."
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "ledger.propose_split",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.ledgerPropose]
            )
        )
        Issue.record("Expected unbalanced split proposal to reject before creating a proposal.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("ledger.propose_split"))
    }

    let proposals = try harness.storage.agentProposalRepository.fetchAgentProposals(
        workspaceId: harness.storage.manifest.workspace.id,
        status: nil
    )
    #expect(proposals.isEmpty)
    #expect(try harness.transactionService.listTransactions(accountId: harness.account.id).count == 3)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "ledger.propose_split")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .proposal)
    #expect(auditPayload.requiredScopes == [.ledgerPropose])
    #expect(auditPayload.errorCode == "invalidInput")
}

@Test
func agentToolWorkflowProposesClosingAccrualWithoutPostingJournalEntry() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let accounts = try harness.storage.ledgerAccountRepository.fetchLedgerAccounts(entityId: harness.entity.id)
    let expenseAccount = try #require(accounts.first { $0.code == "5000" })
    let liabilityAccount = try #require(accounts.first { $0.code == "2000" })
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentClosingAccrualProposalInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        effectiveDate: date("2026-03-31T00:00:00Z"),
        currency: .chf,
        entryNumber: "YE-ACCR-001",
        memo: "Accrue outstanding March supplier invoice",
        lines: [
            AgentClosingAccrualLineInput(
                ledgerAccountId: expenseAccount.id,
                debitMinor: 12_000,
                creditMinor: 0,
                taxCode: "accrual",
                memo: "March expense"
            ),
            AgentClosingAccrualLineInput(
                ledgerAccountId: liabilityAccount.id,
                debitMinor: 0,
                creditMinor: 12_000,
                taxCode: "accrual",
                memo: "Supplier payable"
            ),
        ],
        sourceRef: documentRef,
        confidence: 0.81,
        rationale: "The receipt is dated in March but remains unpaid at the period close."
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "closing.propose_accrual",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.closingPropose]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentClosingAccrualProposalOutput.self, from: result.outputJSON)
    let proposal = try #require(try harness.storage.agentProposalRepository.fetchAgentProposal(id: output.proposal.proposalId))
    #expect(proposal.proposalType == .closingAccrualReview)
    #expect(proposal.status == .pending)
    #expect(proposal.targetRef == ObjectRef(kind: .taxYear, id: taxYear.id.rawValue))
    #expect(proposal.relatedRef == documentRef)
    #expect(proposal.summary == "Review closing accrual for 2026: Accrue outstanding March supplier invoice")
    #expect(proposal.rationale.contains("Proposed draft journal entry:"))
    #expect(proposal.rationale.contains("Account 5000 Living Expenses"))
    #expect(proposal.confidence == 0.81)
    #expect(output.draftEntry.entityId == harness.entity.id)
    #expect(output.draftEntry.taxYearId == taxYear.id)
    #expect(output.draftEntry.entryNumber == "YE-ACCR-001")
    #expect(output.draftEntry.kind == .manual)
    #expect(output.draftEntry.status == .draft)
    #expect(output.draftEntry.createdBy == "agent")
    #expect(output.draftEntry.debitTotalMinor == 12_000)
    #expect(output.draftEntry.creditTotalMinor == 12_000)
    #expect(output.draftEntry.lines.map(\.ledgerAccount.code) == ["5000", "2000"])
    #expect(output.draftEntry.lines.map(\.sourceRef) == [documentRef, documentRef])
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .legalEntity, id: harness.entity.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .taxYear, id: taxYear.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .ledgerAccount, id: expenseAccount.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .ledgerAccount, id: liabilityAccount.id.rawValue)))
    #expect(result.provenanceRefs.contains(documentRef))
    #expect(try harness.storage.ledgerAccountRepository.fetchLedgerAccounts(entityId: harness.entity.id) == accounts)

    let draftEntryEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .journalEntry, id: output.draftEntry.entryId.rawValue)
    )
    #expect(draftEntryEvents.isEmpty)
    let proposalEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)
    )
    #expect(proposalEvents.contains { $0.eventType == .proposalCreated })
}

@Test
func agentToolWorkflowRejectsClosingAccrualWhenUnbalanced() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let accounts = try harness.storage.ledgerAccountRepository.fetchLedgerAccounts(entityId: harness.entity.id)
    let expenseAccount = try #require(accounts.first { $0.code == "5000" })
    let liabilityAccount = try #require(accounts.first { $0.code == "2000" })
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentClosingAccrualProposalInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        effectiveDate: date("2026-03-31T00:00:00Z"),
        currency: .chf,
        memo: "Unbalanced closing accrual",
        lines: [
            AgentClosingAccrualLineInput(
                ledgerAccountId: expenseAccount.id,
                debitMinor: 12_000,
                creditMinor: 0
            ),
            AgentClosingAccrualLineInput(
                ledgerAccountId: liabilityAccount.id,
                debitMinor: 0,
                creditMinor: 11_000
            ),
        ],
        confidence: 0.71,
        rationale: "This should reject because proposed accrual lines do not balance."
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "closing.propose_accrual",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.closingPropose]
            )
        )
        Issue.record("Expected unbalanced accrual proposal to reject before creating a proposal.")
    } catch let error as DomainError {
        #expect(error == .unbalancedJournalEntry)
    }

    let proposals = try harness.storage.agentProposalRepository.fetchAgentProposals(
        workspaceId: harness.storage.manifest.workspace.id,
        status: nil
    )
    #expect(proposals.isEmpty)
    #expect(try harness.storage.ledgerAccountRepository.fetchLedgerAccounts(entityId: harness.entity.id) == accounts)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "closing.propose_accrual")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .proposal)
    #expect(auditPayload.requiredScopes == [.closingPropose])
    #expect(auditPayload.errorCode == "unbalancedJournalEntry")
}

@Test
func agentToolWorkflowAppliesDraftJournalEntryWithExplicitConfirmation() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let accounts = try harness.storage.ledgerAccountRepository.fetchLedgerAccounts(entityId: harness.entity.id)
    let expenseAccount = try #require(accounts.first { $0.code == "5000" })
    let liabilityAccount = try #require(accounts.first { $0.code == "2000" })
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)
    let proposalService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let proposalInput = AgentClosingAccrualProposalInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        effectiveDate: date("2026-03-31T00:00:00Z"),
        currency: .chf,
        entryNumber: "JE-ACCR-POST-001",
        memo: "Accrue approved supplier invoice",
        lines: [
            AgentClosingAccrualLineInput(
                ledgerAccountId: expenseAccount.id,
                debitMinor: 12_000,
                creditMinor: 0,
                taxCode: "accrual",
                memo: "March expense"
            ),
            AgentClosingAccrualLineInput(
                ledgerAccountId: liabilityAccount.id,
                debitMinor: 0,
                creditMinor: 12_000,
                taxCode: "accrual",
                memo: "Supplier payable"
            ),
        ],
        sourceRef: documentRef,
        confidence: 0.86,
        rationale: "The invoice was reviewed and belongs in March."
    )
    let proposalResult = try proposalService.execute(
        AgentToolInvocation(
            toolName: "closing.propose_accrual",
            inputJSON: try JSONEncoder.alpenLedger.encode(proposalInput),
            grantedScopes: [.closingPropose]
        )
    )
    let proposalOutput = try JSONDecoder.alpenLedger.decode(
        AgentClosingAccrualProposalOutput.self,
        from: proposalResult.outputJSON
    )
    let approvedAt = harness.fixedNow.addingTimeInterval(120)
    let applyService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { approvedAt }
    )
    let applyInput = AgentLedgerApplyDraftEntryInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        effectiveDate: date("2026-03-31T00:00:00Z"),
        currency: .chf,
        entryNumber: "JE-ACCR-POST-001",
        memo: "Accrue approved supplier invoice",
        lines: [
            AgentLedgerDraftEntryLineInput(
                ledgerAccountId: expenseAccount.id,
                debitMinor: 12_000,
                creditMinor: 0,
                taxCode: "accrual",
                sourceRef: documentRef,
                memo: "March expense"
            ),
            AgentLedgerDraftEntryLineInput(
                ledgerAccountId: liabilityAccount.id,
                debitMinor: 0,
                creditMinor: 12_000,
                taxCode: "accrual",
                sourceRef: documentRef,
                memo: "Supplier payable"
            ),
        ],
        proposalId: proposalOutput.proposal.proposalId
    )
    let applyInputJSON = try JSONEncoder.alpenLedger.encode(applyInput)

    let result = try applyService.execute(
        confirmedAgentToolInvocation(
            toolName: "ledger.apply_draft_entry",
            inputJSON: applyInputJSON,
            grantedScopes: [.ledgerWrite],
            approvedBy: "reviewer",
            approvedAt: approvedAt,
            reason: "Reviewed the balanced accrual and source receipt."
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentLedgerApplyDraftEntryOutput.self, from: result.outputJSON)
    let postedEntry = try #require(
        try harness.storage.journalEntryRepository.fetchJournalEntry(id: output.journalEntry.journalEntryId)
    )
    #expect(output.journalEntry.status == .posted)
    #expect(output.journalEntry.entryNumber == "JE-ACCR-POST-001")
    #expect(output.journalEntry.approvedBy == "reviewer")
    #expect(output.journalEntry.approvedAt == approvedAt)
    #expect(output.journalEntry.debitTotalMinor == 12_000)
    #expect(output.journalEntry.creditTotalMinor == 12_000)
    #expect(output.journalEntry.lines.map(\.ledgerAccount.code) == ["5000", "2000"])
    #expect(output.journalEntry.lines.map(\.sourceRef) == [documentRef, documentRef])
    #expect(postedEntry.status == .posted)
    #expect(postedEntry.approvedBy == "reviewer")
    #expect(postedEntry.approvedAt == approvedAt)
    #expect(postedEntry.lines.count == 2)
    #expect(try harness.storage.journalEntryRepository.fetchJournalEntries(
        entityId: harness.entity.id,
        taxYearId: taxYear.id
    ).count == 1)

    let resolvedProposal = try #require(
        try harness.storage.agentProposalRepository.fetchAgentProposal(id: proposalOutput.proposal.proposalId)
    )
    #expect(resolvedProposal.status == .resolved)
    #expect(resolvedProposal.decidedBy == "reviewer")
    #expect(resolvedProposal.decidedAt == approvedAt)
    #expect(resolvedProposal.decisionReason == "Reviewed the balanced accrual and source receipt.")
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .journalEntry, id: postedEntry.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .agentProposal, id: resolvedProposal.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .ledgerAccount, id: expenseAccount.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .ledgerAccount, id: liabilityAccount.id.rawValue)))
    #expect(result.provenanceRefs.contains(documentRef))

    let entryEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .journalEntry, id: postedEntry.id.rawValue)
    )
    let postedEvent = try #require(entryEvents.first { $0.eventType == .journalEntryPosted })
    #expect(postedEvent.actorType == .user)
    #expect(postedEvent.actorId == "reviewer")
    #expect(postedEvent.payload == "Reviewed the balanced accrual and source receipt.")
    let proposalEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .agentProposal, id: resolvedProposal.id.rawValue)
    )
    #expect(proposalEvents.contains { $0.eventType == .proposalResolved })
    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let auditPayloads = try workspaceEvents
        .filter { $0.eventType == .agentToolExecuted }
        .map(agentToolAuditPayload)
    let auditPayload = try #require(auditPayloads.first { $0.toolName == "ledger.apply_draft_entry" })
    #expect(auditPayload.outcome == .executed)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.ledgerWrite])
    #expect(auditPayload.confirmationProvided == true)
    #expect(auditPayload.inputHash == AgentToolInputHash.hash(applyInputJSON))
    #expect(auditPayload.confirmationInputHash == AgentToolInputHash.hash(applyInputJSON))
    #expect(auditPayload.provenanceRefs.contains(ObjectRef(kind: .journalEntry, id: postedEntry.id.rawValue)))
    #expect(auditPayload.errorCode == nil)
}

@Test
func agentToolWorkflowRejectsDraftJournalEntryWithoutConfirmation() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let accounts = try harness.storage.ledgerAccountRepository.fetchLedgerAccounts(entityId: harness.entity.id)
    let expenseAccount = try #require(accounts.first { $0.code == "5000" })
    let liabilityAccount = try #require(accounts.first { $0.code == "2000" })
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentLedgerApplyDraftEntryInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        effectiveDate: date("2026-03-31T00:00:00Z"),
        currency: .chf,
        entryNumber: "JE-NO-APPROVAL",
        memo: "Unapproved entry",
        lines: [
            AgentLedgerDraftEntryLineInput(
                ledgerAccountId: expenseAccount.id,
                debitMinor: 5_000,
                creditMinor: 0
            ),
            AgentLedgerDraftEntryLineInput(
                ledgerAccountId: liabilityAccount.id,
                debitMinor: 0,
                creditMinor: 5_000
            ),
        ]
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "ledger.apply_draft_entry",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.ledgerWrite]
            )
        )
        Issue.record("Expected draft journal entry application to require explicit confirmation.")
    } catch let error as AgentToolExecutionError {
        #expect(error == .confirmationRequired("ledger.apply_draft_entry"))
    }

    #expect(try harness.storage.journalEntryRepository.fetchJournalEntries(
        entityId: harness.entity.id,
        taxYearId: taxYear.id
    ).isEmpty)
    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(workspaceEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "ledger.apply_draft_entry")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.ledgerWrite])
    #expect(auditPayload.confirmationProvided == false)
    #expect(auditPayload.errorCode == "confirmationRequired")
}

@Test
func agentToolWorkflowRejectsDraftJournalEntryForLockedTaxYear() throws {
    let harness = try EvidenceHarness()
    var taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    taxYear.status = .locked
    try harness.storage.taxYearRepository.saveTaxYear(taxYear)
    let accounts = try harness.storage.ledgerAccountRepository.fetchLedgerAccounts(entityId: harness.entity.id)
    let expenseAccount = try #require(accounts.first { $0.code == "5000" })
    let liabilityAccount = try #require(accounts.first { $0.code == "2000" })
    let approvedAt = harness.fixedNow.addingTimeInterval(120)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { approvedAt }
    )
    let input = AgentLedgerApplyDraftEntryInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        effectiveDate: date("2026-03-31T00:00:00Z"),
        currency: .chf,
        entryNumber: "JE-LOCKED",
        memo: "Locked-period entry",
        lines: [
            AgentLedgerDraftEntryLineInput(
                ledgerAccountId: expenseAccount.id,
                debitMinor: 5_000,
                creditMinor: 0
            ),
            AgentLedgerDraftEntryLineInput(
                ledgerAccountId: liabilityAccount.id,
                debitMinor: 0,
                creditMinor: 5_000
            ),
        ]
    )

    do {
        _ = try agentToolService.execute(
            confirmedAgentToolInvocation(
                toolName: "ledger.apply_draft_entry",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.ledgerWrite],
                approvedBy: "reviewer",
                approvedAt: approvedAt,
                reason: "Attempted approval should be blocked by period lock."
            )
        )
        Issue.record("Expected locked tax year to reject draft journal entry application.")
    } catch let error as DomainError {
        #expect(error == .lockedPeriod)
    }

    #expect(try harness.storage.journalEntryRepository.fetchJournalEntries(
        entityId: harness.entity.id,
        taxYearId: taxYear.id
    ).isEmpty)
    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(workspaceEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "ledger.apply_draft_entry")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.ledgerWrite])
    #expect(auditPayload.confirmationProvided == true)
    #expect(auditPayload.errorCode == "lockedPeriod")
}

@Test
func statementImportCreatesCounterpartiesForTransactions() throws {
    let harness = try EvidenceHarness()

    try harness.importFixtureStatement()

    let transactions = try harness.transactionService.listTransactions(accountId: harness.account.id)
    #expect(transactions.isEmpty == false)
    #expect(transactions.allSatisfy { $0.counterpartyId != nil })

    let counterparties = try harness.storage.counterpartyRepository.fetchCounterparties(
        entityId: harness.entity.id,
        includeMerged: false
    )
    #expect(counterparties.map(\.displayName).contains("Coffee Bar Zurich"))
    #expect(counterparties.allSatisfy { $0.status == .active })
}

@Test
func agentToolWorkflowMergesCounterpartiesWithExplicitConfirmation() throws {
    let harness = try EvidenceHarness()
    let sourceTransaction = Transaction(
        accountId: harness.account.id,
        originKind: .manual,
        sourceLineRef: "counterparty-merge-source",
        bookingDate: date("2026-03-03T00:00:00Z"),
        amountMinor: -4_200,
        currency: .chf,
        counterpartyName: "Acme AG",
        memo: "Original vendor spelling"
    )
    let targetTransaction = Transaction(
        accountId: harness.account.id,
        originKind: .manual,
        sourceLineRef: "counterparty-merge-target",
        bookingDate: date("2026-03-04T00:00:00Z"),
        amountMinor: -8_400,
        currency: .chf,
        counterpartyName: "ACME Schweiz AG",
        memo: "Canonical vendor"
    )
    try harness.storage.transactionRepository.saveTransactions([sourceTransaction, targetTransaction])
    let counterparties = try harness.storage.counterpartyRepository.fetchCounterparties(
        entityId: harness.entity.id,
        includeMerged: true
    )
    let source = try #require(counterparties.first { $0.displayName == "Acme AG" })
    let target = try #require(counterparties.first { $0.displayName == "ACME Schweiz AG" })
    let approvedAt = harness.fixedNow.addingTimeInterval(300)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { approvedAt }
    )
    let input = AgentCounterpartyMergeInput(
        entityId: harness.entity.id,
        sourceCounterpartyId: source.id,
        targetCounterpartyId: target.id
    )

    let result = try agentToolService.execute(
        confirmedAgentToolInvocation(
            toolName: "entities.merge_counterparties",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.entityWrite],
            approvedBy: "reviewer",
            approvedAt: approvedAt,
            reason: "Reviewed duplicate vendor identities and kept imported transaction text unchanged."
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentCounterpartyMergeOutput.self, from: result.outputJSON)
    #expect(output.source.status == .merged)
    #expect(output.source.mergedIntoCounterpartyId == target.id)
    #expect(output.target.status == .active)
    #expect(output.linkedTransactionCount == 1)

    let mergedSource = try #require(try harness.storage.counterpartyRepository.fetchCounterparty(id: source.id))
    #expect(mergedSource.status == .merged)
    #expect(mergedSource.mergedIntoCounterpartyId == target.id)
    let sourceLinkedTransactions = try harness.storage.transactionRepository.fetchTransactions(counterpartyId: source.id)
    #expect(sourceLinkedTransactions.map(\.counterpartyName) == ["Acme AG"])
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .counterparty, id: source.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .counterparty, id: target.id.rawValue)))

    let counterpartyEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .counterparty, id: source.id.rawValue)
    )
    let mergeEvent = try #require(counterpartyEvents.first { $0.eventType == .counterpartyMerged })
    #expect(mergeEvent.actorType == .user)
    #expect(mergeEvent.actorId == "reviewer")
    #expect(mergeEvent.payload == "Reviewed duplicate vendor identities and kept imported transaction text unchanged.")

    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let auditPayloads = try workspaceEvents
        .filter { $0.eventType == .agentToolExecuted }
        .map(agentToolAuditPayload)
    let auditPayload = try #require(auditPayloads.first { $0.toolName == "entities.merge_counterparties" })
    #expect(auditPayload.outcome == .executed)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.entityWrite])
    #expect(auditPayload.confirmationProvided == true)
    #expect(auditPayload.provenanceRefs.contains(ObjectRef(kind: .counterparty, id: source.id.rawValue)))
}

@Test
func agentToolWorkflowRejectsCounterpartyMergeWithoutConfirmation() throws {
    let harness = try EvidenceHarness()
    let sourceTransaction = Transaction(
        accountId: harness.account.id,
        originKind: .manual,
        sourceLineRef: "counterparty-merge-reject-source",
        bookingDate: date("2026-03-03T00:00:00Z"),
        amountMinor: -4_200,
        currency: .chf,
        counterpartyName: "Reject Source AG",
        memo: "Source"
    )
    let targetTransaction = Transaction(
        accountId: harness.account.id,
        originKind: .manual,
        sourceLineRef: "counterparty-merge-reject-target",
        bookingDate: date("2026-03-04T00:00:00Z"),
        amountMinor: -8_400,
        currency: .chf,
        counterpartyName: "Reject Target AG",
        memo: "Target"
    )
    try harness.storage.transactionRepository.saveTransactions([sourceTransaction, targetTransaction])
    let counterparties = try harness.storage.counterpartyRepository.fetchCounterparties(
        entityId: harness.entity.id,
        includeMerged: true
    )
    let source = try #require(counterparties.first { $0.displayName == "Reject Source AG" })
    let target = try #require(counterparties.first { $0.displayName == "Reject Target AG" })
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentCounterpartyMergeInput(
        entityId: harness.entity.id,
        sourceCounterpartyId: source.id,
        targetCounterpartyId: target.id
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "entities.merge_counterparties",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.entityWrite]
            )
        )
        Issue.record("Expected counterparty merge to require explicit confirmation.")
    } catch let error as AgentToolExecutionError {
        #expect(error == .confirmationRequired("entities.merge_counterparties"))
    }

    let unchangedSource = try #require(try harness.storage.counterpartyRepository.fetchCounterparty(id: source.id))
    #expect(unchangedSource.status == .active)
    #expect(unchangedSource.mergedIntoCounterpartyId == nil)

    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(workspaceEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "entities.merge_counterparties")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.entityWrite])
    #expect(auditPayload.confirmationProvided == false)
    #expect(auditPayload.errorCode == "confirmationRequired")
}

@Test
func agentToolWorkflowGeneratesExportPackageDraftArtifact() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let vatPeriod = VATPeriod(
        entityId: harness.entity.id,
        periodStart: date("2026-04-01T00:00:00Z"),
        periodEnd: date("2026-06-30T00:00:00Z"),
        currency: .chf,
        status: .open
    )
    try harness.storage.vatPeriodRepository.saveVATPeriod(vatPeriod)
    let warningRef = ObjectRef(kind: .vatPeriod, id: vatPeriod.id.rawValue)
    let artifactData = Data("<eCH-0217:VATDeclaration />".utf8)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        exportPackageProvider: { input in
            #expect(input.exportFormat == "eCH-0217")
            #expect(input.vatPeriodId == vatPeriod.id)
            return AgentExportPackageProviderResult(
                schemaVersion: "2.0.0",
                artifactFilename: "AL-VAT-2026-Q2.xml",
                mediaType: "application/xml",
                artifactData: artifactData,
                issues: [
                    AgentExportValidationIssueToolOutput(
                        severity: .warning,
                        code: "vat_export.reviewed_warning",
                        message: "Synthetic reviewed warning.",
                        sourceRef: warningRef
                    ),
                ],
                sourceRefs: [warningRef]
            )
        },
        nowProvider: { harness.fixedNow }
    )
    let input = AgentExportGeneratePackageInput(
        exportFormat: "eCH-0217",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        vatPeriodId: vatPeriod.id,
        uid: "CHE-123.456.789 MWST",
        organisationName: "AlpenLedger Synthetic VAT AG",
        generationTime: harness.fixedNow,
        businessReferenceId: "AL-VAT-2026-Q2",
        applicationProductVersion: "0.1.0",
        typeOfSubmission: 1,
        formOfReporting: 1
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "exports.generate_package",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.exportsGenerate]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentExportPackageToolOutput.self, from: result.outputJSON)
    let filingPackage = try #require(
        try harness.storage.filingPackageRepository.fetchFilingPackage(id: output.filingPackageId)
    )
    #expect(output.exportFormat == "eCH-0217")
    #expect(output.schemaVersion == "2.0.0")
    #expect(output.entityId == harness.entity.id)
    #expect(output.taxYearId == taxYear.id)
    #expect(output.vatPeriodId == vatPeriod.id)
    #expect(output.status == FilingPackageStatus.generated)
    #expect(output.generatedAt == harness.fixedNow)
    #expect(output.artifactByteCount == artifactData.count)
    #expect(output.artifactFilename == "AL-VAT-2026-Q2.xml")
    #expect(output.mediaType == "application/xml")
    #expect(output.blockerCount == 0)
    #expect(output.warningCount == 1)
    #expect(filingPackage.status == FilingPackageStatus.generated)
    #expect(filingPackage.generatedAt == harness.fixedNow)
    #expect(filingPackage.submittedAt == nil)
    #expect(filingPackage.snapshotHash == output.artifactHash)
    #expect(try harness.storage.blobStore.read(hash: output.artifactHash) == artifactData)
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .filingPackage, id: filingPackage.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .legalEntity, id: harness.entity.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .taxYear, id: taxYear.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .vatPeriod, id: vatPeriod.id.rawValue)))
    #expect(result.provenanceRefs.contains(warningRef))

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let executedEvent = try #require(auditEvents.first { $0.eventType == .agentToolExecuted })
    let auditPayload = try agentToolAuditPayload(from: executedEvent)
    #expect(auditPayload.toolName == "exports.generate_package")
    #expect(auditPayload.outcome == .executed)
    #expect(auditPayload.sideEffect == .draftArtifact)
    #expect(auditPayload.requiredScopes == [.exportsGenerate])
    #expect(auditPayload.errorCode == nil)
}

@Test
func agentToolWorkflowRejectsExportPackageGenerationForMissingVATPeriod() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let missingVATPeriodId = VATPeriodID()
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        exportPackageProvider: { _ in
            Issue.record("Package provider should not run for a missing VAT period.")
            return AgentExportPackageProviderResult(
                artifactFilename: "unexpected.xml",
                mediaType: "application/xml",
                artifactData: Data("<unexpected />".utf8),
                issues: [],
                sourceRefs: []
            )
        },
        nowProvider: { harness.fixedNow }
    )
    let input = AgentExportGeneratePackageInput(
        exportFormat: "eCH-0217",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        vatPeriodId: missingVATPeriodId,
        uid: "CHE-123.456.789 MWST",
        organisationName: "AlpenLedger Synthetic VAT AG",
        generationTime: harness.fixedNow,
        businessReferenceId: "AL-VAT-2026-Q2",
        applicationProductVersion: "0.1.0",
        typeOfSubmission: 1,
        formOfReporting: 1
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "exports.generate_package",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.exportsGenerate]
            )
        )
        Issue.record("Expected export package generation to reject a missing VAT period.")
    } catch let error as DomainError {
        #expect(error == .vatPeriodNotFound)
    }

    #expect(try harness.storage.filingPackageRepository.fetchFilingPackages(entityId: harness.entity.id).isEmpty)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "exports.generate_package")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .draftArtifact)
    #expect(auditPayload.requiredScopes == [.exportsGenerate])
    #expect(auditPayload.errorCode == "vatPeriodNotFound")
}

@Test
func agentToolWorkflowFinalizesExportPackageWithExplicitConfirmation() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let artifactHash = try harness.storage.blobStore.store(data: Data("<vat-export/>".utf8))
    let filingPackage = FilingPackage(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        status: .generated,
        generatedAt: harness.fixedNow,
        snapshotHash: artifactHash,
        exportFormat: "eCH-0217",
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.filingPackageRepository.saveFilingPackage(filingPackage)
    let approvedAt = harness.fixedNow.addingTimeInterval(60)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { approvedAt }
    )
    let input = AgentExportFinalizePackageInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        filingPackageId: filingPackage.id,
        expectedSnapshotHash: artifactHash
    )

    let result = try agentToolService.execute(
        confirmedAgentToolInvocation(
            toolName: "exports.finalize_package",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.exportsGenerate],
            approvedBy: "reviewer",
            approvedAt: approvedAt,
            reason: "Reviewed generated XML and validation evidence."
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentExportFinalizePackageOutput.self, from: result.outputJSON)
    let finalizedPackage = try #require(try harness.storage.filingPackageRepository.fetchFilingPackage(id: filingPackage.id))
    #expect(output.filingPackageId == filingPackage.id)
    #expect(output.status == .finalized)
    #expect(output.finalizedAt == approvedAt)
    #expect(output.finalizedBy == "reviewer")
    #expect(output.submittedAt == nil)
    #expect(output.snapshotHash == artifactHash)
    #expect(finalizedPackage.status == .finalized)
    #expect(finalizedPackage.finalizedAt == approvedAt)
    #expect(finalizedPackage.finalizedBy == "reviewer")
    #expect(finalizedPackage.submittedAt == nil)
    #expect(finalizedPackage.snapshotHash == artifactHash)
    #expect(finalizedPackage.updatedAt == approvedAt)
    #expect(try harness.storage.blobStore.read(hash: artifactHash) == Data("<vat-export/>".utf8))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .filingPackage, id: filingPackage.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .legalEntity, id: harness.entity.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .taxYear, id: taxYear.id.rawValue)))

    let packageEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .filingPackage, id: filingPackage.id.rawValue)
    )
    let finalizedEvent = try #require(packageEvents.first { $0.eventType == .filingPackageFinalized })
    #expect(finalizedEvent.actorType == .user)
    #expect(finalizedEvent.actorId == "reviewer")
    #expect(finalizedEvent.payload == "Reviewed generated XML and validation evidence.")
    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let auditPayloads = try workspaceEvents
        .filter { $0.eventType == .agentToolExecuted }
        .map(agentToolAuditPayload)
    let auditPayload = try #require(auditPayloads.first { $0.toolName == "exports.finalize_package" })
    #expect(auditPayload.outcome == .executed)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.exportsGenerate])
    #expect(auditPayload.confirmationProvided == true)
    #expect(auditPayload.provenanceRefs.contains(ObjectRef(kind: .filingPackage, id: filingPackage.id.rawValue)))
    #expect(auditPayload.errorCode == nil)
}

@Test
func agentToolWorkflowRejectsExportFinalizationWithoutConfirmation() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let artifactHash = try harness.storage.blobStore.store(data: Data("<vat-export/>".utf8))
    let filingPackage = FilingPackage(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        status: .generated,
        generatedAt: harness.fixedNow,
        snapshotHash: artifactHash,
        exportFormat: "eCH-0217",
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.filingPackageRepository.saveFilingPackage(filingPackage)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow.addingTimeInterval(60) }
    )
    let input = AgentExportFinalizePackageInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        filingPackageId: filingPackage.id,
        expectedSnapshotHash: artifactHash
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "exports.finalize_package",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.exportsGenerate]
            )
        )
        Issue.record("Expected export finalization to require explicit confirmation.")
    } catch let error as AgentToolExecutionError {
        #expect(error == .confirmationRequired("exports.finalize_package"))
    }

    let unchangedPackage = try #require(try harness.storage.filingPackageRepository.fetchFilingPackage(id: filingPackage.id))
    #expect(unchangedPackage.status == .generated)
    #expect(unchangedPackage.finalizedAt == nil)
    #expect(unchangedPackage.finalizedBy == nil)
    #expect(unchangedPackage.submittedAt == nil)
    let packageEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .filingPackage, id: filingPackage.id.rawValue)
    )
    #expect(packageEvents.contains { $0.eventType == .filingPackageFinalized } == false)
    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(workspaceEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "exports.finalize_package")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.exportsGenerate])
    #expect(auditPayload.confirmationProvided == false)
    #expect(auditPayload.errorCode == "confirmationRequired")
}

@Test
func agentToolWorkflowRejectsExportFinalizationForSnapshotMismatch() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let artifactHash = try harness.storage.blobStore.store(data: Data("<vat-export/>".utf8))
    let filingPackage = FilingPackage(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        status: .generated,
        generatedAt: harness.fixedNow,
        snapshotHash: artifactHash,
        exportFormat: "eCH-0217",
        createdAt: harness.fixedNow,
        updatedAt: harness.fixedNow
    )
    try harness.storage.filingPackageRepository.saveFilingPackage(filingPackage)
    let approvedAt = harness.fixedNow.addingTimeInterval(60)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { approvedAt }
    )
    let input = AgentExportFinalizePackageInput(
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        filingPackageId: filingPackage.id,
        expectedSnapshotHash: String(repeating: "0", count: 64)
    )

    do {
        _ = try agentToolService.execute(
            confirmedAgentToolInvocation(
                toolName: "exports.finalize_package",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.exportsGenerate],
                approvedBy: "reviewer",
                approvedAt: approvedAt,
                reason: "Reviewed generated XML and validation evidence."
            )
        )
        Issue.record("Expected export finalization to reject a stale snapshot hash.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("exports.finalize_package"))
    }

    let unchangedPackage = try #require(try harness.storage.filingPackageRepository.fetchFilingPackage(id: filingPackage.id))
    #expect(unchangedPackage.status == .generated)
    #expect(unchangedPackage.finalizedAt == nil)
    #expect(unchangedPackage.finalizedBy == nil)
    #expect(unchangedPackage.submittedAt == nil)
    let workspaceEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(workspaceEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "exports.finalize_package")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .confirmedWrite)
    #expect(auditPayload.requiredScopes == [.exportsGenerate])
    #expect(auditPayload.confirmationProvided == true)
    #expect(auditPayload.errorCode == "invalidInput")
}

@Test
func agentToolWorkflowValidatesExportThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let vatPeriod = VATPeriod(
        entityId: harness.entity.id,
        periodStart: date("2026-04-01T00:00:00Z"),
        periodEnd: date("2026-06-30T23:59:59Z"),
        currency: .chf
    )
    try harness.storage.vatPeriodRepository.saveVATPeriod(vatPeriod)
    let warningRef = ObjectRef(kind: .transaction, id: UUID())
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        exportValidationProvider: { input in
            AgentExportValidationProviderResult(
                schemaVersion: "2.0.0",
                issues: [
                    AgentExportValidationIssueToolOutput(
                        severity: .warning,
                        code: "vat_export.fixture_warning",
                        message: "Synthetic validation warning.",
                        sourceRef: warningRef
                    ),
                ]
            )
        },
        nowProvider: { harness.fixedNow }
    )
    let input = AgentExportValidateInput(
        exportFormat: "eCH-0217",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        vatPeriodId: vatPeriod.id,
        uid: "CHE-123.456.789 MWST",
        organisationName: "AlpenLedger Synthetic VAT AG",
        generationTime: harness.fixedNow,
        businessReferenceId: "AL-VAT-2026-Q2",
        applicationProductVersion: "0.1.0",
        typeOfSubmission: 1,
        formOfReporting: 1
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "exports.validate",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.exportsGenerate]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentExportValidationToolOutput.self, from: result.outputJSON)
    #expect(output.exportFormat == "eCH-0217")
    #expect(output.schemaVersion == "2.0.0")
    #expect(output.entityId == harness.entity.id)
    #expect(output.taxYearId == taxYear.id)
    #expect(output.vatPeriodId == vatPeriod.id)
    #expect(output.blockerCount == 0)
    #expect(output.warningCount == 1)
    #expect(output.issues.map(\.code) == ["vat_export.fixture_warning"])
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .legalEntity, id: harness.entity.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .taxYear, id: taxYear.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .vatPeriod, id: vatPeriod.id.rawValue)))
    #expect(result.provenanceRefs.contains(warningRef))
    #expect(try harness.storage.filingPackageRepository.fetchFilingPackages(entityId: harness.entity.id).isEmpty)

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let executedEvent = try #require(auditEvents.first { $0.eventType == .agentToolExecuted })
    let auditPayload = try agentToolAuditPayload(from: executedEvent)
    #expect(auditPayload.toolName == "exports.validate")
    #expect(auditPayload.outcome == .executed)
    #expect(auditPayload.sideEffect == .readOnly)
    #expect(auditPayload.requiredScopes == [.exportsGenerate])
    #expect(auditPayload.errorCode == nil)
}

@Test
func agentToolWorkflowRejectsExportValidationForMissingVATPeriod() throws {
    let harness = try EvidenceHarness()
    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let missingVATPeriodId = VATPeriodID()
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        exportValidationProvider: { _ in
            AgentExportValidationProviderResult(schemaVersion: "2.0.0", issues: [])
        },
        nowProvider: { harness.fixedNow }
    )
    let input = AgentExportValidateInput(
        exportFormat: "eCH-0217",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        vatPeriodId: missingVATPeriodId,
        uid: "CHE-123.456.789 MWST",
        organisationName: "AlpenLedger Synthetic VAT AG",
        generationTime: harness.fixedNow,
        businessReferenceId: "AL-VAT-2026-Q2",
        applicationProductVersion: "0.1.0",
        typeOfSubmission: 1,
        formOfReporting: 1
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "exports.validate",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.exportsGenerate]
            )
        )
        Issue.record("Expected export validation to reject a missing VAT period.")
    } catch let error as DomainError {
        #expect(error == .vatPeriodNotFound)
    }

    #expect(try harness.storage.filingPackageRepository.fetchFilingPackages(entityId: harness.entity.id).isEmpty)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "exports.validate")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .readOnly)
    #expect(auditPayload.requiredScopes == [.exportsGenerate])
    #expect(auditPayload.errorCode == "vatPeriodNotFound")
}

@Test
func agentToolWorkflowTracesAuditObjectThroughExecutorWithProvenance() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "Coffee Bar Zurich" })
    )
    let targetRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
    let olderEvent = AuditEvent(
        workspaceId: harness.storage.manifest.workspace.id,
        actorType: .system,
        actorId: "system",
        eventType: .statementImported,
        objectRef: targetRef,
        payload: "Initial transaction import",
        occurredAt: harness.fixedNow
    )
    let newerEvent = AuditEvent(
        workspaceId: harness.storage.manifest.workspace.id,
        actorType: .user,
        actorId: "reviewer",
        eventType: .evidenceLinked,
        objectRef: targetRef,
        payload: String(repeating: "Reviewed evidence. ", count: 20),
        occurredAt: harness.fixedNow.addingTimeInterval(60)
    )
    try harness.storage.auditEventRepository.saveAuditEvent(olderEvent)
    try harness.storage.auditEventRepository.saveAuditEvent(newerEvent)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow.addingTimeInterval(120) }
    )
    let input = AgentAuditTraceInput(objectRef: targetRef, entityId: harness.entity.id, limit: 1)

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "audit.trace_object",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.auditRead]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentAuditTraceToolOutput.self, from: result.outputJSON)
    #expect(output.targetRef == targetRef)
    #expect(output.eventCount == 2)
    #expect(output.hasMore == true)
    #expect(output.events.count == 1)
    #expect(output.events.first?.eventId == newerEvent.id)
    #expect(output.events.first?.eventType == .evidenceLinked)
    #expect(output.events.first?.actorType == .user)
    #expect(output.events.first?.actorId == "reviewer")
    #expect(output.events.first?.payloadPreview?.hasSuffix("...") == true)
    #expect(result.provenanceRefs.contains(targetRef))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .auditEvent, id: newerEvent.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .auditEvent, id: olderEvent.id.rawValue)) == false)

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let executedEvent = try #require(auditEvents.first { $0.eventType == .agentToolExecuted })
    let auditPayload = try agentToolAuditPayload(from: executedEvent)
    #expect(auditPayload.toolName == "audit.trace_object")
    #expect(auditPayload.outcome == .executed)
    #expect(auditPayload.sideEffect == .readOnly)
    #expect(auditPayload.requiredScopes == [.auditRead])
    #expect(auditPayload.provenanceRefs.contains(targetRef))
    #expect(auditPayload.errorCode == nil)
}

@Test
func agentToolWorkflowRejectsAuditTraceOutsideEntityScope() throws {
    let harness = try EvidenceHarness()
    let business = try harness.createBusinessEntity(name: "Audit Scope Business")
    let transaction = Transaction(
        accountId: business.account.id,
        originKind: .manual,
        sourceLineRef: "audit-scope-business",
        bookingDate: date("2026-03-05T00:00:00Z"),
        amountMinor: -21_500,
        currency: .chf,
        counterpartyName: "Scoped Supplier",
        memo: "Business-only service"
    )
    try harness.storage.transactionRepository.saveTransactions([transaction])
    let targetRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
    let scopedEvent = AuditEvent(
        workspaceId: harness.storage.manifest.workspace.id,
        actorType: .user,
        actorId: "business-reviewer",
        eventType: .statementImported,
        objectRef: targetRef,
        payload: "Business-only audit payload",
        occurredAt: harness.fixedNow
    )
    try harness.storage.auditEventRepository.saveAuditEvent(scopedEvent)
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow.addingTimeInterval(60) }
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "audit.trace_object",
                inputJSON: try JSONEncoder.alpenLedger.encode(
                    AgentAuditTraceInput(objectRef: targetRef, entityId: harness.entity.id, limit: 10)
                ),
                grantedScopes: [.auditRead]
            )
        )
        Issue.record("Expected audit trace to reject a target from another entity.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("audit.trace_object"))
    }

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "audit.trace_object",
                inputJSON: try JSONEncoder.alpenLedger.encode(
                    AgentAuditTraceInput(objectRef: targetRef, limit: 10)
                ),
                grantedScopes: [.auditRead]
            )
        )
        Issue.record("Expected audit trace to reject entity-owned targets without entity scope.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("audit.trace_object"))
    }

    let scopedResult = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "audit.trace_object",
            inputJSON: try JSONEncoder.alpenLedger.encode(
                AgentAuditTraceInput(objectRef: targetRef, entityId: business.entity.id, limit: 10)
            ),
            grantedScopes: [.auditRead]
        )
    )
    let scopedOutput = try JSONDecoder.alpenLedger.decode(
        AgentAuditTraceToolOutput.self,
        from: scopedResult.outputJSON
    )
    #expect(scopedOutput.targetRef == targetRef)
    #expect(scopedOutput.eventCount == 1)
    #expect(scopedOutput.events.first?.eventId == scopedEvent.id)
    #expect(scopedOutput.events.first?.payloadPreview == "Business-only audit payload")
}

@Test
func agentToolWorkflowRejectsAuditTraceWithInvalidLimit() throws {
    let harness = try EvidenceHarness()
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentAuditTraceInput(
        objectRef: ObjectRef(kind: .legalEntity, id: harness.entity.id.rawValue),
        limit: 0
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "audit.trace_object",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.auditRead]
            )
        )
        Issue.record("Expected audit trace to reject an invalid limit.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("audit.trace_object"))
    }

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "audit.trace_object")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.sideEffect == .readOnly)
    #expect(auditPayload.requiredScopes == [.auditRead])
    #expect(auditPayload.errorCode == "invalidInput")
}

@Test
func agentToolWorkflowCreatesDocumentMatchProposalThroughExecutor() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "Coffee Bar Zurich" })
    )
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentDocumentMatchProposalInput(
        documentId: document.id,
        transactionId: transaction.id,
        confidence: 0.91,
        rationale: "The receipt counterparty and amount match the imported card transaction."
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "docs.propose_match",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.docsPropose]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentProposalToolOutput.self, from: result.outputJSON)
    let proposal = try #require(try harness.storage.agentProposalRepository.fetchAgentProposal(id: output.proposalId))
    #expect(proposal.status == .pending)
    #expect(proposal.targetRef == ObjectRef(kind: .document, id: document.id.rawValue))
    #expect(proposal.relatedRef == ObjectRef(kind: .transaction, id: transaction.id.rawValue))
    #expect(output.relatedRef == ObjectRef(kind: .transaction, id: transaction.id.rawValue))
    #expect(proposal.rationale == input.rationale)
    #expect(output.rationale == input.rationale)
    #expect(proposal.confidence == 0.91)
    #expect(proposal.missingFields == [])
    #expect(proposal.question == nil)
    #expect(proposal.requiresManualReview == false)
    #expect(output.missingFields == [])
    #expect(output.question == nil)
    #expect(output.requiresManualReview == false)
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .document, id: document.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .transaction, id: transaction.id.rawValue)))
    #expect(try harness.storage.evidenceLinkRepository.fetchEvidenceLinks(
        for: ObjectRef(kind: .document, id: document.id.rawValue)
    ).isEmpty)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)
    )
    #expect(auditEvents.contains { $0.eventType == .proposalCreated })
}

@Test
func agentToolWorkflowRejectsCrossEntityDocumentMatchProposal() throws {
    let harness = try EvidenceHarness()
    let business = try harness.createBusinessEntity(name: "Document Match Business")
    try harness.importFixtureStatement()
    let document = try harness.documentService.importDocument(
        from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"),
        entityId: business.entity.id
    )
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "Coffee Bar Zurich" })
    )
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentDocumentMatchProposalInput(
        documentId: document.id,
        transactionId: transaction.id,
        confidence: 0.91,
        rationale: "The receipt counterparty and amount match the imported card transaction."
    )

    do {
        _ = try agentToolService.execute(
            AgentToolInvocation(
                toolName: "docs.propose_match",
                inputJSON: try JSONEncoder.alpenLedger.encode(input),
                grantedScopes: [.docsPropose]
            )
        )
        Issue.record("Expected cross-entity document match proposal to be rejected.")
    } catch let error as WorkspaceAgentToolError {
        #expect(error == .invalidInput("docs.propose_match"))
    }

    let fingerprint = "docs.propose_match|\(document.id)|\(transaction.id)"
    #expect(try harness.storage.agentProposalRepository.fetchAgentProposal(fingerprint: fingerprint) == nil)
    #expect(try harness.storage.evidenceLinkRepository.fetchEvidenceLinks(
        for: ObjectRef(kind: .document, id: document.id.rawValue)
    ).isEmpty)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue)
    )
    let rejectedEvent = try #require(auditEvents.first { $0.eventType == .agentToolRejected })
    let auditPayload = try agentToolAuditPayload(from: rejectedEvent)
    #expect(auditPayload.toolName == "docs.propose_match")
    #expect(auditPayload.outcome == .rejected)
    #expect(auditPayload.errorCode == "invalidInput")
}

@Test
func agentToolWorkflowLowConfidenceDocumentMatchEscalatesWithQuestion() throws {
    let harness = try EvidenceHarness()
    try harness.importFixtureStatement()
    let document = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"))
    let transaction = try #require(
        harness.transactionService
            .listTransactions(accountId: harness.account.id)
            .first(where: { $0.counterpartyName == "Coffee Bar Zurich" })
    )
    let agentToolService = WorkspaceAgentToolService(
        storage: harness.storage,
        auditLogger: AuditLogger(storage: harness.storage),
        nowProvider: { harness.fixedNow }
    )
    let input = AgentDocumentMatchProposalInput(
        documentId: document.id,
        transactionId: transaction.id,
        confidence: 0.38,
        rationale: "The vendor name is similar, but the receipt total was not extracted.",
        missingFields: ["receipt total", "receipt total", "payment reference"],
        question: nil
    )

    let result = try agentToolService.execute(
        AgentToolInvocation(
            toolName: "docs.propose_match",
            inputJSON: try JSONEncoder.alpenLedger.encode(input),
            grantedScopes: [.docsPropose]
        )
    )

    let output = try JSONDecoder.alpenLedger.decode(AgentProposalToolOutput.self, from: result.outputJSON)
    let proposal = try #require(try harness.storage.agentProposalRepository.fetchAgentProposal(id: output.proposalId))
    #expect(proposal.confidence == 0.38)
    #expect(output.rationale == input.rationale)
    #expect(proposal.requiresManualReview)
    #expect(proposal.missingFields == ["receipt total", "payment reference"])
    #expect(proposal.question == "Does this document actually support the selected transaction?")
    #expect(output.requiresManualReview)
    #expect(output.missingFields == proposal.missingFields)
    #expect(output.question == proposal.question)
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .agentProposal, id: proposal.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .document, id: document.id.rawValue)))
    #expect(result.provenanceRefs.contains(ObjectRef(kind: .transaction, id: transaction.id.rawValue)))
    #expect(try harness.storage.evidenceLinkRepository.fetchEvidenceLinks(
        for: ObjectRef(kind: .document, id: document.id.rawValue)
    ).isEmpty)
}

private func agentToolAuditPayload(from event: AuditEvent) throws -> AgentToolAuditPayload {
    try JSONDecoder.alpenLedger.decode(
        AgentToolAuditPayload.self,
        from: Data(try #require(event.payload).utf8)
    )
}

private func confirmedAgentToolInvocation(
    toolName: String,
    inputJSON: Data,
    grantedScopes: Set<AgentToolScope>,
    approvedBy: String,
    approvedAt: Date,
    reason: String
) -> AgentToolInvocation {
    let invocation = AgentToolInvocation(
        toolName: toolName,
        inputJSON: inputJSON,
        grantedScopes: grantedScopes
    )
    return AgentToolInvocation(
        toolName: invocation.toolName,
        inputJSON: invocation.inputJSON,
        grantedScopes: invocation.grantedScopes,
        confirmation: AgentToolConfirmation.approving(
            invocation: invocation,
            approvedBy: approvedBy,
            approvedAt: approvedAt,
            reason: reason
        )
    )
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
    let issueService: IssueService
    let legalEntityService: LegalEntityService

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
        legalEntityService = LegalEntityService(storage: storage, auditLogger: auditLogger, nowProvider: { fixedNow })
        documentService = DocumentService(storage: storage, auditLogger: auditLogger)
        importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
        transactionService = TransactionService(storage: storage)
        evidenceRefreshService = EvidenceRefreshService(
            storage: storage,
            auditLogger: auditLogger,
            nowProvider: { fixedNow }
        )
        issueService = IssueService(storage: storage, auditLogger: auditLogger)

        entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
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

private func mutableFixtureCopy(relativePath: String, filename: String) throws -> URL {
    let sourceURL = try fixtureURL(relativePath)
    let destinationDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
    let destinationURL = destinationDirectory.appendingPathComponent(filename)
    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    return destinationURL
}

private func uniqueTextFixtureCopy(relativePath: String, filename: String, suffix: String) throws -> URL {
    let destinationURL = try mutableFixtureCopy(relativePath: relativePath, filename: filename)
    let fixtureText = try String(contentsOf: destinationURL, encoding: .utf8)
    try "\(fixtureText)\n\(suffix)\n".write(to: destinationURL, atomically: true, encoding: .utf8)
    return destinationURL
}

private func date(_ rawValue: String) -> Date {
    ISO8601DateFormatter().date(from: rawValue)!
}
