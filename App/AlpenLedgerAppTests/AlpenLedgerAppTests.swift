import XCTest
import ALDomain
import ALFeatures
import ALTaxCore
@testable import AlpenLedgerApp

final class AlpenLedgerAppTests: XCTestCase {
    func testSmoke() {
        XCTAssertTrue(true)
    }

    func testWorkspaceUIPreferencesStoreDefaultsToVisible() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = WorkspaceUIPreferencesStore(defaults: defaults)
        let workspaceId = WorkspaceID()

        XCTAssertTrue(store.inspectorVisible(workspaceId: workspaceId, section: .ledger))
        XCTAssertTrue(store.inspectorVisible(workspaceId: workspaceId, section: .documents))
    }

    func testWorkspaceUIPreferencesStorePersistsPerWorkspaceAndSection() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = WorkspaceUIPreferencesStore(defaults: defaults)
        let firstWorkspace = WorkspaceID()
        let secondWorkspace = WorkspaceID()

        store.setInspectorVisible(false, workspaceId: firstWorkspace, section: .ledger)
        store.setInspectorVisible(true, workspaceId: firstWorkspace, section: .documents)
        store.setInspectorVisible(false, workspaceId: secondWorkspace, section: .documents)

        XCTAssertFalse(store.inspectorVisible(workspaceId: firstWorkspace, section: .ledger))
        XCTAssertTrue(store.inspectorVisible(workspaceId: firstWorkspace, section: .documents))
        XCTAssertTrue(store.inspectorVisible(workspaceId: secondWorkspace, section: .ledger))
        XCTAssertFalse(store.inspectorVisible(workspaceId: secondWorkspace, section: .documents))
    }

    @MainActor
    func testSelectionCommandsFollowActiveSection() {
        let model = WorkspaceAppModel(container: DependencyContainer())

        XCTAssertFalse(model.canLinkSelectedDocument)
        XCTAssertFalse(model.canLinkSelectedTransaction)
        XCTAssertFalse(model.canToggleActiveInspector)

        model.selectedSection = .ledger
        model.selectedTransactionId = TransactionID()

        XCTAssertTrue(model.canLinkSelectedDocument)
        XCTAssertFalse(model.canLinkSelectedTransaction)
        XCTAssertFalse(model.canToggleActiveInspector)

        model.selectedSection = .documents
        model.selectedDocumentId = DocumentID()

        XCTAssertFalse(model.canLinkSelectedDocument)
        XCTAssertTrue(model.canLinkSelectedTransaction)
        XCTAssertFalse(model.canToggleActiveInspector)
    }

    @MainActor
    func testToggleInspectorForActiveSectionRoutesToVisibleSectionOnly() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        model.isLedgerInspectorVisible = true
        model.isDocumentsInspectorVisible = true

        model.selectedSection = .ledger
        model.toggleInspectorForActiveSection()
        XCTAssertFalse(model.isLedgerInspectorVisible)
        XCTAssertTrue(model.isDocumentsInspectorVisible)

        model.selectedSection = .documents
        model.toggleInspectorForActiveSection()
        XCTAssertFalse(model.isDocumentsInspectorVisible)

        model.selectedSection = .overview
        model.toggleInspectorForActiveSection()
        XCTAssertFalse(model.isLedgerInspectorVisible)
        XCTAssertFalse(model.isDocumentsInspectorVisible)
    }

    @MainActor
    func testOverviewPrimaryActionPrioritizesOpenIssues() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let workspaceId = WorkspaceID()
        let issue = Issue(
            fingerprint: "issue-1",
            workspaceId: workspaceId,
            issueCode: .missingExpenseEvidence,
            severity: .blocking,
            status: .open,
            summary: "Receipt missing for office supplies",
            objectRef: ObjectRef(kind: .transaction, id: UUID())
        )
        let proposal = AgentProposal(
            fingerprint: "proposal-1",
            workspaceId: workspaceId,
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: ObjectRef(kind: .document, id: UUID()),
            summary: "Link receipt to coffee transaction",
            rationale: "Amounts and dates line up",
            confidence: 0.86
        )
        let requirement = Requirement(
            fingerprint: "requirement-1",
            entityId: LegalEntityID(),
            taxYearId: TaxYearID(),
            requirementCode: .expenseEvidence,
            subjectRef: ObjectRef(kind: .document, id: UUID()),
            summary: "Upload health insurance certificate",
            status: .pending
        )

        model.seedUIStateForTesting(
            issues: [issue],
            agentProposals: [proposal],
            taxRequirements: [requirement],
            taxReadinessSummary: TaxReadinessSummary(
                state: .needsAttention,
                openIssueCount: 1,
                pendingRequirementCount: 1,
                currentFactCount: 0,
                missingConceptCodes: []
            )
        )

        XCTAssertEqual(
            model.overviewSnapshot.priorityAction?.action,
            .openInbox(selection: InboxSelection.issue(issue.id))
        )
    }

    @MainActor
    func testPerformOverviewActionDeepLinksToTargetSelection() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let entityId = LegalEntityID()
        let taxYearId = TaxYearID()
        let account = FinancialAccount(
            entityId: entityId,
            accountType: .bank,
            institutionName: "Personal Bank",
            displayName: "Personal Bank",
            ledgerControlAccountId: LedgerAccountID()
        )
        let transaction = Transaction(
            accountId: account.id,
            sourceLineRef: "row-1",
            bookingDate: .now,
            amountMinor: -4250,
            currency: "CHF",
            counterpartyName: "Coffee Bar Zurich",
            memo: "Team coffee"
        )
        let document = Document(
            workspaceId: WorkspaceID(),
            blobHash: "hash",
            originalFilename: "sample-receipt.pdf",
            mediaType: "application/pdf"
        )
        let taxFact = TaxFact(
            fingerprint: "fact-1",
            entityId: entityId,
            taxYearId: taxYearId,
            jurisdictionCode: "ch-zh",
            conceptCode: "personal.income.salary_gross",
            valueType: .money,
            moneyMinor: 9800000,
            status: .observed,
            rulesetVersion: "zh-personal-2026-v1"
        )

        model.seedUIStateForTesting(
            financialAccounts: [account],
            transactions: [transaction],
            documents: [document],
            taxFacts: [taxFact],
            selectedTaxEntityId: entityId,
            selectedTaxYearId: taxYearId,
            taxReadinessSummary: TaxReadinessSummary(
                state: .needsAttention,
                openIssueCount: 0,
                pendingRequirementCount: 0,
                currentFactCount: 1,
                missingConceptCodes: []
            )
        )

        model.performOverviewAction(.openLedger(accountId: account.id, transactionId: transaction.id))
        XCTAssertEqual(model.selectedSection, .ledger)
        XCTAssertEqual(model.selectedAccountId, account.id)
        XCTAssertEqual(model.selectedTransactionId, transaction.id)

        model.performOverviewAction(.openDocuments(documentId: document.id))
        XCTAssertEqual(model.selectedSection, .documents)
        XCTAssertEqual(model.selectedDocumentId, document.id)

        model.performOverviewAction(
            .openTaxStudio(entityId: entityId, taxYearId: taxYearId, factId: taxFact.id)
        )
        XCTAssertEqual(model.selectedSection, .taxStudio)
        XCTAssertEqual(model.selectedTaxEntityId, entityId)
        XCTAssertEqual(model.selectedTaxYearId, taxYearId)
        XCTAssertEqual(model.selectedTaxFactId, taxFact.id)
        XCTAssertEqual(model.selectedTaxStudioSelection, .fact(taxFact.id))
    }

    @MainActor
    func testLedgerAccountSummaryShowsUnavailableWithoutRunningBalance() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let account = FinancialAccount(
            entityId: LegalEntityID(),
            accountType: .bank,
            institutionName: "Personal Bank",
            displayName: "Personal Bank",
            ledgerControlAccountId: LedgerAccountID()
        )

        model.seedUIStateForTesting(financialAccounts: [account])
        XCTAssertEqual(model.ledgerAccountSummaries.first?.balanceText, "Balance unavailable")

        let transaction = Transaction(
            accountId: account.id,
            sourceLineRef: "row-1",
            bookingDate: .now,
            amountMinor: 1250,
            currency: "CHF",
            counterpartyName: "Client",
            memo: "Transfer",
            balanceAfterMinor: 9250
        )
        model.seedUIStateForTesting(financialAccounts: [account], transactions: [transaction])
        XCTAssertEqual(model.ledgerAccountSummaries.first?.balanceText, "92.5 CHF")
    }

    @MainActor
    func testInboxSnapshotUsesShortIssueTitles() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        let issue = Issue(
            fingerprint: "issue-short-title",
            workspaceId: WorkspaceID(),
            issueCode: .missingStatementCoverage,
            severity: .blocking,
            status: .open,
            summary: "Missing monthly statement for January 2026",
            objectRef: ObjectRef(kind: .financialAccount, id: UUID())
        )

        model.seedUIStateForTesting(issues: [issue])

        XCTAssertEqual(model.inboxSnapshot.rows.first?.title, "Statement missing")
    }
}
