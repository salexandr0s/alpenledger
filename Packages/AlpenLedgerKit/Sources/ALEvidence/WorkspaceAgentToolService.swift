import Foundation
import ALAudit
import ALDomain
import ALStorage

public enum WorkspaceAgentToolError: Error, Hashable, Sendable {
    case invalidInput(String)
    case documentNotFound(DocumentID)
    case transactionNotFound(TransactionID)
    case transactionCategoryNotFound(TransactionCategoryID)
    case taxFactNotFound(TaxFactID)
    case filingPackageNotFound(FilingPackageID)
}

public enum AgentToolAuditOutcome: String, Codable, Hashable, Sendable {
    case executed
    case rejected
}

public struct AgentToolAuditPayload: Codable, Hashable, Sendable {
    public let toolName: String
    public let outcome: AgentToolAuditOutcome
    public let sideEffect: AgentToolSideEffect?
    public let requiredScopes: [AgentToolScope]
    public let grantedScopes: [AgentToolScope]
    public let inputHash: String?
    public let confirmationInputHash: String?
    public let confirmationProvided: Bool
    public let provenanceRefs: [ObjectRef]
    public let errorCode: String?
    public let durationMilliseconds: Int

    public init(
        toolName: String,
        outcome: AgentToolAuditOutcome,
        sideEffect: AgentToolSideEffect?,
        requiredScopes: [AgentToolScope],
        grantedScopes: [AgentToolScope],
        inputHash: String?,
        confirmationInputHash: String?,
        confirmationProvided: Bool,
        provenanceRefs: [ObjectRef],
        errorCode: String?,
        durationMilliseconds: Int
    ) {
        self.toolName = toolName
        self.outcome = outcome
        self.sideEffect = sideEffect
        self.requiredScopes = requiredScopes
        self.grantedScopes = grantedScopes
        self.inputHash = inputHash
        self.confirmationInputHash = confirmationInputHash
        self.confirmationProvided = confirmationProvided
        self.provenanceRefs = provenanceRefs
        self.errorCode = errorCode
        self.durationMilliseconds = durationMilliseconds
    }
}

public struct AgentIssueListInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID?
    public let taxYearId: TaxYearID?
    public let status: IssueStatus?

    public init(
        entityId: LegalEntityID? = nil,
        taxYearId: TaxYearID? = nil,
        status: IssueStatus? = nil
    ) {
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.status = status
    }
}

public struct AgentIssueOpenOrUpdateInput: Codable, Hashable, Sendable {
    public let fingerprint: String
    public let entityId: LegalEntityID?
    public let taxYearId: TaxYearID?
    public let issueCode: IssueCode
    public let severity: IssueSeverity
    public let status: IssueStatus?
    public let summary: String
    public let objectRef: ObjectRef
    public let relatedRef: ObjectRef?

    public init(
        fingerprint: String,
        entityId: LegalEntityID? = nil,
        taxYearId: TaxYearID? = nil,
        issueCode: IssueCode,
        severity: IssueSeverity,
        status: IssueStatus? = nil,
        summary: String,
        objectRef: ObjectRef,
        relatedRef: ObjectRef? = nil
    ) {
        self.fingerprint = fingerprint
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.issueCode = issueCode
        self.severity = severity
        self.status = status
        self.summary = summary
        self.objectRef = objectRef
        self.relatedRef = relatedRef
    }
}

public struct AgentIssueToolOutput: Codable, Hashable, Sendable {
    public let issueId: IssueID
    public let fingerprint: String
    public let issueCode: IssueCode
    public let severity: IssueSeverity
    public let status: IssueStatus
    public let summary: String
    public let objectRef: ObjectRef
    public let relatedRef: ObjectRef?

    public init(issue: Issue) {
        issueId = issue.id
        fingerprint = issue.fingerprint
        issueCode = issue.issueCode
        severity = issue.severity
        status = issue.status
        summary = issue.summary
        objectRef = issue.objectRef
        relatedRef = issue.relatedRef
    }
}

public struct AgentIssueListOutput: Codable, Hashable, Sendable {
    public let issues: [AgentIssueToolOutput]

    public init(issues: [AgentIssueToolOutput]) {
        self.issues = issues
    }
}

public struct AgentFinanceListAccountsInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID

    public init(entityId: LegalEntityID) {
        self.entityId = entityId
    }
}

public struct AgentFinancialAccountToolOutput: Codable, Hashable, Sendable {
    public let accountId: FinancialAccountID
    public let entityId: LegalEntityID
    public let accountType: FinancialAccountType
    public let institutionName: String
    public let displayName: String
    public let currency: CurrencyCode
    public let ibanMask: String?
    public let statementCadence: StatementCadence
    public let openingBalanceMinor: Int64?
    public let openingBalanceDate: Date?
    public let openedAt: Date
    public let closedAt: Date?

    public init(account: FinancialAccount) {
        accountId = account.id
        entityId = account.entityId
        accountType = account.accountType
        institutionName = account.institutionName
        displayName = account.displayName
        currency = account.currency
        ibanMask = account.ibanMask
        statementCadence = account.statementCadence
        openingBalanceMinor = account.openingBalanceMinor
        openingBalanceDate = account.openingBalanceDate
        openedAt = account.openedAt
        closedAt = account.closedAt
    }
}

public struct AgentFinanceListAccountsOutput: Codable, Hashable, Sendable {
    public let accounts: [AgentFinancialAccountToolOutput]

    public init(accounts: [AgentFinancialAccountToolOutput]) {
        self.accounts = accounts
    }
}

public struct AgentFinanceSearchTransactionsInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let accountId: FinancialAccountID?
    public let query: String?
    public let from: Date?
    public let through: Date?
    public let minimumAmountMinor: Int64?
    public let maximumAmountMinor: Int64?
    public let limit: Int?

    public init(
        entityId: LegalEntityID,
        accountId: FinancialAccountID? = nil,
        query: String? = nil,
        from: Date? = nil,
        through: Date? = nil,
        minimumAmountMinor: Int64? = nil,
        maximumAmountMinor: Int64? = nil,
        limit: Int? = nil
    ) {
        self.entityId = entityId
        self.accountId = accountId
        self.query = query
        self.from = from
        self.through = through
        self.minimumAmountMinor = minimumAmountMinor
        self.maximumAmountMinor = maximumAmountMinor
        self.limit = limit
    }
}

public struct AgentTransactionToolOutput: Codable, Hashable, Sendable {
    public let transactionId: TransactionID
    public let accountId: FinancialAccountID
    public let accountDisplayName: String
    public let bookingDate: Date
    public let valueDate: Date?
    public let amountMinor: Int64
    public let currency: CurrencyCode
    public let counterpartyId: CounterpartyID?
    public let counterpartyName: String
    public let memo: String
    public let reference: String?
    public let taxCode: String?
    public let reviewState: ReviewState

    public init(transaction: Transaction, accountDisplayName: String) {
        transactionId = transaction.id
        accountId = transaction.accountId
        self.accountDisplayName = accountDisplayName
        bookingDate = transaction.bookingDate
        valueDate = transaction.valueDate
        amountMinor = transaction.amountMinor
        currency = transaction.currency
        counterpartyId = transaction.counterpartyId
        counterpartyName = transaction.counterpartyName
        memo = transaction.memo
        reference = transaction.reference
        taxCode = transaction.taxCode
        reviewState = transaction.reviewState
    }
}

public struct AgentFinanceSearchTransactionsOutput: Codable, Hashable, Sendable {
    public let transactions: [AgentTransactionToolOutput]

    public init(transactions: [AgentTransactionToolOutput]) {
        self.transactions = transactions
    }
}

public struct AgentCounterpartyToolOutput: Codable, Hashable, Sendable {
    public let counterpartyId: CounterpartyID
    public let entityId: LegalEntityID
    public let displayName: String
    public let normalizedName: String
    public let status: CounterpartyStatus
    public let mergedIntoCounterpartyId: CounterpartyID?

    public init(counterparty: Counterparty) {
        counterpartyId = counterparty.id
        entityId = counterparty.entityId
        displayName = counterparty.displayName
        normalizedName = counterparty.normalizedName
        status = counterparty.status
        mergedIntoCounterpartyId = counterparty.mergedIntoCounterpartyId
    }
}

public struct AgentCounterpartyMergeInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let sourceCounterpartyId: CounterpartyID
    public let targetCounterpartyId: CounterpartyID
    public let proposalId: AgentProposalID?

    public init(
        entityId: LegalEntityID,
        sourceCounterpartyId: CounterpartyID,
        targetCounterpartyId: CounterpartyID,
        proposalId: AgentProposalID? = nil
    ) {
        self.entityId = entityId
        self.sourceCounterpartyId = sourceCounterpartyId
        self.targetCounterpartyId = targetCounterpartyId
        self.proposalId = proposalId
    }
}

public struct AgentCounterpartyMergeOutput: Codable, Hashable, Sendable {
    public let source: AgentCounterpartyToolOutput
    public let target: AgentCounterpartyToolOutput
    public let linkedTransactionCount: Int
    public let approvalReason: String

    public init(
        result: CounterpartyMergeResult,
        approvalReason: String
    ) {
        source = AgentCounterpartyToolOutput(counterparty: result.source)
        target = AgentCounterpartyToolOutput(counterparty: result.target)
        linkedTransactionCount = result.linkedTransactionCount
        self.approvalReason = approvalReason
    }
}

public struct AgentFinanceAccountSummaryInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let accountId: FinancialAccountID

    public init(entityId: LegalEntityID, accountId: FinancialAccountID) {
        self.entityId = entityId
        self.accountId = accountId
    }
}

public struct AgentFinanceAccountSummaryOutput: Codable, Hashable, Sendable {
    public let account: AgentFinancialAccountToolOutput
    public let transactionCount: Int
    public let latestTransactionId: TransactionID?
    public let latestBookingDate: Date?
    public let latestBalanceMinor: Int64?
    public let latestBalanceSourceTransactionId: TransactionID?
    public let statementImportCount: Int
    public let latestStatementImportId: StatementImportID?
    public let latestStatementCoverageStart: Date?
    public let latestStatementCoverageEnd: Date?
    public let latestStatementClosingBalanceMinor: Int64?

    public init(
        account: FinancialAccount,
        transactions: [Transaction],
        statementImports: [StatementImport]
    ) {
        let latestTransaction = transactions.sorted { lhs, rhs in
            if lhs.bookingDate != rhs.bookingDate {
                return lhs.bookingDate > rhs.bookingDate
            }
            return lhs.sourceLineRef < rhs.sourceLineRef
        }.first
        let latestBalanceSource = transactions
            .filter { $0.balanceAfterMinor != nil }
            .sorted { lhs, rhs in
                if lhs.bookingDate != rhs.bookingDate {
                    return lhs.bookingDate > rhs.bookingDate
                }
                return lhs.sourceLineRef < rhs.sourceLineRef
            }
            .first
        let latestStatement = statementImports.first

        self.account = AgentFinancialAccountToolOutput(account: account)
        transactionCount = transactions.count
        latestTransactionId = latestTransaction?.id
        latestBookingDate = latestTransaction?.bookingDate
        latestBalanceMinor = account.currentBalanceMinor(transactions: transactions)
        latestBalanceSourceTransactionId = latestBalanceSource?.id
        statementImportCount = statementImports.count
        latestStatementImportId = latestStatement?.id
        latestStatementCoverageStart = latestStatement?.coverageStart
        latestStatementCoverageEnd = latestStatement?.coverageEnd
        latestStatementClosingBalanceMinor = latestStatement?.closingBalanceMinor
    }
}

public struct AgentDocsSearchInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID?
    public let query: String?
    public let documentType: DocumentType?
    public let limit: Int?

    public init(
        entityId: LegalEntityID? = nil,
        query: String? = nil,
        documentType: DocumentType? = nil,
        limit: Int? = nil
    ) {
        self.entityId = entityId
        self.query = query
        self.documentType = documentType
        self.limit = limit
    }
}

public struct AgentDocumentToolOutput: Codable, Hashable, Sendable {
    public let documentId: DocumentID
    public let entityId: LegalEntityID?
    public let originalFilename: String
    public let mediaType: String
    public let documentType: DocumentType
    public let issueDate: Date?
    public let metadataStatus: MetadataStatus
    public let detectedTaxYearId: TaxYearID?

    public init(document: Document) {
        documentId = document.id
        entityId = document.entityId
        originalFilename = document.originalFilename
        mediaType = document.mediaType
        documentType = document.documentType
        issueDate = document.issueDate
        metadataStatus = document.metadataStatus
        detectedTaxYearId = document.detectedTaxYearId
    }
}

public struct AgentDocsSearchOutput: Codable, Hashable, Sendable {
    public let documents: [AgentDocumentToolOutput]

    public init(documents: [AgentDocumentToolOutput]) {
        self.documents = documents
    }
}

public struct AgentDocsGetSummaryInput: Codable, Hashable, Sendable {
    public let documentId: DocumentID
    public let entityId: LegalEntityID?
    public let maximumSnippetCharacters: Int?

    public init(
        documentId: DocumentID,
        entityId: LegalEntityID? = nil,
        maximumSnippetCharacters: Int? = nil
    ) {
        self.documentId = documentId
        self.entityId = entityId
        self.maximumSnippetCharacters = maximumSnippetCharacters
    }
}

public struct AgentDocsGetSummaryOutput: Codable, Hashable, Sendable {
    public let document: AgentDocumentToolOutput
    public let textSnippet: String?
    public let snippetTruncated: Bool

    public init(document: Document, maximumSnippetCharacters: Int) {
        self.document = AgentDocumentToolOutput(document: document)
        let text = document.extractedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let text, text.isEmpty == false {
            textSnippet = String(text.prefix(maximumSnippetCharacters))
            snippetTruncated = text.count > maximumSnippetCharacters
        } else {
            textSnippet = nil
            snippetTruncated = false
        }
    }
}

public struct AgentReconcileStatementCoverageInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let accountId: FinancialAccountID?
    public let taxYearId: TaxYearID?
    public let includeSatisfied: Bool

    public init(
        entityId: LegalEntityID,
        accountId: FinancialAccountID? = nil,
        taxYearId: TaxYearID? = nil,
        includeSatisfied: Bool = true
    ) {
        self.entityId = entityId
        self.accountId = accountId
        self.taxYearId = taxYearId
        self.includeSatisfied = includeSatisfied
    }
}

public struct AgentStatementCoverageRowOutput: Codable, Hashable, Sendable {
    public let accountId: FinancialAccountID
    public let accountDisplayName: String
    public let requirementId: RequirementID
    public let requirementStatus: RequirementStatus
    public let summary: String
    public let coverageStart: Date?
    public let coverageEnd: Date?
    public let satisfiedByRef: ObjectRef?
    public let issueId: IssueID?
    public let issueSeverity: IssueSeverity?
    public let issueStatus: IssueStatus?
    public let issueSummary: String?

    public init(account: FinancialAccount, requirement: Requirement, issue: Issue?) {
        accountId = account.id
        accountDisplayName = account.displayName
        requirementId = requirement.id
        requirementStatus = requirement.status
        summary = requirement.summary
        coverageStart = requirement.coverageStart
        coverageEnd = requirement.coverageEnd
        satisfiedByRef = requirement.satisfiedByRef
        issueId = issue?.id
        issueSeverity = issue?.severity
        issueStatus = issue?.status
        issueSummary = issue?.summary
    }
}

public struct AgentReconcileStatementCoverageOutput: Codable, Hashable, Sendable {
    public let rows: [AgentStatementCoverageRowOutput]

    public init(rows: [AgentStatementCoverageRowOutput]) {
        self.rows = rows
    }
}

public struct AgentTaxListRequirementsInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID?
    public let requirementCode: RequirementCode?
    public let status: RequirementStatus?
    public let limit: Int?

    public init(
        entityId: LegalEntityID,
        taxYearId: TaxYearID? = nil,
        requirementCode: RequirementCode? = nil,
        status: RequirementStatus? = nil,
        limit: Int? = nil
    ) {
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.requirementCode = requirementCode
        self.status = status
        self.limit = limit
    }
}

public struct AgentRequirementToolOutput: Codable, Hashable, Sendable {
    public let requirementId: RequirementID
    public let fingerprint: String
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID?
    public let requirementCode: RequirementCode
    public let subjectRef: ObjectRef
    public let summary: String
    public let coverageStart: Date?
    public let coverageEnd: Date?
    public let status: RequirementStatus
    public let satisfiedByRef: ObjectRef?

    public init(requirement: Requirement) {
        requirementId = requirement.id
        fingerprint = requirement.fingerprint
        entityId = requirement.entityId
        taxYearId = requirement.taxYearId
        requirementCode = requirement.requirementCode
        subjectRef = requirement.subjectRef
        summary = requirement.summary
        coverageStart = requirement.coverageStart
        coverageEnd = requirement.coverageEnd
        status = requirement.status
        satisfiedByRef = requirement.satisfiedByRef
    }
}

public struct AgentTaxListRequirementsOutput: Codable, Hashable, Sendable {
    public let requirements: [AgentRequirementToolOutput]

    public init(requirements: [AgentRequirementToolOutput]) {
        self.requirements = requirements
    }
}

public enum AgentTaxReadinessState: String, Codable, CaseIterable, Sendable {
    case notStarted
    case needsAttention
    case readyForReview
}

public struct AgentTaxReadinessToolOutput: Codable, Hashable, Sendable {
    public let state: AgentTaxReadinessState
    public let openIssueCount: Int
    public let pendingRequirementCount: Int
    public let currentFactCount: Int
    public let missingConceptCodes: [String]

    public init(
        state: AgentTaxReadinessState,
        openIssueCount: Int,
        pendingRequirementCount: Int,
        currentFactCount: Int,
        missingConceptCodes: [String]
    ) {
        self.state = state
        self.openIssueCount = openIssueCount
        self.pendingRequirementCount = pendingRequirementCount
        self.currentFactCount = currentFactCount
        self.missingConceptCodes = missingConceptCodes
    }
}

public struct AgentTaxPreviewStatusInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID

    public init(entityId: LegalEntityID, taxYearId: TaxYearID) {
        self.entityId = entityId
        self.taxYearId = taxYearId
    }
}

public struct AgentTaxFactToolOutput: Codable, Hashable, Sendable {
    public let taxFactId: TaxFactID
    public let fingerprint: String
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public let jurisdictionCode: String
    public let conceptCode: String
    public let valueType: TaxFactValueType
    public let moneyMinor: Int64?
    public let textValue: String?
    public let boolValue: Bool?
    public let dateValue: Date?
    public let currency: CurrencyCode?
    public let status: TaxFactStatus
    public let rulesetVersion: String
    public let provenanceRefs: [ObjectRef]
    public let confidence: Double
    public let isCurrent: Bool
    public let overrideReason: String?

    public init(fact: TaxFact) {
        taxFactId = fact.id
        fingerprint = fact.fingerprint
        entityId = fact.entityId
        taxYearId = fact.taxYearId
        jurisdictionCode = fact.jurisdictionCode
        conceptCode = fact.conceptCode
        valueType = fact.valueType
        moneyMinor = fact.moneyMinor
        textValue = fact.textValue
        boolValue = fact.boolValue
        dateValue = fact.dateValue
        currency = fact.currency
        status = fact.status
        rulesetVersion = fact.rulesetVersion
        provenanceRefs = fact.provenanceRefs
        confidence = fact.confidence
        isCurrent = fact.isCurrent
        overrideReason = fact.overrideReason
    }
}

public struct AgentTaxIssueToolOutput: Codable, Hashable, Sendable {
    public let issueId: IssueID
    public let fingerprint: String
    public let issueCode: IssueCode
    public let severity: IssueSeverity
    public let status: IssueStatus
    public let summary: String
    public let objectRef: ObjectRef
    public let relatedRef: ObjectRef?

    public init(issue: Issue) {
        issueId = issue.id
        fingerprint = issue.fingerprint
        issueCode = issue.issueCode
        severity = issue.severity
        status = issue.status
        summary = issue.summary
        objectRef = issue.objectRef
        relatedRef = issue.relatedRef
    }
}

public struct AgentTaxPreviewStatusOutput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let entityDisplayName: String
    public let entityKind: LegalEntityKind
    public let taxYearId: TaxYearID
    public let year: Int
    public let canton: CantonCode?
    public let rulesetVersion: String
    public let taxYearStatus: TaxYearStatus
    public let readiness: AgentTaxReadinessToolOutput
    public let currentFacts: [AgentTaxFactToolOutput]
    public let pendingRequirements: [AgentRequirementToolOutput]
    public let openIssues: [AgentTaxIssueToolOutput]

    public init(
        entity: LegalEntity,
        taxYear: TaxYear,
        readiness: AgentTaxReadinessToolOutput,
        currentFacts: [TaxFact],
        pendingRequirements: [Requirement],
        openIssues: [Issue]
    ) {
        entityId = entity.id
        entityDisplayName = entity.displayName
        entityKind = entity.kind
        taxYearId = taxYear.id
        year = taxYear.year
        canton = taxYear.canton
        rulesetVersion = taxYear.rulesetVersion
        taxYearStatus = taxYear.status
        self.readiness = readiness
        self.currentFacts = currentFacts.map(AgentTaxFactToolOutput.init)
        self.pendingRequirements = pendingRequirements.map(AgentRequirementToolOutput.init)
        self.openIssues = openIssues.map(AgentTaxIssueToolOutput.init)
    }
}

public struct AgentTaxExplainFactInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public let factId: TaxFactID

    public init(entityId: LegalEntityID, taxYearId: TaxYearID, factId: TaxFactID) {
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.factId = factId
    }
}

public struct AgentTaxFactSourceSummaryOutput: Codable, Hashable, Sendable {
    public let sourceRef: ObjectRef
    public let title: String
    public let detail: String

    public init(sourceRef: ObjectRef, title: String, detail: String) {
        self.sourceRef = sourceRef
        self.title = title
        self.detail = detail
    }
}

public struct AgentTaxExplainFactOutput: Codable, Hashable, Sendable {
    public let fact: AgentTaxFactToolOutput
    public let summary: String
    public let sourceSummaries: [AgentTaxFactSourceSummaryOutput]
    public let missingSourceRefs: [ObjectRef]
    public let overrideReason: String?

    public init(
        fact: TaxFact,
        summary: String,
        sourceSummaries: [AgentTaxFactSourceSummaryOutput],
        missingSourceRefs: [ObjectRef]
    ) {
        self.fact = AgentTaxFactToolOutput(fact: fact)
        self.summary = summary
        self.sourceSummaries = sourceSummaries
        self.missingSourceRefs = missingSourceRefs
        overrideReason = fact.overrideReason
    }
}

public struct AgentTaxOverrideReasonProposalInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public let factId: TaxFactID
    public let proposedReason: String
    public let confidence: Double
    public let rationale: String?
    public let missingFields: [String]?
    public let question: String?

    public init(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        factId: TaxFactID,
        proposedReason: String,
        confidence: Double,
        rationale: String? = nil,
        missingFields: [String] = [],
        question: String? = nil
    ) {
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.factId = factId
        self.proposedReason = proposedReason
        self.confidence = confidence
        self.rationale = rationale
        self.missingFields = missingFields
        self.question = question
    }
}

public struct AgentRulesAcceptOverrideInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public let factId: TaxFactID
    public let proposalId: AgentProposalID?
    public let overrideReason: String

    public init(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        factId: TaxFactID,
        proposalId: AgentProposalID? = nil,
        overrideReason: String
    ) {
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.factId = factId
        self.proposalId = proposalId
        self.overrideReason = overrideReason
    }
}

public struct AgentRulesAcceptOverrideOutput: Codable, Hashable, Sendable {
    public let fact: AgentTaxFactToolOutput
    public let proposal: AgentProposalToolOutput?
    public let approvedBy: String
    public let approvedAt: Date
    public let approvalReason: String

    public init(
        fact: TaxFact,
        proposal: AgentProposal?,
        approvedBy: String,
        approvedAt: Date,
        approvalReason: String
    ) {
        self.fact = AgentTaxFactToolOutput(fact: fact)
        self.proposal = proposal.map(AgentProposalToolOutput.init)
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.approvalReason = approvalReason
    }
}

public struct AgentLedgerSplitLineInput: Codable, Hashable, Sendable {
    public let amountMinor: Int64
    public let categoryId: TransactionCategoryID?
    public let taxCode: String?
    public let memo: String?

    public init(
        amountMinor: Int64,
        categoryId: TransactionCategoryID? = nil,
        taxCode: String? = nil,
        memo: String? = nil
    ) {
        self.amountMinor = amountMinor
        self.categoryId = categoryId
        self.taxCode = taxCode
        self.memo = memo
    }
}

public struct AgentLedgerSplitProposalInput: Codable, Hashable, Sendable {
    public let transactionId: TransactionID
    public let lines: [AgentLedgerSplitLineInput]
    public let confidence: Double
    public let rationale: String
    public let missingFields: [String]?
    public let question: String?

    public init(
        transactionId: TransactionID,
        lines: [AgentLedgerSplitLineInput],
        confidence: Double,
        rationale: String,
        missingFields: [String] = [],
        question: String? = nil
    ) {
        self.transactionId = transactionId
        self.lines = lines
        self.confidence = confidence
        self.rationale = rationale
        self.missingFields = missingFields
        self.question = question
    }
}

public struct AgentLedgerMappingProposalInput: Codable, Hashable, Sendable {
    public let transactionId: TransactionID
    public let categoryId: TransactionCategoryID?
    public let taxCode: String?
    public let confidence: Double
    public let rationale: String
    public let missingFields: [String]?
    public let question: String?

    public init(
        transactionId: TransactionID,
        categoryId: TransactionCategoryID? = nil,
        taxCode: String? = nil,
        confidence: Double,
        rationale: String,
        missingFields: [String] = [],
        question: String? = nil
    ) {
        self.transactionId = transactionId
        self.categoryId = categoryId
        self.taxCode = taxCode
        self.confidence = confidence
        self.rationale = rationale
        self.missingFields = missingFields
        self.question = question
    }
}

public struct AgentClosingAccrualLineInput: Codable, Hashable, Sendable {
    public let ledgerAccountId: LedgerAccountID
    public let debitMinor: Int64
    public let creditMinor: Int64
    public let taxCode: String?
    public let sourceRef: ObjectRef?
    public let memo: String?

    public init(
        ledgerAccountId: LedgerAccountID,
        debitMinor: Int64,
        creditMinor: Int64,
        taxCode: String? = nil,
        sourceRef: ObjectRef? = nil,
        memo: String? = nil
    ) {
        self.ledgerAccountId = ledgerAccountId
        self.debitMinor = debitMinor
        self.creditMinor = creditMinor
        self.taxCode = taxCode
        self.sourceRef = sourceRef
        self.memo = memo
    }
}

public struct AgentClosingAccrualProposalInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID?
    public let effectiveDate: Date
    public let currency: CurrencyCode
    public let entryNumber: String?
    public let memo: String
    public let lines: [AgentClosingAccrualLineInput]
    public let sourceRef: ObjectRef?
    public let confidence: Double
    public let rationale: String
    public let missingFields: [String]?
    public let question: String?

    public init(
        entityId: LegalEntityID,
        taxYearId: TaxYearID? = nil,
        effectiveDate: Date,
        currency: CurrencyCode,
        entryNumber: String? = nil,
        memo: String,
        lines: [AgentClosingAccrualLineInput],
        sourceRef: ObjectRef? = nil,
        confidence: Double,
        rationale: String,
        missingFields: [String] = [],
        question: String? = nil
    ) {
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.effectiveDate = effectiveDate
        self.currency = currency
        self.entryNumber = entryNumber
        self.memo = memo
        self.lines = lines
        self.sourceRef = sourceRef
        self.confidence = confidence
        self.rationale = rationale
        self.missingFields = missingFields
        self.question = question
    }
}

public struct AgentLedgerDraftEntryLineInput: Codable, Hashable, Sendable {
    public let ledgerAccountId: LedgerAccountID
    public let debitMinor: Int64
    public let creditMinor: Int64
    public let taxCode: String?
    public let sourceRef: ObjectRef?
    public let memo: String?

    public init(
        ledgerAccountId: LedgerAccountID,
        debitMinor: Int64,
        creditMinor: Int64,
        taxCode: String? = nil,
        sourceRef: ObjectRef? = nil,
        memo: String? = nil
    ) {
        self.ledgerAccountId = ledgerAccountId
        self.debitMinor = debitMinor
        self.creditMinor = creditMinor
        self.taxCode = taxCode
        self.sourceRef = sourceRef
        self.memo = memo
    }
}

public struct AgentLedgerApplyDraftEntryInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public let effectiveDate: Date
    public let currency: CurrencyCode
    public let entryNumber: String
    public let memo: String
    public let lines: [AgentLedgerDraftEntryLineInput]
    public let proposalId: AgentProposalID?

    public init(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        effectiveDate: Date,
        currency: CurrencyCode,
        entryNumber: String,
        memo: String,
        lines: [AgentLedgerDraftEntryLineInput],
        proposalId: AgentProposalID? = nil
    ) {
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.effectiveDate = effectiveDate
        self.currency = currency
        self.entryNumber = entryNumber
        self.memo = memo
        self.lines = lines
        self.proposalId = proposalId
    }
}

public struct AgentLedgerSplitLineOutput: Codable, Hashable, Sendable {
    public let amountMinor: Int64
    public let categoryId: TransactionCategoryID?
    public let categoryCode: String?
    public let categoryDisplayName: String?
    public let taxCode: String?
    public let memo: String?

    public init(
        input: AgentLedgerSplitLineInput,
        category: TransactionCategory?,
        taxCode: String?,
        memo: String?
    ) {
        amountMinor = input.amountMinor
        categoryId = category?.id
        categoryCode = category?.code
        categoryDisplayName = category?.displayName
        self.taxCode = taxCode
        self.memo = memo
    }
}

public struct AgentLedgerAccountToolOutput: Codable, Hashable, Sendable {
    public let ledgerAccountId: LedgerAccountID
    public let code: String
    public let name: String
    public let category: LedgerCategory
    public let normalBalance: NormalBalance
    public let taxRole: String?
    public let isControlAccount: Bool

    public init(account: LedgerAccount) {
        ledgerAccountId = account.id
        code = account.code
        name = account.name
        category = account.category
        normalBalance = account.normalBalance
        taxRole = account.taxRole
        isControlAccount = account.isControlAccount
    }
}

public struct AgentClosingAccrualLineOutput: Codable, Hashable, Sendable {
    public let ledgerAccount: AgentLedgerAccountToolOutput
    public let debitMinor: Int64
    public let creditMinor: Int64
    public let taxCode: String?
    public let sourceRef: ObjectRef?
    public let memo: String?

    public init(
        account: LedgerAccount,
        debitMinor: Int64,
        creditMinor: Int64,
        taxCode: String?,
        sourceRef: ObjectRef?,
        memo: String?
    ) {
        ledgerAccount = AgentLedgerAccountToolOutput(account: account)
        self.debitMinor = debitMinor
        self.creditMinor = creditMinor
        self.taxCode = taxCode
        self.sourceRef = sourceRef
        self.memo = memo
    }
}

public struct AgentClosingAccrualDraftEntryOutput: Codable, Hashable, Sendable {
    public let entryId: JournalEntryID
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID?
    public let entryNumber: String
    public let effectiveDate: Date
    public let kind: JournalEntryKind
    public let status: JournalEntryStatus
    public let memo: String
    public let currency: CurrencyCode
    public let createdBy: String
    public let debitTotalMinor: Int64
    public let creditTotalMinor: Int64
    public let lines: [AgentClosingAccrualLineOutput]

    public init(entry: JournalEntry, currency: CurrencyCode, lines: [AgentClosingAccrualLineOutput]) {
        entryId = entry.id
        entityId = entry.entityId
        taxYearId = entry.taxYearId
        entryNumber = entry.entryNumber
        effectiveDate = entry.effectiveDate
        kind = entry.kind
        status = entry.status
        memo = entry.memo
        self.currency = currency
        createdBy = entry.createdBy
        debitTotalMinor = lines.reduce(0) { $0 + $1.debitMinor }
        creditTotalMinor = lines.reduce(0) { $0 + $1.creditMinor }
        self.lines = lines
    }
}

public struct AgentClosingAccrualProposalOutput: Codable, Hashable, Sendable {
    public let proposal: AgentProposalToolOutput
    public let draftEntry: AgentClosingAccrualDraftEntryOutput

    public init(proposal: AgentProposal, draftEntry: AgentClosingAccrualDraftEntryOutput) {
        self.proposal = AgentProposalToolOutput(proposal: proposal)
        self.draftEntry = draftEntry
    }
}

public struct AgentJournalLineToolOutput: Codable, Hashable, Sendable {
    public let journalLineId: JournalLineID
    public let ledgerAccount: AgentLedgerAccountToolOutput
    public let debitMinor: Int64
    public let creditMinor: Int64
    public let currency: CurrencyCode
    public let taxCode: String?
    public let sourceRef: ObjectRef?
    public let memo: String

    public init(line: JournalLine, account: LedgerAccount) {
        journalLineId = line.id
        ledgerAccount = AgentLedgerAccountToolOutput(account: account)
        debitMinor = line.debitMinor
        creditMinor = line.creditMinor
        currency = line.currency
        taxCode = line.taxCode
        sourceRef = line.sourceObjectRef
        memo = line.memo
    }
}

public struct AgentJournalEntryToolOutput: Codable, Hashable, Sendable {
    public let journalEntryId: JournalEntryID
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID?
    public let entryNumber: String
    public let effectiveDate: Date
    public let kind: JournalEntryKind
    public let status: JournalEntryStatus
    public let memo: String
    public let createdBy: String
    public let approvedBy: String?
    public let approvedAt: Date?
    public let debitTotalMinor: Int64
    public let creditTotalMinor: Int64
    public let lines: [AgentJournalLineToolOutput]

    public init(entry: JournalEntry, lines: [AgentJournalLineToolOutput]) {
        journalEntryId = entry.id
        entityId = entry.entityId
        taxYearId = entry.taxYearId
        entryNumber = entry.entryNumber
        effectiveDate = entry.effectiveDate
        kind = entry.kind
        status = entry.status
        memo = entry.memo
        createdBy = entry.createdBy
        approvedBy = entry.approvedBy
        approvedAt = entry.approvedAt
        debitTotalMinor = entry.lines.reduce(0) { $0 + $1.debitMinor }
        creditTotalMinor = entry.lines.reduce(0) { $0 + $1.creditMinor }
        self.lines = lines
    }
}

public struct AgentLedgerApplyDraftEntryOutput: Codable, Hashable, Sendable {
    public let journalEntry: AgentJournalEntryToolOutput
    public let proposal: AgentProposalToolOutput?
    public let approvedBy: String
    public let approvedAt: Date
    public let approvalReason: String

    public init(
        entry: JournalEntry,
        lines: [AgentJournalLineToolOutput],
        proposal: AgentProposal?,
        approvedBy: String,
        approvedAt: Date,
        approvalReason: String
    ) {
        journalEntry = AgentJournalEntryToolOutput(entry: entry, lines: lines)
        self.proposal = proposal.map(AgentProposalToolOutput.init)
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.approvalReason = approvalReason
    }
}

public struct AgentDocumentMatchProposalInput: Codable, Hashable, Sendable {
    public let documentId: DocumentID
    public let transactionId: TransactionID
    public let confidence: Double
    public let rationale: String
    public let missingFields: [String]?
    public let question: String?

    public init(
        documentId: DocumentID,
        transactionId: TransactionID,
        confidence: Double,
        rationale: String,
        missingFields: [String] = [],
        question: String? = nil
    ) {
        self.documentId = documentId
        self.transactionId = transactionId
        self.confidence = confidence
        self.rationale = rationale
        self.missingFields = missingFields
        self.question = question
    }
}

public struct AgentProposalToolOutput: Codable, Hashable, Sendable {
    public let proposalId: AgentProposalID
    public let fingerprint: String
    public let status: ProposalStatus
    public let summary: String
    public let rationale: String
    public let targetRef: ObjectRef
    public let relatedRef: ObjectRef?
    public let confidence: Double
    public let missingFields: [String]
    public let question: String?
    public let requiresManualReview: Bool

    public init(proposal: AgentProposal) {
        proposalId = proposal.id
        fingerprint = proposal.fingerprint
        status = proposal.status
        summary = proposal.summary
        rationale = proposal.rationale
        targetRef = proposal.targetRef
        relatedRef = proposal.relatedRef
        confidence = proposal.confidence
        missingFields = proposal.missingFields
        question = proposal.question
        requiresManualReview = proposal.requiresManualReview
    }
}

public struct AgentLedgerSplitProposalOutput: Codable, Hashable, Sendable {
    public let proposal: AgentProposalToolOutput
    public let transaction: AgentTransactionToolOutput
    public let splitLines: [AgentLedgerSplitLineOutput]
    public let totalAmountMinor: Int64

    public init(
        proposal: AgentProposal,
        transaction: Transaction,
        account: FinancialAccount,
        splitLines: [AgentLedgerSplitLineOutput],
        totalAmountMinor: Int64
    ) {
        self.proposal = AgentProposalToolOutput(proposal: proposal)
        self.transaction = AgentTransactionToolOutput(transaction: transaction, accountDisplayName: account.displayName)
        self.splitLines = splitLines
        self.totalAmountMinor = totalAmountMinor
    }
}

public struct AgentLedgerMappingProposalOutput: Codable, Hashable, Sendable {
    public let proposal: AgentProposalToolOutput
    public let transaction: AgentTransactionToolOutput
    public let categoryId: TransactionCategoryID?
    public let categoryCode: String?
    public let categoryDisplayName: String?
    public let taxCode: String?

    public init(
        proposal: AgentProposal,
        transaction: Transaction,
        account: FinancialAccount,
        category: TransactionCategory?,
        taxCode: String?
    ) {
        self.proposal = AgentProposalToolOutput(proposal: proposal)
        self.transaction = AgentTransactionToolOutput(transaction: transaction, accountDisplayName: account.displayName)
        categoryId = category?.id
        categoryCode = category?.code
        categoryDisplayName = category?.displayName
        self.taxCode = taxCode
    }
}

public struct AgentExportValidateInput: Codable, Hashable, Sendable {
    public let exportFormat: String
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID?
    public let vatPeriodId: VATPeriodID?
    public let uid: String?
    public let organisationName: String?
    public let generationTime: Date?
    public let businessReferenceId: String?
    public let applicationProductVersion: String?
    public let typeOfSubmission: Int?
    public let formOfReporting: Int?

    public init(
        exportFormat: String,
        entityId: LegalEntityID,
        taxYearId: TaxYearID? = nil,
        vatPeriodId: VATPeriodID? = nil,
        uid: String? = nil,
        organisationName: String? = nil,
        generationTime: Date? = nil,
        businessReferenceId: String? = nil,
        applicationProductVersion: String? = nil,
        typeOfSubmission: Int? = nil,
        formOfReporting: Int? = nil
    ) {
        self.exportFormat = exportFormat
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.vatPeriodId = vatPeriodId
        self.uid = uid
        self.organisationName = organisationName
        self.generationTime = generationTime
        self.businessReferenceId = businessReferenceId
        self.applicationProductVersion = applicationProductVersion
        self.typeOfSubmission = typeOfSubmission
        self.formOfReporting = formOfReporting
    }
}

public struct AgentExportGeneratePackageInput: Codable, Hashable, Sendable {
    public let exportFormat: String
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public let vatPeriodId: VATPeriodID?
    public let uid: String?
    public let organisationName: String?
    public let generationTime: Date?
    public let businessReferenceId: String?
    public let applicationProductVersion: String?
    public let typeOfSubmission: Int?
    public let formOfReporting: Int?

    public init(
        exportFormat: String,
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        vatPeriodId: VATPeriodID? = nil,
        uid: String? = nil,
        organisationName: String? = nil,
        generationTime: Date? = nil,
        businessReferenceId: String? = nil,
        applicationProductVersion: String? = nil,
        typeOfSubmission: Int? = nil,
        formOfReporting: Int? = nil
    ) {
        self.exportFormat = exportFormat
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.vatPeriodId = vatPeriodId
        self.uid = uid
        self.organisationName = organisationName
        self.generationTime = generationTime
        self.businessReferenceId = businessReferenceId
        self.applicationProductVersion = applicationProductVersion
        self.typeOfSubmission = typeOfSubmission
        self.formOfReporting = formOfReporting
    }
}

public struct AgentExportValidationIssueToolOutput: Codable, Hashable, Sendable {
    public let severity: VATReconciliationIssueSeverity
    public let code: String
    public let message: String
    public let sourceRef: ObjectRef?

    public init(
        severity: VATReconciliationIssueSeverity,
        code: String,
        message: String,
        sourceRef: ObjectRef? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.sourceRef = sourceRef
    }
}

public struct AgentExportValidationProviderResult: Codable, Hashable, Sendable {
    public let schemaVersion: String?
    public let issues: [AgentExportValidationIssueToolOutput]

    public init(schemaVersion: String? = nil, issues: [AgentExportValidationIssueToolOutput]) {
        self.schemaVersion = schemaVersion
        self.issues = issues
    }
}

public struct AgentExportPackageProviderResult: Hashable, Sendable {
    public let schemaVersion: String?
    public let artifactFilename: String
    public let mediaType: String
    public let artifactData: Data
    public let issues: [AgentExportValidationIssueToolOutput]
    public let sourceRefs: [ObjectRef]

    public init(
        schemaVersion: String? = nil,
        artifactFilename: String,
        mediaType: String,
        artifactData: Data,
        issues: [AgentExportValidationIssueToolOutput],
        sourceRefs: [ObjectRef]
    ) {
        self.schemaVersion = schemaVersion
        self.artifactFilename = artifactFilename
        self.mediaType = mediaType
        self.artifactData = artifactData
        self.issues = issues
        self.sourceRefs = sourceRefs
    }
}

public struct AgentExportValidationToolOutput: Codable, Hashable, Sendable {
    public let exportFormat: String
    public let schemaVersion: String?
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID?
    public let vatPeriodId: VATPeriodID?
    public let blockerCount: Int
    public let warningCount: Int
    public let issues: [AgentExportValidationIssueToolOutput]

    public init(input: AgentExportValidateInput, providerResult: AgentExportValidationProviderResult) {
        exportFormat = input.exportFormat
        schemaVersion = providerResult.schemaVersion
        entityId = input.entityId
        taxYearId = input.taxYearId
        vatPeriodId = input.vatPeriodId
        issues = providerResult.issues
        blockerCount = providerResult.issues.filter { $0.severity == .blocker }.count
        warningCount = providerResult.issues.filter { $0.severity == .warning }.count
    }
}

public struct AgentExportPackageToolOutput: Codable, Hashable, Sendable {
    public let filingPackageId: FilingPackageID
    public let exportFormat: String
    public let schemaVersion: String?
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public let vatPeriodId: VATPeriodID?
    public let status: FilingPackageStatus
    public let generatedAt: Date?
    public let artifactHash: String
    public let artifactByteCount: Int
    public let artifactFilename: String
    public let mediaType: String
    public let blockerCount: Int
    public let warningCount: Int
    public let issues: [AgentExportValidationIssueToolOutput]

    public init(
        input: AgentExportGeneratePackageInput,
        filingPackage: FilingPackage,
        providerResult: AgentExportPackageProviderResult,
        artifactHash: String
    ) {
        filingPackageId = filingPackage.id
        exportFormat = filingPackage.exportFormat
        schemaVersion = providerResult.schemaVersion
        entityId = filingPackage.entityId
        taxYearId = filingPackage.taxYearId
        vatPeriodId = input.vatPeriodId
        status = filingPackage.status
        generatedAt = filingPackage.generatedAt
        self.artifactHash = artifactHash
        artifactByteCount = providerResult.artifactData.count
        artifactFilename = providerResult.artifactFilename
        mediaType = providerResult.mediaType
        issues = providerResult.issues
        blockerCount = providerResult.issues.filter { $0.severity == .blocker }.count
        warningCount = providerResult.issues.filter { $0.severity == .warning }.count
    }
}

public struct AgentExportFinalizePackageInput: Codable, Hashable, Sendable {
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public let filingPackageId: FilingPackageID
    public let expectedSnapshotHash: String

    public init(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        filingPackageId: FilingPackageID,
        expectedSnapshotHash: String
    ) {
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.filingPackageId = filingPackageId
        self.expectedSnapshotHash = expectedSnapshotHash
    }
}

public struct AgentExportFinalizePackageOutput: Codable, Hashable, Sendable {
    public let filingPackageId: FilingPackageID
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public let exportFormat: String
    public let status: FilingPackageStatus
    public let generatedAt: Date?
    public let finalizedAt: Date?
    public let finalizedBy: String?
    public let submittedAt: Date?
    public let snapshotHash: String
    public let approvedBy: String
    public let approvedAt: Date
    public let approvalReason: String

    public init(
        filingPackage: FilingPackage,
        approvedBy: String,
        approvedAt: Date,
        approvalReason: String
    ) {
        filingPackageId = filingPackage.id
        entityId = filingPackage.entityId
        taxYearId = filingPackage.taxYearId
        exportFormat = filingPackage.exportFormat
        status = filingPackage.status
        generatedAt = filingPackage.generatedAt
        finalizedAt = filingPackage.finalizedAt
        finalizedBy = filingPackage.finalizedBy
        submittedAt = filingPackage.submittedAt
        snapshotHash = filingPackage.snapshotHash ?? ""
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.approvalReason = approvalReason
    }
}

public struct AgentAuditTraceInput: Codable, Hashable, Sendable {
    public let objectRef: ObjectRef
    public let entityId: LegalEntityID?
    public let limit: Int?

    public init(objectRef: ObjectRef, entityId: LegalEntityID? = nil, limit: Int? = nil) {
        self.objectRef = objectRef
        self.entityId = entityId
        self.limit = limit
    }
}

public struct AgentAuditEventToolOutput: Codable, Hashable, Sendable {
    public let eventId: AuditEventID
    public let eventType: AuditEventType
    public let actorType: AuditActorType
    public let actorId: String
    public let objectRef: ObjectRef
    public let occurredAt: Date
    public let payloadPreview: String?

    public init(event: AuditEvent, payloadPreview: String?) {
        eventId = event.id
        eventType = event.eventType
        actorType = event.actorType
        actorId = event.actorId
        objectRef = event.objectRef
        occurredAt = event.occurredAt
        self.payloadPreview = payloadPreview
    }
}

public struct AgentAuditTraceToolOutput: Codable, Hashable, Sendable {
    public let targetRef: ObjectRef
    public let eventCount: Int
    public let hasMore: Bool
    public let events: [AgentAuditEventToolOutput]

    public init(targetRef: ObjectRef, eventCount: Int, hasMore: Bool, events: [AgentAuditEventToolOutput]) {
        self.targetRef = targetRef
        self.eventCount = eventCount
        self.hasMore = hasMore
        self.events = events
    }
}

public final class WorkspaceAgentToolService: Sendable {
    public typealias TaxStatusProvider = @Sendable (LegalEntityID, TaxYearID) throws -> AgentTaxReadinessToolOutput
    public typealias ExportValidationProvider = @Sendable (AgentExportValidateInput) throws -> AgentExportValidationProviderResult
    public typealias ExportPackageProvider = @Sendable (AgentExportGeneratePackageInput) throws -> AgentExportPackageProviderResult

    private let storage: WorkspaceStorage
    private let auditLogger: AuditLogger
    private let registry: AgentToolRegistry
    private let taxStatusProvider: TaxStatusProvider?
    private let exportValidationProvider: ExportValidationProvider?
    private let exportPackageProvider: ExportPackageProvider?
    private let nowProvider: @Sendable () -> Date

    public init(
        storage: WorkspaceStorage,
        auditLogger: AuditLogger,
        registry: AgentToolRegistry = .productionDefaults,
        taxStatusProvider: TaxStatusProvider? = nil,
        exportValidationProvider: ExportValidationProvider? = nil,
        exportPackageProvider: ExportPackageProvider? = nil,
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.storage = storage
        self.auditLogger = auditLogger
        self.registry = registry
        self.taxStatusProvider = taxStatusProvider
        self.exportValidationProvider = exportValidationProvider
        self.exportPackageProvider = exportPackageProvider
        self.nowProvider = nowProvider
    }

    public func execute(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let startedAt = nowProvider()
        let executor = AgentToolExecutor(
            registry: registry,
            handlers: [
                "finance.list_accounts": handleFinanceListAccounts,
                "finance.search_transactions": handleFinanceSearchTransactions,
                "finance.account_summary": handleFinanceAccountSummary,
                "docs.search": handleDocumentSearch,
                "docs.get_summary": handleDocumentSummary,
                "reconcile.statement_coverage": handleStatementCoverage,
                "issues.list_open": handleIssueList,
                "tax.list_requirements": handleTaxListRequirements,
                "tax.preview_status": handleTaxPreviewStatus,
                "tax.explain_fact": handleTaxExplainFact,
                "audit.trace_object": handleAuditTraceObject,
                "tax.propose_override_reason": handleTaxOverrideReasonProposal,
                "rules.accept_override": handleRulesAcceptOverride,
                "ledger.propose_mapping": handleLedgerMappingProposal,
                "ledger.propose_split": handleLedgerSplitProposal,
                "closing.propose_accrual": handleClosingAccrualProposal,
                "ledger.apply_draft_entry": handleLedgerApplyDraftEntry,
                "entities.merge_counterparties": handleEntitiesMergeCounterparties,
                "exports.generate_package": handleExportGeneratePackage,
                "exports.finalize_package": handleExportFinalizePackage,
                "exports.validate": handleExportValidate,
                "issues.open_or_update": handleIssueOpenOrUpdate,
                "docs.propose_match": handleDocumentMatchProposal,
            ]
        )
        let result: AgentToolExecutionResult
        do {
            result = try executor.execute(invocation)
        } catch {
            try? logAgentToolAudit(
                invocation: invocation,
                outcome: .rejected,
                result: nil,
                error: error,
                startedAt: startedAt,
                finishedAt: nowProvider()
            )
            throw error
        }
        try logAgentToolAudit(
            invocation: invocation,
            outcome: .executed,
            result: result,
            error: nil,
            startedAt: startedAt,
            finishedAt: nowProvider()
        )
        return result
    }

    private func handleFinanceListAccounts(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentFinanceListAccountsInput.self, from: invocation)
        _ = try storage.requireEntity(entityId: input.entityId)
        let accounts = try storage.financialAccountRepository.fetchFinancialAccounts(entityId: input.entityId)
        let output = AgentFinanceListAccountsOutput(accounts: accounts.map(AgentFinancialAccountToolOutput.init))
        let provenanceRefs = accounts.map { ObjectRef(kind: .financialAccount, id: $0.id.rawValue) }
        return try encodedResult(
            output,
            provenanceRefs: provenanceRefs.isEmpty
                ? [ObjectRef(kind: .legalEntity, id: input.entityId.rawValue)]
                : provenanceRefs
        )
    }

    private func handleFinanceSearchTransactions(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentFinanceSearchTransactionsInput.self, from: invocation)
        _ = try storage.requireEntity(entityId: input.entityId)
        let limit = try normalizedLimit(input.limit, toolName: invocation.toolName)
        let trimmedQuery = try normalizedQuery(input.query, toolName: invocation.toolName)
        if let from = input.from, let through = input.through, from > through {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        if let minimum = input.minimumAmountMinor,
           let maximum = input.maximumAmountMinor,
           minimum > maximum {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let accounts = try storage.financialAccountRepository.fetchFinancialAccounts(entityId: input.entityId)
        let scopedAccounts: [FinancialAccount]
        if let accountId = input.accountId {
            guard let account = accounts.first(where: { $0.id == accountId }) else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
            scopedAccounts = [account]
        } else {
            scopedAccounts = accounts
        }
        let accountNames = Dictionary(uniqueKeysWithValues: scopedAccounts.map { ($0.id, $0.displayName) })

        var transactions: [Transaction] = []
        for account in scopedAccounts {
            transactions.append(contentsOf: try storage.transactionRepository.fetchTransactions(accountId: account.id))
        }
        transactions = transactions
            .filter { transaction in
                guard input.from.map({ transaction.bookingDate >= $0 }) ?? true else { return false }
                guard input.through.map({ transaction.bookingDate <= $0 }) ?? true else { return false }
                guard input.minimumAmountMinor.map({ transaction.amountMinor >= $0 }) ?? true else { return false }
                guard input.maximumAmountMinor.map({ transaction.amountMinor <= $0 }) ?? true else { return false }
                guard trimmedQuery.isEmpty == false else { return true }
                return transaction.counterpartyName.localizedCaseInsensitiveContains(trimmedQuery) ||
                    transaction.memo.localizedCaseInsensitiveContains(trimmedQuery) ||
                    (transaction.reference?.localizedCaseInsensitiveContains(trimmedQuery) ?? false) ||
                    transaction.sourceLineRef.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .sorted { lhs, rhs in
                if lhs.bookingDate != rhs.bookingDate {
                    return lhs.bookingDate > rhs.bookingDate
                }
                return lhs.sourceLineRef < rhs.sourceLineRef
            }
        let limitedTransactions = Array(transactions.prefix(limit))
        let output = AgentFinanceSearchTransactionsOutput(
            transactions: limitedTransactions.map {
                AgentTransactionToolOutput(
                    transaction: $0,
                    accountDisplayName: accountNames[$0.accountId] ?? "Unknown account"
                )
            }
        )
        let provenanceRefs = limitedTransactions.map { ObjectRef(kind: .transaction, id: $0.id.rawValue) }
        return try encodedResult(
            output,
            provenanceRefs: provenanceRefs.isEmpty
                ? emptyFinanceSearchProvenance(input: input, scopedAccounts: scopedAccounts)
                : provenanceRefs
        )
    }

    private func handleFinanceAccountSummary(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentFinanceAccountSummaryInput.self, from: invocation)
        guard let account = try storage.financialAccountRepository.fetchFinancialAccount(id: input.accountId),
              account.entityId == input.entityId
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let transactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)
        let statementImports = try storage.statementImportRepository.fetchStatementImports(accountId: account.id)
        let output = AgentFinanceAccountSummaryOutput(
            account: account,
            transactions: transactions,
            statementImports: statementImports
        )
        var provenanceRefs = [ObjectRef(kind: .financialAccount, id: account.id.rawValue)]
        if let latestBalanceSourceTransactionId = output.latestBalanceSourceTransactionId {
            provenanceRefs.append(ObjectRef(kind: .transaction, id: latestBalanceSourceTransactionId.rawValue))
        } else if let latestTransactionId = output.latestTransactionId {
            provenanceRefs.append(ObjectRef(kind: .transaction, id: latestTransactionId.rawValue))
        }
        if let latestStatementImportId = output.latestStatementImportId {
            provenanceRefs.append(ObjectRef(kind: .statementImport, id: latestStatementImportId.rawValue))
        }
        return try encodedResult(output, provenanceRefs: provenanceRefs)
    }

    private func handleDocumentSearch(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentDocsSearchInput.self, from: invocation)
        let limit = try normalizedLimit(input.limit, toolName: invocation.toolName)
        let trimmedQuery = try normalizedQuery(input.query, toolName: invocation.toolName)
        if let entityId = input.entityId {
            _ = try storage.requireEntity(entityId: entityId)
        }

        let documents: [Document]
        if trimmedQuery.isEmpty {
            if let entityId = input.entityId {
                documents = try storage.documentRepository.fetchDocuments(entityId: entityId)
            } else {
                documents = try storage.documentRepository.fetchDocuments(workspaceId: storage.manifest.workspace.id)
            }
        } else {
            let ids = try storage.searchIndex.searchDocumentIDs(
                workspaceId: storage.manifest.workspace.id,
                query: trimmedQuery
            )
            let fetchedDocuments = try storage.documentRepository.fetchDocuments(ids: ids)
            let lookup = Dictionary(uniqueKeysWithValues: fetchedDocuments.map { ($0.id, $0) })
            documents = ids.compactMap { lookup[$0] }
        }

        let filteredDocuments = documents
            .filter { document in
                guard input.entityId.map({ document.entityId == $0 }) ?? (document.entityId == nil) else {
                    return false
                }
                guard input.documentType.map({ document.documentType == $0 }) ?? true else { return false }
                return true
            }
            .prefix(limit)
        let output = AgentDocsSearchOutput(documents: filteredDocuments.map(AgentDocumentToolOutput.init))
        let provenanceRefs = filteredDocuments.map { ObjectRef(kind: .document, id: $0.id.rawValue) }
        return try encodedResult(
            output,
            provenanceRefs: provenanceRefs.isEmpty
                ? [
                    input.entityId.map { ObjectRef(kind: .legalEntity, id: $0.rawValue) }
                        ?? ObjectRef(kind: .workspace, id: storage.manifest.workspace.id.rawValue),
                ]
                : provenanceRefs
        )
    }

    private func handleDocumentSummary(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentDocsGetSummaryInput.self, from: invocation)
        let snippetLimit = try normalizedSnippetLimit(
            input.maximumSnippetCharacters,
            toolName: invocation.toolName
        )
        guard let document = try storage.documentRepository.fetchDocument(id: input.documentId) else {
            throw WorkspaceAgentToolError.documentNotFound(input.documentId)
        }
        guard document.status == .active else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        if let entityId = input.entityId {
            _ = try storage.requireEntity(entityId: entityId)
            guard document.entityId == entityId else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
        } else if document.entityId != nil {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        return try encodedResult(
            AgentDocsGetSummaryOutput(document: document, maximumSnippetCharacters: snippetLimit),
            provenanceRefs: [ObjectRef(kind: .document, id: document.id.rawValue)]
        )
    }

    private func handleStatementCoverage(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentReconcileStatementCoverageInput.self, from: invocation)
        let accounts = try scopedAccounts(
            entityId: input.entityId,
            accountId: input.accountId,
            toolName: invocation.toolName
        )
        let accountLookup = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let accountRefs = Set(accounts.map { ObjectRef(kind: .financialAccount, id: $0.id.rawValue) })
        let requirements = try storage.requirementRepository
            .fetchRequirements(entityId: input.entityId, taxYearId: input.taxYearId)
            .filter {
                $0.requirementCode == .statementCoverage &&
                    accountRefs.contains($0.subjectRef) &&
                    (input.includeSatisfied || $0.status != .satisfied)
            }
        let issues = try IssueService(storage: storage, auditLogger: auditLogger).listIssues(
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            status: nil
        )
        let issueByRequirementRef = Dictionary(
            uniqueKeysWithValues: issues
                .filter { $0.issueCode == .missingStatementCoverage }
                .compactMap { issue -> (ObjectRef, Issue)? in
                    guard let relatedRef = issue.relatedRef else { return nil }
                    return (relatedRef, issue)
                }
        )
        let rows = requirements.compactMap { requirement -> AgentStatementCoverageRowOutput? in
            guard let accountId = UUID(uuidString: requirement.subjectRef.id).map(FinancialAccountID.init(rawValue:)),
                  let account = accountLookup[accountId]
            else {
                return nil
            }
            let requirementRef = ObjectRef(kind: .requirement, id: requirement.id.rawValue)
            return AgentStatementCoverageRowOutput(
                account: account,
                requirement: requirement,
                issue: issueByRequirementRef[requirementRef]
            )
        }
        let provenanceRefs = statementCoverageProvenanceRefs(
            accounts: accounts,
            requirements: requirements,
            rows: rows
        )
        return try encodedResult(AgentReconcileStatementCoverageOutput(rows: rows), provenanceRefs: provenanceRefs)
    }

    private func handleIssueList(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentIssueListInput.self, from: invocation)
        if let taxYearId = input.taxYearId {
            guard let entityId = input.entityId else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
            _ = try storage.requireTaxYear(entityId: entityId, taxYearId: taxYearId)
        } else if let entityId = input.entityId {
            _ = try storage.requireEntity(entityId: entityId)
        }
        let issueService = IssueService(storage: storage, auditLogger: auditLogger)
        let issues = try issueService.listIssues(
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            status: input.status ?? .open
        )
        let output = AgentIssueListOutput(issues: issues.map(AgentIssueToolOutput.init))
        let provenanceRefs = issues.map { ObjectRef(kind: .issue, id: $0.id.rawValue) }
        return try encodedResult(
            output,
            provenanceRefs: provenanceRefs.isEmpty
                ? [ObjectRef(kind: .workspace, id: storage.manifest.workspace.id.rawValue)]
                : provenanceRefs
        )
    }

    private func handleTaxListRequirements(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentTaxListRequirementsInput.self, from: invocation)
        let limit = try normalizedLimit(input.limit, toolName: invocation.toolName)
        if let taxYearId = input.taxYearId {
            _ = try storage.requireTaxYear(entityId: input.entityId, taxYearId: taxYearId)
        } else {
            _ = try storage.requireEntity(entityId: input.entityId)
        }

        let requirements = try storage.requirementRepository
            .fetchRequirements(entityId: input.entityId, taxYearId: input.taxYearId)
            .filter { requirement in
                guard input.requirementCode.map({ requirement.requirementCode == $0 }) ?? true else { return false }
                guard input.status.map({ requirement.status == $0 }) ?? true else { return false }
                return true
            }
            .sorted { lhs, rhs in
                if lhs.status != rhs.status {
                    return lhs.status.rawValue < rhs.status.rawValue
                }
                return lhs.summary < rhs.summary
            }
            .prefix(limit)
        let output = AgentTaxListRequirementsOutput(
            requirements: requirements.map(AgentRequirementToolOutput.init)
        )
        let provenanceRefs = requirements.map { ObjectRef(kind: .requirement, id: $0.id.rawValue) }
        return try encodedResult(
            output,
            provenanceRefs: provenanceRefs.isEmpty
                ? taxContextProvenanceRefs(entityId: input.entityId, taxYearId: input.taxYearId)
                : provenanceRefs
        )
    }

    private func handleTaxPreviewStatus(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentTaxPreviewStatusInput.self, from: invocation)
        let entity = try storage.requireEntity(entityId: input.entityId)
        let taxYear = try storage.requireTaxYear(entityId: input.entityId, taxYearId: input.taxYearId)
        let currentFacts = try storage.taxFactRepository.fetchTaxFacts(
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            currentOnly: true
        )
        let requirements = try storage.requirementRepository.fetchRequirements(
            entityId: input.entityId,
            taxYearId: input.taxYearId
        )
        let pendingRequirements = requirements.filter { $0.status == .pending }
        let openIssues = try IssueService(storage: storage, auditLogger: auditLogger).listIssues(
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            status: .open
        )
        let readiness = try taxStatusProvider?(input.entityId, input.taxYearId) ?? fallbackTaxReadiness(
            currentFactCount: currentFacts.count,
            pendingRequirementCount: pendingRequirements.count,
            openIssueCount: openIssues.count
        )
        let output = AgentTaxPreviewStatusOutput(
            entity: entity,
            taxYear: taxYear,
            readiness: readiness,
            currentFacts: currentFacts,
            pendingRequirements: pendingRequirements,
            openIssues: openIssues
        )
        return try encodedResult(
            output,
            provenanceRefs: taxPreviewStatusProvenanceRefs(
                entityId: input.entityId,
                taxYearId: input.taxYearId,
                facts: currentFacts,
                requirements: pendingRequirements,
                issues: openIssues
            )
        )
    }

    private func handleTaxExplainFact(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentTaxExplainFactInput.self, from: invocation)
        guard let fact = try storage.taxFactRepository.fetchTaxFact(id: input.factId) else {
            throw WorkspaceAgentToolError.taxFactNotFound(input.factId)
        }
        guard fact.entityId == input.entityId, fact.taxYearId == input.taxYearId else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        var sourceSummaries: [AgentTaxFactSourceSummaryOutput] = []
        var missingSourceRefs: [ObjectRef] = []
        for sourceRef in fact.provenanceRefs {
            if let sourceSummary = try taxFactSourceSummary(for: sourceRef) {
                sourceSummaries.append(sourceSummary)
            } else {
                missingSourceRefs.append(sourceRef)
            }
        }
        let output = AgentTaxExplainFactOutput(
            fact: fact,
            summary: taxFactExplanationSummary(
                fact: fact,
                resolvedSourceCount: sourceSummaries.count,
                missingSourceCount: missingSourceRefs.count
            ),
            sourceSummaries: sourceSummaries,
            missingSourceRefs: missingSourceRefs
        )
        var provenanceRefs = [ObjectRef(kind: .taxFact, id: fact.id.rawValue)]
        for sourceSummary in sourceSummaries {
            appendUnique(sourceSummary.sourceRef, to: &provenanceRefs)
        }
        return try encodedResult(output, provenanceRefs: provenanceRefs)
    }

    private func handleAuditTraceObject(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentAuditTraceInput.self, from: invocation)
        let limit = try normalizedLimit(input.limit, toolName: invocation.toolName)
        let objectRef = try validatedAuditTraceReference(
            input.objectRef,
            entityId: input.entityId,
            toolName: invocation.toolName
        )

        let events = try ProvenanceTraceService(storage: storage).events(for: objectRef)
        let limitedEvents = Array(events.prefix(limit))
        let output = AgentAuditTraceToolOutput(
            targetRef: objectRef,
            eventCount: events.count,
            hasMore: events.count > limitedEvents.count,
            events: limitedEvents.map { event in
                AgentAuditEventToolOutput(event: event, payloadPreview: boundedAuditPayload(event.payload))
            }
        )
        var provenanceRefs = [objectRef]
        for event in limitedEvents {
            appendUnique(ObjectRef(kind: .auditEvent, id: event.id.rawValue), to: &provenanceRefs)
        }
        return try encodedResult(output, provenanceRefs: provenanceRefs)
    }

    private func handleTaxOverrideReasonProposal(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentTaxOverrideReasonProposalInput.self, from: invocation)
        let taxYear = try storage.requireTaxYear(entityId: input.entityId, taxYearId: input.taxYearId)
        guard taxYear.status == .open else {
            throw DomainError.lockedPeriod
        }
        guard let fact = try storage.taxFactRepository.fetchTaxFact(id: input.factId) else {
            throw WorkspaceAgentToolError.taxFactNotFound(input.factId)
        }
        guard fact.entityId == input.entityId,
              fact.taxYearId == input.taxYearId,
              fact.isCurrent
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let proposedReason = input.proposedReason.trimmingCharacters(in: .whitespacesAndNewlines)
        let rationale = (input.rationale ?? "Proposed override reason: \(proposedReason)")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard proposedReason.isEmpty == false,
              proposedReason.count <= 500,
              rationale.isEmpty == false,
              rationale.count <= 1_000,
              input.confidence >= 0,
              input.confidence <= 1
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        let reviewMetadata = try proposalReviewMetadata(
            confidence: input.confidence,
            missingFields: input.missingFields,
            question: input.question,
            defaultLowConfidenceQuestion: "What evidence justifies overriding this tax fact?",
            toolName: invocation.toolName
        )

        let fingerprint = "tax.propose_override_reason|\(fact.id)"
        let existing = try storage.agentProposalRepository.fetchAgentProposal(fingerprint: fingerprint)
        let previousStatus = existing?.status
        var proposal = existing ?? AgentProposal(
            fingerprint: fingerprint,
            workspaceId: storage.manifest.workspace.id,
            agentKind: .systemHeuristics,
            proposalType: .taxOverrideReview,
            targetRef: ObjectRef(kind: .taxFact, id: fact.id.rawValue),
            relatedRef: nil,
            summary: "",
            rationale: "",
            confidence: input.confidence,
            status: .pending,
            createdAt: nowProvider()
        )

        proposal.proposalType = .taxOverrideReview
        proposal.targetRef = ObjectRef(kind: .taxFact, id: fact.id.rawValue)
        proposal.relatedRef = nil
        proposal.summary = "Review override reason for \(fact.conceptCode)"
        proposal.rationale = rationale
        proposal.confidence = input.confidence
        proposal.missingFields = reviewMetadata.missingFields
        proposal.question = reviewMetadata.question
        proposal.requiresManualReview = reviewMetadata.requiresManualReview
        if proposal.status != .rejected {
            proposal.status = .pending
            proposal.decidedAt = nil
            proposal.decidedBy = nil
            proposal.decisionReason = nil
        }

        try storage.agentProposalRepository.saveAgentProposal(proposal)

        if previousStatus != .pending, proposal.status == .pending {
            try auditLogger.log(
                eventType: .proposalCreated,
                objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                payload: proposal.summary
            )
        }

        return try encodedResult(
            AgentProposalToolOutput(proposal: proposal),
            provenanceRefs: [
                ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                ObjectRef(kind: .taxFact, id: fact.id.rawValue),
            ]
        )
    }

    private func handleRulesAcceptOverride(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentRulesAcceptOverrideInput.self, from: invocation)
        guard let confirmation = invocation.confirmation else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        guard let approvedBy = try normalizedBoundedString(
            confirmation.approvedBy,
            maximumCount: 128,
            toolName: invocation.toolName
        ),
            let approvalReason = try normalizedBoundedString(
                confirmation.reason,
                maximumCount: 500,
                toolName: invocation.toolName
            ),
            let overrideReason = try normalizedBoundedString(
                input.overrideReason,
                maximumCount: 500,
                toolName: invocation.toolName
            )
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let taxYear = try storage.requireTaxYear(entityId: input.entityId, taxYearId: input.taxYearId)
        guard taxYear.status == .open else {
            throw DomainError.lockedPeriod
        }
        guard var fact = try storage.taxFactRepository.fetchTaxFact(id: input.factId) else {
            throw WorkspaceAgentToolError.taxFactNotFound(input.factId)
        }
        guard fact.entityId == input.entityId,
              fact.taxYearId == input.taxYearId,
              fact.isCurrent
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        var proposal: AgentProposal?
        if let proposalId = input.proposalId {
            guard var loadedProposal = try storage.agentProposalRepository.fetchAgentProposal(id: proposalId) else {
                throw DomainError.proposalNotFound
            }
            guard loadedProposal.proposalType == .taxOverrideReview,
                  loadedProposal.status == .pending,
                  loadedProposal.targetRef == ObjectRef(kind: .taxFact, id: fact.id.rawValue)
            else {
                throw DomainError.invalidProposal
            }
            loadedProposal.status = .resolved
            loadedProposal.decidedAt = confirmation.approvedAt
            loadedProposal.decidedBy = approvedBy
            loadedProposal.decisionReason = approvalReason
            proposal = loadedProposal
        }

        fact.status = .overridden
        fact.overrideReason = overrideReason
        fact.updatedAt = nowProvider()
        try storage.taxFactRepository.saveTaxFact(fact)
        try auditLogger.log(
            actorType: .user,
            actorId: approvedBy,
            eventType: .taxFactOverridden,
            objectRef: ObjectRef(kind: .taxFact, id: fact.id.rawValue),
            payload: overrideReason
        )

        if let resolvedProposal = proposal {
            try storage.agentProposalRepository.saveAgentProposal(resolvedProposal)
            try auditLogger.log(
                actorType: .user,
                actorId: approvedBy,
                eventType: .proposalResolved,
                objectRef: ObjectRef(kind: .agentProposal, id: resolvedProposal.id.rawValue),
                payload: resolvedProposal.summary
            )
        }

        return try encodedResult(
            AgentRulesAcceptOverrideOutput(
                fact: fact,
                proposal: proposal,
                approvedBy: approvedBy,
                approvedAt: confirmation.approvedAt,
                approvalReason: approvalReason
            ),
            provenanceRefs: taxOverrideAcceptanceProvenanceRefs(
                entityId: input.entityId,
                taxYearId: input.taxYearId,
                fact: fact,
                proposal: proposal
            )
        )
    }

    private func handleLedgerMappingProposal(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentLedgerMappingProposalInput.self, from: invocation)
        guard let transaction = try storage.transactionRepository.fetchTransactions(ids: [input.transactionId]).first else {
            throw WorkspaceAgentToolError.transactionNotFound(input.transactionId)
        }
        guard let account = try storage.financialAccountRepository.fetchFinancialAccount(id: transaction.accountId) else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let rationale = input.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        let taxCode = input.taxCode?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard rationale.isEmpty == false,
              rationale.count <= 1_000,
              taxCode.map({ $0.count <= 64 }) ?? true,
              input.confidence >= 0,
              input.confidence <= 1
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let category = try input.categoryId.map { categoryId in
            guard let category = try storage.categoryRepository.fetchTransactionCategory(id: categoryId) else {
                throw WorkspaceAgentToolError.transactionCategoryNotFound(categoryId)
            }
            guard category.entityId == account.entityId else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
            return category
        }
        let normalizedTaxCode = taxCode?.isEmpty == false ? taxCode : nil
        guard category != nil || normalizedTaxCode != nil else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        let reviewMetadata = try proposalReviewMetadata(
            confidence: input.confidence,
            missingFields: input.missingFields,
            question: input.question,
            defaultLowConfidenceQuestion: "Which account category or tax code should this transaction use?",
            toolName: invocation.toolName
        )

        let fingerprint = "ledger.propose_mapping|\(transaction.id)"
        let existing = try storage.agentProposalRepository.fetchAgentProposal(fingerprint: fingerprint)
        let previousStatus = existing?.status
        var proposal = existing ?? AgentProposal(
            fingerprint: fingerprint,
            workspaceId: storage.manifest.workspace.id,
            agentKind: .systemHeuristics,
            proposalType: .transactionMappingReview,
            targetRef: ObjectRef(kind: .transaction, id: transaction.id.rawValue),
            relatedRef: category.map { ObjectRef(kind: .transactionCategory, id: $0.id.rawValue) }
                ?? ObjectRef(kind: .financialAccount, id: account.id.rawValue),
            summary: "",
            rationale: "",
            confidence: input.confidence,
            status: .pending,
            createdAt: nowProvider()
        )

        proposal.proposalType = .transactionMappingReview
        proposal.targetRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
        proposal.relatedRef = category.map { ObjectRef(kind: .transactionCategory, id: $0.id.rawValue) }
            ?? ObjectRef(kind: .financialAccount, id: account.id.rawValue)
        proposal.summary = "Review mapping for \(transaction.counterpartyName)"
        proposal.rationale = mappingProposalRationale(
            rationale: rationale,
            category: category,
            taxCode: normalizedTaxCode
        )
        proposal.confidence = input.confidence
        proposal.missingFields = reviewMetadata.missingFields
        proposal.question = reviewMetadata.question
        proposal.requiresManualReview = reviewMetadata.requiresManualReview
        if proposal.status != .rejected {
            proposal.status = .pending
            proposal.decidedAt = nil
            proposal.decidedBy = nil
            proposal.decisionReason = nil
        }

        try storage.agentProposalRepository.saveAgentProposal(proposal)

        if previousStatus != .pending, proposal.status == .pending {
            try auditLogger.log(
                eventType: .proposalCreated,
                objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                payload: proposal.summary
            )
        }

        var provenanceRefs = [
            ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
            ObjectRef(kind: .transaction, id: transaction.id.rawValue),
            ObjectRef(kind: .financialAccount, id: account.id.rawValue),
        ]
        if let category {
            appendUnique(ObjectRef(kind: .transactionCategory, id: category.id.rawValue), to: &provenanceRefs)
        }

        return try encodedResult(
            AgentLedgerMappingProposalOutput(
                proposal: proposal,
                transaction: transaction,
                account: account,
                category: category,
                taxCode: normalizedTaxCode
            ),
            provenanceRefs: provenanceRefs
        )
    }

    private func handleLedgerSplitProposal(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentLedgerSplitProposalInput.self, from: invocation)
        guard let transaction = try storage.transactionRepository.fetchTransactions(ids: [input.transactionId]).first else {
            throw WorkspaceAgentToolError.transactionNotFound(input.transactionId)
        }
        guard let account = try storage.financialAccountRepository.fetchFinancialAccount(id: transaction.accountId) else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let rationale = input.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...20).contains(input.lines.count),
              rationale.isEmpty == false,
              rationale.count <= 1_000,
              input.confidence >= 0,
              input.confidence <= 1
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let categoryIds = Set(input.lines.compactMap(\.categoryId))
        let categories = try categoryLookup(
            categoryIds: categoryIds,
            entityId: account.entityId,
            toolName: invocation.toolName
        )
        let normalizedLines = try normalizedSplitLines(
            input.lines,
            categories: categories,
            toolName: invocation.toolName
        )
        let totalAmountMinor = try splitTotalAmountMinor(input.lines, toolName: invocation.toolName)
        guard totalAmountMinor == transaction.amountMinor else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        let reviewMetadata = try proposalReviewMetadata(
            confidence: input.confidence,
            missingFields: input.missingFields,
            question: input.question,
            defaultLowConfidenceQuestion: "Which split lines, categories, and tax codes should be confirmed?",
            toolName: invocation.toolName
        )

        let fingerprint = "ledger.propose_split|\(transaction.id)"
        let existing = try storage.agentProposalRepository.fetchAgentProposal(fingerprint: fingerprint)
        let previousStatus = existing?.status
        var proposal = existing ?? AgentProposal(
            fingerprint: fingerprint,
            workspaceId: storage.manifest.workspace.id,
            agentKind: .systemHeuristics,
            proposalType: .transactionSplitReview,
            targetRef: ObjectRef(kind: .transaction, id: transaction.id.rawValue),
            relatedRef: ObjectRef(kind: .financialAccount, id: account.id.rawValue),
            summary: "",
            rationale: "",
            confidence: input.confidence,
            status: .pending,
            createdAt: nowProvider()
        )

        proposal.proposalType = .transactionSplitReview
        proposal.targetRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
        proposal.relatedRef = ObjectRef(kind: .financialAccount, id: account.id.rawValue)
        proposal.summary = "Review split for \(transaction.counterpartyName)"
        proposal.rationale = splitProposalRationale(
            rationale: rationale,
            lines: normalizedLines,
            currency: transaction.currency
        )
        proposal.confidence = input.confidence
        proposal.missingFields = reviewMetadata.missingFields
        proposal.question = reviewMetadata.question
        proposal.requiresManualReview = reviewMetadata.requiresManualReview
        if proposal.status != .rejected {
            proposal.status = .pending
            proposal.decidedAt = nil
            proposal.decidedBy = nil
            proposal.decisionReason = nil
        }

        try storage.agentProposalRepository.saveAgentProposal(proposal)

        if previousStatus != .pending, proposal.status == .pending {
            try auditLogger.log(
                eventType: .proposalCreated,
                objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                payload: proposal.summary
            )
        }

        var provenanceRefs = [
            ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
            ObjectRef(kind: .transaction, id: transaction.id.rawValue),
            ObjectRef(kind: .financialAccount, id: account.id.rawValue),
        ]
        for line in normalizedLines {
            if let categoryId = line.categoryId {
                appendUnique(ObjectRef(kind: .transactionCategory, id: categoryId.rawValue), to: &provenanceRefs)
            }
        }

        return try encodedResult(
            AgentLedgerSplitProposalOutput(
                proposal: proposal,
                transaction: transaction,
                account: account,
                splitLines: normalizedLines,
                totalAmountMinor: totalAmountMinor
            ),
            provenanceRefs: provenanceRefs
        )
    }

    private func handleClosingAccrualProposal(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentClosingAccrualProposalInput.self, from: invocation)
        let entity = try storage.requireEntity(entityId: input.entityId)
        let taxYear = try input.taxYearId.map { try storage.requireTaxYear(entityId: input.entityId, taxYearId: $0) }
        if let taxYear {
            guard taxYear.status == .open else {
                throw DomainError.lockedPeriod
            }
            guard input.effectiveDate >= taxYear.periodStart,
                  input.effectiveDate <= taxYear.periodEnd
            else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
        }

        let memo = input.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let rationale = input.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEntryNumber = input.entryNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...20).contains(input.lines.count),
              memo.isEmpty == false,
              memo.count <= 300,
              normalizedEntryNumber.map({ $0.count <= 64 }) ?? true,
              rationale.isEmpty == false,
              rationale.count <= 1_000,
              input.confidence >= 0,
              input.confidence <= 1
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let proposalSourceRef = try normalizedObjectRef(input.sourceRef, toolName: invocation.toolName)
        let ledgerAccounts = try storage.ledgerAccountRepository.fetchLedgerAccounts(entityId: input.entityId)
        let ledgerAccountsById = Dictionary(uniqueKeysWithValues: ledgerAccounts.map { ($0.id, $0) })
        let entryId = JournalEntryID()
        var journalLines: [JournalLine] = []
        var outputLines: [AgentClosingAccrualLineOutput] = []
        var debitTotal: Int64 = 0
        var creditTotal: Int64 = 0

        for inputLine in input.lines {
            guard let account = ledgerAccountsById[inputLine.ledgerAccountId] else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
            guard inputLine.debitMinor >= 0,
                  inputLine.creditMinor >= 0,
                  (inputLine.debitMinor > 0) != (inputLine.creditMinor > 0)
            else {
                throw DomainError.invalidJournalLine
            }

            let taxCode = try normalizedBoundedString(inputLine.taxCode, maximumCount: 64, toolName: invocation.toolName)
            let lineMemo = try normalizedBoundedString(inputLine.memo, maximumCount: 200, toolName: invocation.toolName) ?? ""
            let sourceRef = try normalizedObjectRef(inputLine.sourceRef, toolName: invocation.toolName) ?? proposalSourceRef
            let nextDebitTotal = debitTotal.addingReportingOverflow(inputLine.debitMinor)
            let nextCreditTotal = creditTotal.addingReportingOverflow(inputLine.creditMinor)
            guard nextDebitTotal.overflow == false,
                  nextCreditTotal.overflow == false
            else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
            debitTotal = nextDebitTotal.partialValue
            creditTotal = nextCreditTotal.partialValue

            journalLines.append(
                try JournalLine(
                    journalEntryId: entryId,
                    ledgerAccountId: account.id,
                    debitMinor: inputLine.debitMinor,
                    creditMinor: inputLine.creditMinor,
                    currency: input.currency,
                    taxCode: taxCode,
                    sourceObjectRef: sourceRef,
                    memo: lineMemo
                )
            )
            outputLines.append(
                AgentClosingAccrualLineOutput(
                    account: account,
                    debitMinor: inputLine.debitMinor,
                    creditMinor: inputLine.creditMinor,
                    taxCode: taxCode,
                    sourceRef: sourceRef,
                    memo: lineMemo.isEmpty ? nil : lineMemo
                )
            )
        }

        guard debitTotal == creditTotal else {
            throw DomainError.unbalancedJournalEntry
        }

        let entryNumber = normalizedEntryNumber?.isEmpty == false
            ? normalizedEntryNumber!
            : "agent-accrual-\(String(entryId.rawValue.uuidString.lowercased().prefix(8)))"
        let draftEntry = try JournalEntry(
            id: entryId,
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            entryNumber: entryNumber,
            effectiveDate: input.effectiveDate,
            kind: .manual,
            status: .draft,
            memo: memo,
            createdBy: "agent",
            lines: journalLines
        )

        let entityRef = ObjectRef(kind: .legalEntity, id: entity.id.rawValue)
        let targetRef = taxYear.map { ObjectRef(kind: .taxYear, id: $0.id.rawValue) } ?? entityRef
        let reviewMetadata = try proposalReviewMetadata(
            confidence: input.confidence,
            missingFields: input.missingFields,
            question: input.question,
            defaultLowConfidenceQuestion: "Which source evidence supports this year-end accrual?",
            toolName: invocation.toolName
        )
        let fingerprint = closingAccrualFingerprint(
            input: input,
            sourceRef: proposalSourceRef,
            lines: outputLines
        )
        let existing = try storage.agentProposalRepository.fetchAgentProposal(fingerprint: fingerprint)
        let previousStatus = existing?.status
        var proposal = existing ?? AgentProposal(
            fingerprint: fingerprint,
            workspaceId: storage.manifest.workspace.id,
            agentKind: .systemHeuristics,
            proposalType: .closingAccrualReview,
            targetRef: targetRef,
            relatedRef: proposalSourceRef,
            summary: "",
            rationale: "",
            confidence: input.confidence,
            status: .pending,
            createdAt: nowProvider()
        )

        proposal.proposalType = .closingAccrualReview
        proposal.targetRef = targetRef
        proposal.relatedRef = proposalSourceRef
        proposal.summary = closingAccrualSummary(memo: memo, taxYear: taxYear)
        proposal.rationale = closingAccrualProposalRationale(
            rationale: rationale,
            draftEntry: draftEntry,
            lines: outputLines
        )
        proposal.confidence = input.confidence
        proposal.missingFields = reviewMetadata.missingFields
        proposal.question = reviewMetadata.question
        proposal.requiresManualReview = reviewMetadata.requiresManualReview
        if proposal.status != .rejected {
            proposal.status = .pending
            proposal.decidedAt = nil
            proposal.decidedBy = nil
            proposal.decisionReason = nil
        }

        try storage.agentProposalRepository.saveAgentProposal(proposal)

        if previousStatus != .pending, proposal.status == .pending {
            try auditLogger.log(
                eventType: .proposalCreated,
                objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                payload: proposal.summary
            )
        }

        var provenanceRefs = [
            ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
            entityRef,
        ]
        if let taxYear {
            appendUnique(ObjectRef(kind: .taxYear, id: taxYear.id.rawValue), to: &provenanceRefs)
        }
        if let proposalSourceRef {
            appendUnique(proposalSourceRef, to: &provenanceRefs)
        }
        for line in outputLines {
            appendUnique(ObjectRef(kind: .ledgerAccount, id: line.ledgerAccount.ledgerAccountId.rawValue), to: &provenanceRefs)
            if let sourceRef = line.sourceRef {
                appendUnique(sourceRef, to: &provenanceRefs)
            }
        }

        return try encodedResult(
            AgentClosingAccrualProposalOutput(
                proposal: proposal,
                draftEntry: AgentClosingAccrualDraftEntryOutput(
                    entry: draftEntry,
                    currency: input.currency,
                    lines: outputLines
                )
            ),
            provenanceRefs: provenanceRefs
        )
    }

    private func handleEntitiesMergeCounterparties(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentCounterpartyMergeInput.self, from: invocation)
        guard let confirmation = invocation.confirmation else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        guard let approvedBy = try normalizedBoundedString(
            confirmation.approvedBy,
            maximumCount: 128,
            toolName: invocation.toolName
        ),
            let approvalReason = try normalizedBoundedString(
                confirmation.reason,
                maximumCount: 500,
                toolName: invocation.toolName
            )
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        _ = try storage.requireEntity(entityId: input.entityId)
        let source = try storage.requireCounterparty(
            entityId: input.entityId,
            counterpartyId: input.sourceCounterpartyId
        )
        let target = try storage.requireCounterparty(
            entityId: input.entityId,
            counterpartyId: input.targetCounterpartyId
        )
        guard source.id != target.id,
              source.status == .active,
              target.status == .active
        else {
            throw DomainError.invalidCounterpartyMerge
        }

        var proposal: AgentProposal?
        if let proposalId = input.proposalId {
            guard var loadedProposal = try storage.agentProposalRepository.fetchAgentProposal(id: proposalId) else {
                throw DomainError.proposalNotFound
            }
            guard loadedProposal.proposalType == .counterpartyMergeReview,
                  loadedProposal.status == .pending,
                  loadedProposal.targetRef == ObjectRef(kind: .counterparty, id: input.sourceCounterpartyId.rawValue),
                  loadedProposal.relatedRef == ObjectRef(kind: .counterparty, id: input.targetCounterpartyId.rawValue)
            else {
                throw DomainError.invalidProposal
            }
            loadedProposal.status = .resolved
            loadedProposal.decidedAt = confirmation.approvedAt
            loadedProposal.decidedBy = approvedBy
            loadedProposal.decisionReason = approvalReason
            proposal = loadedProposal
        }

        let result = try storage.counterpartyRepository.mergeCounterparty(
            sourceId: input.sourceCounterpartyId,
            targetId: input.targetCounterpartyId,
            approvedAt: confirmation.approvedAt
        )

        if let proposal {
            try storage.agentProposalRepository.saveAgentProposal(proposal)
            try auditLogger.log(
                actorType: .user,
                actorId: approvedBy,
                eventType: .proposalResolved,
                objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                payload: approvalReason
            )
        }
        try auditLogger.log(
            actorType: .user,
            actorId: approvedBy,
            eventType: .counterpartyMerged,
            objectRef: ObjectRef(kind: .counterparty, id: result.source.id.rawValue),
            payload: approvalReason
        )

        var provenanceRefs = [
            ObjectRef(kind: .legalEntity, id: input.entityId.rawValue),
            ObjectRef(kind: .counterparty, id: result.source.id.rawValue),
            ObjectRef(kind: .counterparty, id: result.target.id.rawValue),
        ]
        if let proposal {
            appendUnique(ObjectRef(kind: .agentProposal, id: proposal.id.rawValue), to: &provenanceRefs)
        }

        return try encodedResult(
            AgentCounterpartyMergeOutput(
                result: result,
                approvalReason: approvalReason
            ),
            provenanceRefs: provenanceRefs
        )
    }

    private func handleLedgerApplyDraftEntry(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentLedgerApplyDraftEntryInput.self, from: invocation)
        guard let confirmation = invocation.confirmation else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        guard let approvedBy = try normalizedBoundedString(
            confirmation.approvedBy,
            maximumCount: 128,
            toolName: invocation.toolName
        ),
            let approvalReason = try normalizedBoundedString(
                confirmation.reason,
                maximumCount: 500,
                toolName: invocation.toolName
            ),
            let entryNumber = try normalizedBoundedString(
                input.entryNumber,
                maximumCount: 64,
                toolName: invocation.toolName
            ),
            let memo = try normalizedBoundedString(
                input.memo,
                maximumCount: 300,
                toolName: invocation.toolName
            )
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let entity = try storage.requireEntity(entityId: input.entityId)
        let taxYear = try storage.requireTaxYear(entityId: input.entityId, taxYearId: input.taxYearId)
        guard taxYear.status == .open else {
            throw DomainError.lockedPeriod
        }
        guard input.effectiveDate >= taxYear.periodStart,
              input.effectiveDate <= taxYear.periodEnd
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        guard try storage.journalEntryRepository
            .fetchJournalEntry(entityId: input.entityId, entryNumber: entryNumber) == nil
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let ledgerAccounts = try storage.ledgerAccountRepository.fetchLedgerAccounts(entityId: input.entityId)
        let ledgerAccountsById = Dictionary(uniqueKeysWithValues: ledgerAccounts.map { ($0.id, $0) })
        let entryId = JournalEntryID()
        var lines: [JournalLine] = []
        var outputLines: [AgentJournalLineToolOutput] = []
        var debitTotal: Int64 = 0
        var creditTotal: Int64 = 0

        guard (2...50).contains(input.lines.count) else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        for inputLine in input.lines {
            guard let account = ledgerAccountsById[inputLine.ledgerAccountId] else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
            guard inputLine.debitMinor >= 0,
                  inputLine.creditMinor >= 0,
                  (inputLine.debitMinor > 0) != (inputLine.creditMinor > 0)
            else {
                throw DomainError.invalidJournalLine
            }
            let taxCode = try normalizedBoundedString(inputLine.taxCode, maximumCount: 64, toolName: invocation.toolName)
            let lineMemo = try normalizedBoundedString(inputLine.memo, maximumCount: 200, toolName: invocation.toolName) ?? ""
            let sourceRef = try normalizedObjectRef(inputLine.sourceRef, toolName: invocation.toolName)
            let nextDebitTotal = debitTotal.addingReportingOverflow(inputLine.debitMinor)
            let nextCreditTotal = creditTotal.addingReportingOverflow(inputLine.creditMinor)
            guard nextDebitTotal.overflow == false,
                  nextCreditTotal.overflow == false
            else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
            debitTotal = nextDebitTotal.partialValue
            creditTotal = nextCreditTotal.partialValue

            let line = try JournalLine(
                journalEntryId: entryId,
                ledgerAccountId: account.id,
                debitMinor: inputLine.debitMinor,
                creditMinor: inputLine.creditMinor,
                currency: input.currency,
                taxCode: taxCode,
                sourceObjectRef: sourceRef,
                memo: lineMemo
            )
            lines.append(line)
            outputLines.append(AgentJournalLineToolOutput(line: line, account: account))
        }

        guard debitTotal == creditTotal else {
            throw DomainError.unbalancedJournalEntry
        }

        var proposal: AgentProposal?
        if let proposalId = input.proposalId {
            guard var loadedProposal = try storage.agentProposalRepository.fetchAgentProposal(id: proposalId) else {
                throw DomainError.proposalNotFound
            }
            guard loadedProposal.proposalType == .closingAccrualReview,
                  loadedProposal.status == .pending,
                  loadedProposal.targetRef == ObjectRef(kind: .taxYear, id: input.taxYearId.rawValue)
            else {
                throw DomainError.invalidProposal
            }
            loadedProposal.status = .resolved
            loadedProposal.decidedAt = confirmation.approvedAt
            loadedProposal.decidedBy = approvedBy
            loadedProposal.decisionReason = approvalReason
            proposal = loadedProposal
        }

        let entry = try JournalEntry(
            id: entryId,
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            entryNumber: entryNumber,
            effectiveDate: input.effectiveDate,
            kind: .manual,
            status: .posted,
            memo: memo,
            createdBy: "agent",
            approvedBy: approvedBy,
            approvedAt: confirmation.approvedAt,
            lines: lines
        )

        try storage.journalEntryRepository.saveJournalEntry(entry)
        try auditLogger.log(
            actorType: .user,
            actorId: approvedBy,
            eventType: .journalEntryPosted,
            objectRef: ObjectRef(kind: .journalEntry, id: entry.id.rawValue),
            payload: approvalReason
        )

        if let resolvedProposal = proposal {
            try storage.agentProposalRepository.saveAgentProposal(resolvedProposal)
            try auditLogger.log(
                actorType: .user,
                actorId: approvedBy,
                eventType: .proposalResolved,
                objectRef: ObjectRef(kind: .agentProposal, id: resolvedProposal.id.rawValue),
                payload: resolvedProposal.summary
            )
        }

        var provenanceRefs = [
            ObjectRef(kind: .journalEntry, id: entry.id.rawValue),
            ObjectRef(kind: .legalEntity, id: entity.id.rawValue),
            ObjectRef(kind: .taxYear, id: taxYear.id.rawValue),
        ]
        if let proposal {
            appendUnique(ObjectRef(kind: .agentProposal, id: proposal.id.rawValue), to: &provenanceRefs)
        }
        for line in entry.lines {
            appendUnique(ObjectRef(kind: .journalLine, id: line.id.rawValue), to: &provenanceRefs)
            appendUnique(ObjectRef(kind: .ledgerAccount, id: line.ledgerAccountId.rawValue), to: &provenanceRefs)
            if let sourceRef = line.sourceObjectRef {
                appendUnique(sourceRef, to: &provenanceRefs)
            }
        }

        return try encodedResult(
            AgentLedgerApplyDraftEntryOutput(
                entry: entry,
                lines: outputLines,
                proposal: proposal,
                approvedBy: approvedBy,
                approvedAt: confirmation.approvedAt,
                approvalReason: approvalReason
            ),
            provenanceRefs: provenanceRefs
        )
    }

    private func handleExportGeneratePackage(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentExportGeneratePackageInput.self, from: invocation)
        let exportFormat = input.exportFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.exportFormat == exportFormat,
              exportFormat.isEmpty == false,
              exportFormat.count <= 64,
              exportPackageMetadataIsBounded(input)
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        _ = try storage.requireEntity(entityId: input.entityId)
        _ = try storage.requireTaxYear(entityId: input.entityId, taxYearId: input.taxYearId)
        if let vatPeriodId = input.vatPeriodId {
            let vatPeriod = try storage.requireVATPeriod(vatPeriodId: vatPeriodId)
            guard vatPeriod.entityId == input.entityId else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
        }
        guard let exportPackageProvider else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let providerResult = try exportPackageProvider(input)
        guard providerResult.artifactData.isEmpty == false,
              providerResult.artifactFilename.trimmingCharacters(in: .whitespacesAndNewlines) == providerResult.artifactFilename,
              providerResult.artifactFilename.isEmpty == false,
              providerResult.artifactFilename.count <= 200,
              providerResult.mediaType.trimmingCharacters(in: .whitespacesAndNewlines) == providerResult.mediaType,
              providerResult.mediaType.isEmpty == false,
              providerResult.mediaType.count <= 100,
              providerResult.schemaVersion.map({ $0.isEmpty == false && $0.count <= 64 }) ?? true,
              providerResult.issues.contains(where: { $0.severity == .blocker }) == false
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let artifactHash = try storage.blobStore.store(data: providerResult.artifactData)
        let now = nowProvider()
        let filingPackage = FilingPackage(
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            status: .generated,
            generatedAt: now,
            submittedAt: nil,
            snapshotHash: artifactHash,
            exportFormat: exportFormat,
            createdAt: now,
            updatedAt: now
        )
        try storage.filingPackageRepository.saveFilingPackage(filingPackage)

        return try encodedResult(
            AgentExportPackageToolOutput(
                input: input,
                filingPackage: filingPackage,
                providerResult: providerResult,
                artifactHash: artifactHash
            ),
            provenanceRefs: exportPackageProvenanceRefs(
                input: input,
                filingPackage: filingPackage,
                providerResult: providerResult
            )
        )
    }

    private func handleExportFinalizePackage(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentExportFinalizePackageInput.self, from: invocation)
        guard let confirmation = invocation.confirmation else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        guard let approvedBy = try normalizedBoundedString(
            confirmation.approvedBy,
            maximumCount: 128,
            toolName: invocation.toolName
        ),
            let approvalReason = try normalizedBoundedString(
                confirmation.reason,
                maximumCount: 500,
                toolName: invocation.toolName
            ),
            let expectedSnapshotHash = try normalizedBoundedString(
                input.expectedSnapshotHash,
                maximumCount: 128,
                toolName: invocation.toolName
            )
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        _ = try storage.requireEntity(entityId: input.entityId)
        let taxYear = try storage.requireTaxYear(entityId: input.entityId, taxYearId: input.taxYearId)
        guard taxYear.status != .filed else {
            throw DomainError.lockedPeriod
        }
        guard var filingPackage = try storage.filingPackageRepository
            .fetchFilingPackage(id: input.filingPackageId)
        else {
            throw WorkspaceAgentToolError.filingPackageNotFound(input.filingPackageId)
        }
        guard filingPackage.entityId == input.entityId,
              filingPackage.taxYearId == input.taxYearId,
              filingPackage.status == .generated,
              filingPackage.submittedAt == nil,
              filingPackage.finalizedAt == nil,
              filingPackage.finalizedBy == nil,
              let snapshotHash = filingPackage.snapshotHash,
              snapshotHash == expectedSnapshotHash
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        do {
            _ = try storage.blobStore.read(hash: snapshotHash)
        } catch {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        filingPackage.status = .finalized
        filingPackage.finalizedAt = confirmation.approvedAt
        filingPackage.finalizedBy = approvedBy
        filingPackage.updatedAt = nowProvider()
        try storage.filingPackageRepository.saveFilingPackage(filingPackage)
        try auditLogger.log(
            actorType: .user,
            actorId: approvedBy,
            eventType: .filingPackageFinalized,
            objectRef: ObjectRef(kind: .filingPackage, id: filingPackage.id.rawValue),
            payload: approvalReason
        )

        return try encodedResult(
            AgentExportFinalizePackageOutput(
                filingPackage: filingPackage,
                approvedBy: approvedBy,
                approvedAt: confirmation.approvedAt,
                approvalReason: approvalReason
            ),
            provenanceRefs: exportFinalizePackageProvenanceRefs(
                entityId: input.entityId,
                taxYearId: input.taxYearId,
                filingPackageId: filingPackage.id
            )
        )
    }

    private func handleExportValidate(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentExportValidateInput.self, from: invocation)
        let exportFormat = input.exportFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.exportFormat == exportFormat,
              exportFormat.isEmpty == false,
              exportFormat.count <= 64,
              exportValidationMetadataIsBounded(input)
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        _ = try storage.requireEntity(entityId: input.entityId)
        if let taxYearId = input.taxYearId {
            _ = try storage.requireTaxYear(entityId: input.entityId, taxYearId: taxYearId)
        }
        if let vatPeriodId = input.vatPeriodId {
            let vatPeriod = try storage.requireVATPeriod(vatPeriodId: vatPeriodId)
            guard vatPeriod.entityId == input.entityId else {
                throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
            }
        }
        guard let exportValidationProvider else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }

        let providerResult = try exportValidationProvider(input)
        let output = AgentExportValidationToolOutput(input: input, providerResult: providerResult)
        return try encodedResult(
            output,
            provenanceRefs: exportValidationProvenanceRefs(input: input, issues: providerResult.issues)
        )
    }

    private func handleIssueOpenOrUpdate(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentIssueOpenOrUpdateInput.self, from: invocation)
        guard let fingerprint = try normalizedBoundedString(
            input.fingerprint,
            maximumCount: 512,
            toolName: invocation.toolName
        ),
            let summary = try normalizedBoundedString(
                input.summary,
                maximumCount: 1_000,
                toolName: invocation.toolName
            )
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        try validateIssueScope(
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            toolName: invocation.toolName
        )
        let objectRef = try validatedIssueReference(
            input.objectRef,
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            toolName: invocation.toolName
        )
        let relatedRef = try validatedIssueReference(
            input.relatedRef,
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            toolName: invocation.toolName
        )

        let issueService = IssueService(storage: storage, auditLogger: auditLogger)
        let issue = try issueService.syncIssue(
            fingerprint: fingerprint,
            entityId: input.entityId,
            taxYearId: input.taxYearId,
            code: input.issueCode,
            severity: input.severity,
            status: input.status ?? .open,
            summary: summary,
            objectRef: objectRef,
            relatedRef: relatedRef,
            now: nowProvider()
        )
        var provenanceRefs = [
            ObjectRef(kind: .issue, id: issue.id.rawValue),
            issue.objectRef,
        ]
        if let relatedRef = issue.relatedRef {
            appendUnique(relatedRef, to: &provenanceRefs)
        }
        return try encodedResult(
            AgentIssueToolOutput(issue: issue),
            provenanceRefs: provenanceRefs
        )
    }

    private func handleDocumentMatchProposal(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let input = try decode(AgentDocumentMatchProposalInput.self, from: invocation)
        guard let document = try storage.documentRepository.fetchDocument(id: input.documentId) else {
            throw WorkspaceAgentToolError.documentNotFound(input.documentId)
        }
        guard document.status == .active else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        guard let transaction = try storage.transactionRepository.fetchTransactions(ids: [input.transactionId]).first else {
            throw WorkspaceAgentToolError.transactionNotFound(input.transactionId)
        }
        guard let account = try storage.financialAccountRepository.fetchFinancialAccount(id: transaction.accountId),
              document.entityId.map({ $0 == account.entityId }) ?? true
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        let trimmedRationale = input.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedRationale.isEmpty == false,
              input.confidence >= 0,
              input.confidence <= 1
        else {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
        let reviewMetadata = try proposalReviewMetadata(
            confidence: input.confidence,
            missingFields: input.missingFields,
            question: input.question,
            defaultLowConfidenceQuestion: "Does this document actually support the selected transaction?",
            toolName: invocation.toolName
        )

        let fingerprint = "docs.propose_match|\(document.id)|\(transaction.id)"
        let existing = try storage.agentProposalRepository.fetchAgentProposal(fingerprint: fingerprint)
        let previousStatus = existing?.status
        var proposal = existing ?? AgentProposal(
            fingerprint: fingerprint,
            workspaceId: storage.manifest.workspace.id,
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: ObjectRef(kind: .document, id: document.id.rawValue),
            relatedRef: ObjectRef(kind: .transaction, id: transaction.id.rawValue),
            summary: "",
            rationale: "",
            confidence: input.confidence,
            status: .pending,
            createdAt: nowProvider()
        )

        proposal.summary = "Review match between \(document.originalFilename) and \(transaction.counterpartyName)"
        proposal.rationale = trimmedRationale
        proposal.confidence = input.confidence
        proposal.targetRef = ObjectRef(kind: .document, id: document.id.rawValue)
        proposal.relatedRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
        proposal.missingFields = reviewMetadata.missingFields
        proposal.question = reviewMetadata.question
        proposal.requiresManualReview = reviewMetadata.requiresManualReview
        if proposal.status != .rejected {
            proposal.status = .pending
            proposal.decidedAt = nil
            proposal.decidedBy = nil
            proposal.decisionReason = nil
        }

        try storage.agentProposalRepository.saveAgentProposal(proposal)

        if previousStatus != .pending, proposal.status == .pending {
            try auditLogger.log(
                eventType: .proposalCreated,
                objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                payload: proposal.summary
            )
        }

        return try encodedResult(
            AgentProposalToolOutput(proposal: proposal),
            provenanceRefs: [
                ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                ObjectRef(kind: .document, id: document.id.rawValue),
                ObjectRef(kind: .transaction, id: transaction.id.rawValue),
                ObjectRef(kind: .financialAccount, id: account.id.rawValue),
            ]
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from invocation: AgentToolInvocation) throws -> T {
        do {
            return try JSONDecoder.alpenLedger.decode(T.self, from: invocation.inputJSON)
        } catch {
            throw WorkspaceAgentToolError.invalidInput(invocation.toolName)
        }
    }

    private func encodedResult<T: Encodable>(
        _ output: T,
        provenanceRefs: [ObjectRef]
    ) throws -> AgentToolExecutionResult {
        AgentToolExecutionResult(
            outputJSON: try JSONEncoder.alpenLedger.encode(output),
            provenanceRefs: provenanceRefs
        )
    }

    private func logAgentToolAudit(
        invocation: AgentToolInvocation,
        outcome: AgentToolAuditOutcome,
        result: AgentToolExecutionResult?,
        error: Error?,
        startedAt: Date,
        finishedAt: Date
    ) throws {
        let definition = registry.definition(named: invocation.toolName)
        let payload = AgentToolAuditPayload(
            toolName: invocation.toolName,
            outcome: outcome,
            sideEffect: definition?.sideEffect,
            requiredScopes: sortedScopes(definition?.requiredScopes ?? []),
            grantedScopes: sortedScopes(invocation.grantedScopes),
            inputHash: invocation.inputHash,
            confirmationInputHash: invocation.confirmation?.approvedInputHash,
            confirmationProvided: invocation.confirmation != nil,
            provenanceRefs: result?.provenanceRefs ?? [],
            errorCode: error.map(agentToolAuditErrorCode),
            durationMilliseconds: max(0, Int(finishedAt.timeIntervalSince(startedAt) * 1_000))
        )
        let eventType: AuditEventType = outcome == .executed ? .agentToolExecuted : .agentToolRejected
        try auditLogger.log(
            eventType: eventType,
            objectRef: ObjectRef(kind: .workspace, id: storage.manifest.workspace.id.rawValue),
            payload: String(data: try JSONEncoder.alpenLedger.encode(payload), encoding: .utf8)
        )
    }

    private func sortedScopes(_ scopes: Set<AgentToolScope>) -> [AgentToolScope] {
        scopes.sorted { $0.rawValue < $1.rawValue }
    }

    private func agentToolAuditErrorCode(_ error: Error) -> String {
        switch error {
        case AgentToolExecutionError.unsafeRegistry(_):
            return "unsafeRegistry"
        case AgentToolExecutionError.unregisteredTool(_):
            return "unregisteredTool"
        case AgentToolExecutionError.missingScopes(_, _, _):
            return "missingScopes"
        case AgentToolExecutionError.confirmationRequired(_):
            return "confirmationRequired"
        case AgentToolExecutionError.invalidConfirmation(_):
            return "invalidConfirmation"
        case AgentToolExecutionError.missingResultProvenance(_):
            return "missingResultProvenance"
        case WorkspaceAgentToolError.invalidInput(_):
            return "invalidInput"
        case WorkspaceAgentToolError.documentNotFound(_):
            return "documentNotFound"
        case WorkspaceAgentToolError.transactionNotFound(_):
            return "transactionNotFound"
        case WorkspaceAgentToolError.transactionCategoryNotFound(_):
            return "transactionCategoryNotFound"
        case WorkspaceAgentToolError.taxFactNotFound(_):
            return "taxFactNotFound"
        case WorkspaceAgentToolError.filingPackageNotFound(_):
            return "filingPackageNotFound"
        case DomainError.lockedPeriod:
            return "lockedPeriod"
        case DomainError.entityNotFound:
            return "entityNotFound"
        case DomainError.counterpartyNotFound:
            return "counterpartyNotFound"
        case DomainError.invalidCounterpartyMerge:
            return "invalidCounterpartyMerge"
        case DomainError.taxYearNotFound:
            return "taxYearNotFound"
        case DomainError.vatPeriodNotFound:
            return "vatPeriodNotFound"
        case DomainError.invalidJournalLine:
            return "invalidJournalLine"
        case DomainError.unbalancedJournalEntry:
            return "unbalancedJournalEntry"
        case DomainError.invalidOverrideReason:
            return "invalidOverrideReason"
        case DomainError.taxFactNotFound:
            return "taxFactNotFound"
        case DomainError.proposalNotFound:
            return "proposalNotFound"
        case DomainError.invalidProposal:
            return "invalidProposal"
        default:
            return "unexpectedError"
        }
    }

    private func normalizedLimit(_ limit: Int?, toolName: String) throws -> Int {
        let value = limit ?? 50
        guard (1...100).contains(value) else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return value
    }

    private func normalizedSnippetLimit(_ limit: Int?, toolName: String) throws -> Int {
        let value = limit ?? 280
        guard (1...1_000).contains(value) else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return value
    }

    private func normalizedQuery(_ query: String?, toolName: String) throws -> String {
        let value = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count <= 200 else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return value
    }

    private func boundedAuditPayload(_ payload: String?) -> String? {
        guard let payload else {
            return nil
        }
        let value = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else {
            return nil
        }
        guard value.count > 240 else {
            return value
        }
        return "\(value.prefix(240))..."
    }

    private func scopedAccounts(
        entityId: LegalEntityID,
        accountId: FinancialAccountID?,
        toolName: String
    ) throws -> [FinancialAccount] {
        _ = try storage.requireEntity(entityId: entityId)
        let accounts = try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entityId)
        guard let accountId else {
            return accounts
        }
        guard let account = accounts.first(where: { $0.id == accountId }) else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return [account]
    }

    private func exportValidationMetadataIsBounded(_ input: AgentExportValidateInput) -> Bool {
        let boundedStrings = [
            input.uid,
            input.organisationName,
            input.businessReferenceId,
            input.applicationProductVersion,
        ]
        guard boundedStrings.allSatisfy({ value in
            guard let value else { return true }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return value == trimmed && value.count <= 200
        }) else {
            return false
        }
        if let typeOfSubmission = input.typeOfSubmission, (1...10).contains(typeOfSubmission) == false {
            return false
        }
        if let formOfReporting = input.formOfReporting, (1...10).contains(formOfReporting) == false {
            return false
        }
        return true
    }

    private func exportPackageMetadataIsBounded(_ input: AgentExportGeneratePackageInput) -> Bool {
        let boundedStrings = [
            input.uid,
            input.organisationName,
            input.businessReferenceId,
            input.applicationProductVersion,
        ]
        guard boundedStrings.allSatisfy({ value in
            guard let value else { return true }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return value == trimmed && value.count <= 200
        }) else {
            return false
        }
        if let typeOfSubmission = input.typeOfSubmission, (1...10).contains(typeOfSubmission) == false {
            return false
        }
        if let formOfReporting = input.formOfReporting, (1...10).contains(formOfReporting) == false {
            return false
        }
        return true
    }

    private func exportValidationProvenanceRefs(
        input: AgentExportValidateInput,
        issues: [AgentExportValidationIssueToolOutput]
    ) -> [ObjectRef] {
        var refs = [ObjectRef(kind: .legalEntity, id: input.entityId.rawValue)]
        if let taxYearId = input.taxYearId {
            appendUnique(ObjectRef(kind: .taxYear, id: taxYearId.rawValue), to: &refs)
        }
        if let vatPeriodId = input.vatPeriodId {
            appendUnique(ObjectRef(kind: .vatPeriod, id: vatPeriodId.rawValue), to: &refs)
        }
        for issue in issues {
            if let sourceRef = issue.sourceRef {
                appendUnique(sourceRef, to: &refs)
            }
        }
        return refs
    }

    private func exportPackageProvenanceRefs(
        input: AgentExportGeneratePackageInput,
        filingPackage: FilingPackage,
        providerResult: AgentExportPackageProviderResult
    ) -> [ObjectRef] {
        var refs = [
            ObjectRef(kind: .filingPackage, id: filingPackage.id.rawValue),
            ObjectRef(kind: .legalEntity, id: input.entityId.rawValue),
            ObjectRef(kind: .taxYear, id: input.taxYearId.rawValue),
        ]
        if let vatPeriodId = input.vatPeriodId {
            appendUnique(ObjectRef(kind: .vatPeriod, id: vatPeriodId.rawValue), to: &refs)
        }
        for sourceRef in providerResult.sourceRefs {
            appendUnique(sourceRef, to: &refs)
        }
        for issue in providerResult.issues {
            if let sourceRef = issue.sourceRef {
                appendUnique(sourceRef, to: &refs)
            }
        }
        return refs
    }

    private func exportFinalizePackageProvenanceRefs(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        filingPackageId: FilingPackageID
    ) -> [ObjectRef] {
        [
            ObjectRef(kind: .filingPackage, id: filingPackageId.rawValue),
            ObjectRef(kind: .legalEntity, id: entityId.rawValue),
            ObjectRef(kind: .taxYear, id: taxYearId.rawValue),
        ]
    }

    private func taxOverrideAcceptanceProvenanceRefs(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        fact: TaxFact,
        proposal: AgentProposal?
    ) -> [ObjectRef] {
        var refs = [
            ObjectRef(kind: .legalEntity, id: entityId.rawValue),
            ObjectRef(kind: .taxYear, id: taxYearId.rawValue),
            ObjectRef(kind: .taxFact, id: fact.id.rawValue),
        ]
        if let proposal {
            appendUnique(ObjectRef(kind: .agentProposal, id: proposal.id.rawValue), to: &refs)
        }
        for sourceRef in fact.provenanceRefs {
            appendUnique(sourceRef, to: &refs)
        }
        return refs
    }

    private func categoryLookup(
        categoryIds: Set<TransactionCategoryID>,
        entityId: LegalEntityID,
        toolName: String
    ) throws -> [TransactionCategoryID: TransactionCategory] {
        var categories: [TransactionCategoryID: TransactionCategory] = [:]
        for categoryId in categoryIds {
            guard let category = try storage.categoryRepository.fetchTransactionCategory(id: categoryId) else {
                throw WorkspaceAgentToolError.transactionCategoryNotFound(categoryId)
            }
            guard category.entityId == entityId else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            categories[category.id] = category
        }
        return categories
    }

    private func normalizedSplitLines(
        _ lines: [AgentLedgerSplitLineInput],
        categories: [TransactionCategoryID: TransactionCategory],
        toolName: String
    ) throws -> [AgentLedgerSplitLineOutput] {
        try lines.map { line in
            guard line.amountMinor != 0 else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            let memo = line.memo?.trimmingCharacters(in: .whitespacesAndNewlines)
            let taxCode = line.taxCode?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard memo.map({ $0.count <= 200 }) ?? true,
                  taxCode.map({ $0.count <= 64 }) ?? true
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            let category = try line.categoryId.map { categoryId in
                guard let category = categories[categoryId] else {
                    throw WorkspaceAgentToolError.transactionCategoryNotFound(categoryId)
                }
                return category
            }
            return AgentLedgerSplitLineOutput(
                input: line,
                category: category,
                taxCode: taxCode?.isEmpty == false ? taxCode : nil,
                memo: memo?.isEmpty == false ? memo : nil
            )
        }
    }

    private func splitTotalAmountMinor(
        _ lines: [AgentLedgerSplitLineInput],
        toolName: String
    ) throws -> Int64 {
        var total: Int64 = 0
        for line in lines {
            let result = total.addingReportingOverflow(line.amountMinor)
            guard result.overflow == false else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            total = result.partialValue
        }
        return total
    }

    private func splitProposalRationale(
        rationale: String,
        lines: [AgentLedgerSplitLineOutput],
        currency: CurrencyCode
    ) -> String {
        var parts = [rationale, "Proposed split lines:"]
        for (index, line) in lines.enumerated() {
            let category = line.categoryCode ?? "uncategorized"
            let taxCode = line.taxCode ?? "none"
            let memo = line.memo.map { "; memo \($0)" } ?? ""
            parts.append(
                "\(index + 1). \(line.amountMinor) minor \(currency.rawValue); category \(category); taxCode \(taxCode)\(memo)"
            )
        }
        return parts.joined(separator: "\n")
    }

    private func normalizedBoundedString(
        _ value: String?,
        maximumCount: Int,
        toolName: String
    ) throws -> String? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count <= maximumCount else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return normalized.isEmpty ? nil : normalized
    }

    private struct AgentProposalReviewMetadata {
        let missingFields: [String]
        let question: String?
        let requiresManualReview: Bool
    }

    private func proposalReviewMetadata(
        confidence: Double,
        missingFields: [String]?,
        question: String?,
        defaultLowConfidenceQuestion: String,
        toolName: String
    ) throws -> AgentProposalReviewMetadata {
        var normalizedMissingFields: [String] = []
        let suppliedMissingFields = missingFields ?? []
        guard suppliedMissingFields.count <= 10 else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        for missingField in suppliedMissingFields {
            guard let normalized = try normalizedBoundedString(
                missingField,
                maximumCount: 80,
                toolName: toolName
            ) else {
                continue
            }
            if normalizedMissingFields.contains(normalized) == false {
                normalizedMissingFields.append(normalized)
            }
        }

        var normalizedQuestion = try normalizedBoundedString(
            question,
            maximumCount: 300,
            toolName: toolName
        )
        if confidence < 0.50 {
            if normalizedMissingFields.isEmpty {
                normalizedMissingFields = ["reviewer confirmation"]
            }
            if normalizedQuestion == nil {
                normalizedQuestion = defaultLowConfidenceQuestion
            }
        }

        return AgentProposalReviewMetadata(
            missingFields: normalizedMissingFields,
            question: normalizedQuestion,
            requiresManualReview: confidence < 0.50 || normalizedMissingFields.isEmpty == false || normalizedQuestion != nil
        )
    }

    private func normalizedObjectRef(_ sourceRef: ObjectRef?, toolName: String) throws -> ObjectRef? {
        guard let sourceRef else {
            return nil
        }
        let normalizedId = sourceRef.id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedId.isEmpty == false,
              normalizedId == sourceRef.id,
              normalizedId.count <= 128
        else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return sourceRef
    }

    private func validateIssueScope(
        entityId: LegalEntityID?,
        taxYearId: TaxYearID?,
        toolName: String
    ) throws {
        guard let entityId else {
            if taxYearId != nil {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return
        }

        _ = try issueLegalEntity(entityId, toolName: toolName)
        if let taxYearId {
            let scope = try issueTaxYearScope(taxYearId, toolName: toolName)
            guard scope.entityId == entityId else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
        }
    }

    private func validatedIssueReference(
        _ sourceRef: ObjectRef,
        entityId: LegalEntityID?,
        taxYearId: TaxYearID?,
        toolName: String
    ) throws -> ObjectRef {
        guard let ref = try validatedIssueReference(
            Optional(sourceRef),
            entityId: entityId,
            taxYearId: taxYearId,
            toolName: toolName
        ) else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return ref
    }

    private func validatedIssueReference(
        _ sourceRef: ObjectRef?,
        entityId: LegalEntityID?,
        taxYearId: TaxYearID?,
        toolName: String
    ) throws -> ObjectRef? {
        guard let ref = try normalizedObjectRef(sourceRef, toolName: toolName) else {
            return nil
        }
        try validateIssueReferenceScope(
            ref,
            entityId: entityId,
            taxYearId: taxYearId,
            toolName: toolName
        )
        return ref
    }

    private func validatedAuditTraceReference(
        _ sourceRef: ObjectRef,
        entityId: LegalEntityID?,
        toolName: String
    ) throws -> ObjectRef {
        guard let ref = try normalizedObjectRef(sourceRef, toolName: toolName) else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        if let entityId {
            _ = try issueLegalEntity(entityId, toolName: toolName)
        }
        var visitedRefs = Set<ObjectRef>()
        let targetEntityId = try auditTraceEntityId(for: ref, toolName: toolName, visitedRefs: &visitedRefs)
        if let entityId {
            guard targetEntityId == entityId else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
        } else if targetEntityId != nil {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return ref
    }

    private func auditTraceEntityId(
        for ref: ObjectRef,
        toolName: String,
        visitedRefs: inout Set<ObjectRef>
    ) throws -> LegalEntityID? {
        guard visitedRefs.insert(ref).inserted else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        defer {
            visitedRefs.remove(ref)
        }

        switch ref.kind {
        case .workspace:
            let workspaceId = WorkspaceID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard workspaceId == storage.manifest.workspace.id else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return nil
        case .legalEntity:
            let entityId = LegalEntityID(rawValue: try issueUUID(from: ref, toolName: toolName))
            _ = try issueLegalEntity(entityId, toolName: toolName)
            return entityId
        case .taxYear:
            let taxYearId = TaxYearID(rawValue: try issueUUID(from: ref, toolName: toolName))
            return try issueTaxYearScope(taxYearId, toolName: toolName).entityId
        case .financialAccount:
            return try issueFinancialAccount(ref, toolName: toolName).entityId
        case .counterparty:
            let counterpartyId = CounterpartyID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let counterparty = try storage.counterpartyRepository.fetchCounterparty(id: counterpartyId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return counterparty.entityId
        case .transaction:
            return try issueTransactionScope(ref, toolName: toolName).account.entityId
        case .document:
            let documentId = DocumentID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let document = try storage.documentRepository.fetchDocument(id: documentId),
                  document.workspaceId == storage.manifest.workspace.id
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return document.entityId
        case .requirement:
            let requirementId = RequirementID(rawValue: try issueUUID(from: ref, toolName: toolName))
            return try issueRequirement(requirementId, entityId: nil, toolName: toolName).entityId
        case .taxFact:
            let factId = TaxFactID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let fact = try storage.taxFactRepository.fetchTaxFact(id: factId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return fact.entityId
        case .vatPeriod:
            let vatPeriodId = VATPeriodID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let period = try storage.vatPeriodRepository.fetchVATPeriod(id: vatPeriodId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return period.entityId
        case .ledgerAccount:
            let accountId = LedgerAccountID(rawValue: try issueUUID(from: ref, toolName: toolName))
            return try issueLedgerAccount(accountId, entityId: nil, toolName: toolName).entityId
        case .journalEntry:
            let entryId = JournalEntryID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let entry = try storage.journalEntryRepository.fetchJournalEntry(id: entryId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return entry.entityId
        case .journalLine:
            let lineId = JournalLineID(rawValue: try issueUUID(from: ref, toolName: toolName))
            return try issueJournalLineScope(lineId, entityId: nil, toolName: toolName).entry.entityId
        case .statementImport:
            let statementImportId = StatementImportID(rawValue: try issueUUID(from: ref, toolName: toolName))
            return try issueStatementImportScope(statementImportId, entityId: nil, toolName: toolName).account.entityId
        case .transactionCategory:
            let categoryId = TransactionCategoryID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let category = try storage.categoryRepository.fetchTransactionCategory(id: categoryId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return category.entityId
        case .invoiceRecord:
            let invoiceRecordId = InvoiceRecordID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let invoiceRecord = try storage.invoiceRecordRepository.fetchInvoiceRecord(id: invoiceRecordId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return invoiceRecord.entityId
        case .filingPackage:
            let packageId = FilingPackageID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let package = try storage.filingPackageRepository.fetchFilingPackage(id: packageId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return package.entityId
        case .taxProfile:
            let taxProfileId = TaxProfileID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let taxProfile = try storage.taxProfileRepository.fetchTaxProfile(id: taxProfileId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return taxProfile.entityId
        case .entityWorkspace:
            let entityWorkspaceId = EntityWorkspaceID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let entityWorkspace = try storage.entityWorkspaceRepository.fetchEntityWorkspace(id: entityWorkspaceId),
                  entityWorkspace.workspaceId == storage.manifest.workspace.id
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return entityWorkspace.entityId
        case .issue:
            let issueId = IssueID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let issue = try storage.issueRepository.fetchIssue(id: issueId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return issue.entityId
        case .importJob:
            let importJobId = ImportJobID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let importJob = try storage.importJobRepository.fetchImportJob(
                workspaceId: storage.manifest.workspace.id,
                id: importJobId
            ),
                importJob.workspaceId == storage.manifest.workspace.id
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return nil
        case .agentProposal:
            let proposalId = AgentProposalID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let proposal = try storage.agentProposalRepository.fetchAgentProposal(id: proposalId),
                  proposal.workspaceId == storage.manifest.workspace.id
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            var proposalEntityIds: [LegalEntityID?] = [
                try auditTraceEntityId(for: proposal.targetRef, toolName: toolName, visitedRefs: &visitedRefs),
            ]
            if let relatedRef = proposal.relatedRef {
                proposalEntityIds.append(
                    try auditTraceEntityId(for: relatedRef, toolName: toolName, visitedRefs: &visitedRefs)
                )
            }
            return try mergedAuditTraceEntityIds(
                proposalEntityIds,
                toolName: toolName
            )
        case .agentConversation:
            let conversationId = AgentConversationID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let conversation = try storage.agentConversationRepository.fetchConversation(id: conversationId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try validateAgentConversationScope(conversation, entityId: conversation.activeEntityId, taxYearId: nil, toolName: toolName)
            return conversation.activeEntityId
        case .agentMessage:
            let messageId = AgentMessageID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let message = try storage.agentConversationRepository.fetchMessage(id: messageId),
                  let conversation = try storage.agentConversationRepository.fetchConversation(id: message.conversationId)
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try validateAgentConversationScope(conversation, entityId: conversation.activeEntityId, taxYearId: nil, toolName: toolName)
            return conversation.activeEntityId
        case .agentPendingApproval:
            let approvalId = AgentPendingApprovalID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let approval = try storage.agentConversationRepository.fetchPendingApproval(id: approvalId),
                  let conversation = try storage.agentConversationRepository.fetchConversation(id: approval.conversationId)
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try validateAgentConversationScope(conversation, entityId: conversation.activeEntityId, taxYearId: nil, toolName: toolName)
            return conversation.activeEntityId
        case .agentRun:
            let runId = AgentRunID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let run = try storage.agentConversationRepository.fetchAgentRun(id: runId),
                  let conversation = try storage.agentConversationRepository.fetchConversation(id: run.conversationId)
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try validateAgentConversationScope(conversation, entityId: conversation.activeEntityId, taxYearId: nil, toolName: toolName)
            return conversation.activeEntityId
        case .evidenceLink:
            let evidenceLinkId = EvidenceLinkID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let evidenceLink = try storage.evidenceLinkRepository.fetchEvidenceLink(id: evidenceLinkId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return try mergedAuditTraceEntityIds(
                [
                    auditTraceEntityId(for: evidenceLink.sourceRef, toolName: toolName, visitedRefs: &visitedRefs),
                    auditTraceEntityId(for: evidenceLink.targetRef, toolName: toolName, visitedRefs: &visitedRefs),
                ],
                toolName: toolName
            )
        case .auditEvent:
            let auditEventId = AuditEventID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let auditEvent = try storage.auditEventRepository.fetchAuditEvent(id: auditEventId),
                  auditEvent.workspaceId == storage.manifest.workspace.id
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            return try auditTraceEntityId(for: auditEvent.objectRef, toolName: toolName, visitedRefs: &visitedRefs)
        }
    }

    private func mergedAuditTraceEntityIds(
        _ entityIds: [LegalEntityID?],
        toolName: String
    ) throws -> LegalEntityID? {
        let scopedEntityIds = Set(entityIds.compactMap { $0 })
        guard scopedEntityIds.count <= 1 else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return scopedEntityIds.first
    }

    private func validateIssueReferenceScope(
        _ ref: ObjectRef,
        entityId: LegalEntityID?,
        taxYearId: TaxYearID?,
        toolName: String
    ) throws {
        switch ref.kind {
        case .workspace:
            let workspaceId = WorkspaceID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard workspaceId == storage.manifest.workspace.id else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
        case .legalEntity:
            let refEntityId = LegalEntityID(rawValue: try issueUUID(from: ref, toolName: toolName))
            _ = try issueLegalEntity(refEntityId, toolName: toolName)
            try requireIssueEntity(refEntityId, matches: entityId, toolName: toolName)
        case .taxYear:
            let refTaxYearId = TaxYearID(rawValue: try issueUUID(from: ref, toolName: toolName))
            let scope = try issueTaxYearScope(refTaxYearId, toolName: toolName)
            try requireIssueEntity(scope.entityId, matches: entityId, toolName: toolName)
            try requireIssueTaxYear(refTaxYearId, matches: taxYearId, toolName: toolName)
        case .financialAccount:
            let account = try issueFinancialAccount(ref, toolName: toolName)
            try requireIssueEntity(account.entityId, matches: entityId, toolName: toolName)
        case .counterparty:
            let counterpartyId = CounterpartyID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let counterparty = try storage.counterpartyRepository.fetchCounterparty(id: counterpartyId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try requireIssueEntity(counterparty.entityId, matches: entityId, toolName: toolName)
        case .transaction:
            let scope = try issueTransactionScope(ref, toolName: toolName)
            try requireIssueEntity(scope.account.entityId, matches: entityId, toolName: toolName)
        case .document:
            let documentId = DocumentID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let document = try storage.documentRepository.fetchDocument(id: documentId),
                  document.workspaceId == storage.manifest.workspace.id,
                  document.status == .active
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            if let documentEntityId = document.entityId {
                try requireIssueEntity(documentEntityId, matches: entityId, toolName: toolName)
            }
        case .requirement:
            let requirementId = RequirementID(rawValue: try issueUUID(from: ref, toolName: toolName))
            let requirement = try issueRequirement(requirementId, entityId: entityId, toolName: toolName)
            try requireIssueEntity(requirement.entityId, matches: entityId, toolName: toolName)
            if let requirementTaxYearId = requirement.taxYearId {
                try requireIssueTaxYear(requirementTaxYearId, matches: taxYearId, toolName: toolName)
            }
        case .taxFact:
            let factId = TaxFactID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let fact = try storage.taxFactRepository.fetchTaxFact(id: factId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try requireIssueEntity(fact.entityId, matches: entityId, toolName: toolName)
            try requireIssueTaxYear(fact.taxYearId, matches: taxYearId, toolName: toolName)
        case .vatPeriod:
            let vatPeriodId = VATPeriodID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let period = try storage.vatPeriodRepository.fetchVATPeriod(id: vatPeriodId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try requireIssueEntity(period.entityId, matches: entityId, toolName: toolName)
        case .ledgerAccount:
            let accountId = LedgerAccountID(rawValue: try issueUUID(from: ref, toolName: toolName))
            let account = try issueLedgerAccount(accountId, entityId: entityId, toolName: toolName)
            try requireIssueEntity(account.entityId, matches: entityId, toolName: toolName)
        case .journalEntry:
            let entryId = JournalEntryID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let entry = try storage.journalEntryRepository.fetchJournalEntry(id: entryId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try requireIssueEntity(entry.entityId, matches: entityId, toolName: toolName)
            if let entryTaxYearId = entry.taxYearId {
                try requireIssueTaxYear(entryTaxYearId, matches: taxYearId, toolName: toolName)
            }
        case .journalLine:
            let lineId = JournalLineID(rawValue: try issueUUID(from: ref, toolName: toolName))
            let scope = try issueJournalLineScope(lineId, entityId: entityId, toolName: toolName)
            try requireIssueEntity(scope.entry.entityId, matches: entityId, toolName: toolName)
            if let entryTaxYearId = scope.entry.taxYearId {
                try requireIssueTaxYear(entryTaxYearId, matches: taxYearId, toolName: toolName)
            }
        case .statementImport:
            let statementImportId = StatementImportID(rawValue: try issueUUID(from: ref, toolName: toolName))
            let scope = try issueStatementImportScope(statementImportId, entityId: entityId, toolName: toolName)
            try requireIssueEntity(scope.account.entityId, matches: entityId, toolName: toolName)
        case .transactionCategory:
            let categoryId = TransactionCategoryID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let category = try storage.categoryRepository.fetchTransactionCategory(id: categoryId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try requireIssueEntity(category.entityId, matches: entityId, toolName: toolName)
        case .invoiceRecord:
            let invoiceRecordId = InvoiceRecordID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let invoiceRecord = try storage.invoiceRecordRepository.fetchInvoiceRecord(id: invoiceRecordId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try requireIssueEntity(invoiceRecord.entityId, matches: entityId, toolName: toolName)
        case .filingPackage:
            let packageId = FilingPackageID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let package = try storage.filingPackageRepository.fetchFilingPackage(id: packageId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try requireIssueEntity(package.entityId, matches: entityId, toolName: toolName)
            try requireIssueTaxYear(package.taxYearId, matches: taxYearId, toolName: toolName)
        case .taxProfile:
            let taxProfileId = TaxProfileID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let taxProfile = try storage.taxProfileRepository.fetchTaxProfile(id: taxProfileId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try requireIssueEntity(taxProfile.entityId, matches: entityId, toolName: toolName)
        case .entityWorkspace:
            let entityWorkspaceId = EntityWorkspaceID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let entityWorkspace = try storage.entityWorkspaceRepository.fetchEntityWorkspace(id: entityWorkspaceId),
                  entityWorkspace.workspaceId == storage.manifest.workspace.id
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try requireIssueEntity(entityWorkspace.entityId, matches: entityId, toolName: toolName)
        case .issue:
            let issueId = IssueID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let issue = try storage.issueRepository.fetchIssue(id: issueId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            if let issueEntityId = issue.entityId {
                try requireIssueEntity(issueEntityId, matches: entityId, toolName: toolName)
            }
            if let issueTaxYearId = issue.taxYearId {
                try requireIssueTaxYear(issueTaxYearId, matches: taxYearId, toolName: toolName)
            }
        case .importJob:
            let importJobId = ImportJobID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let importJob = try storage.importJobRepository.fetchImportJob(
                workspaceId: storage.manifest.workspace.id,
                id: importJobId
            ),
                importJob.workspaceId == storage.manifest.workspace.id
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
        case .agentProposal:
            let proposalId = AgentProposalID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let proposal = try storage.agentProposalRepository.fetchAgentProposal(id: proposalId),
                  proposal.workspaceId == storage.manifest.workspace.id
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try validateIssueReferenceScope(
                proposal.targetRef,
                entityId: entityId,
                taxYearId: taxYearId,
                toolName: toolName
            )
            if let relatedRef = proposal.relatedRef {
                try validateIssueReferenceScope(
                    relatedRef,
                    entityId: entityId,
                    taxYearId: taxYearId,
                    toolName: toolName
                )
            }
        case .agentConversation:
            let conversationId = AgentConversationID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let conversation = try storage.agentConversationRepository.fetchConversation(id: conversationId) else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try validateAgentConversationScope(
                conversation,
                entityId: entityId,
                taxYearId: taxYearId,
                toolName: toolName
            )
        case .agentMessage:
            let messageId = AgentMessageID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let message = try storage.agentConversationRepository.fetchMessage(id: messageId),
                  let conversation = try storage.agentConversationRepository.fetchConversation(id: message.conversationId)
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try validateAgentConversationScope(
                conversation,
                entityId: entityId,
                taxYearId: taxYearId,
                toolName: toolName
            )
        case .agentPendingApproval:
            let approvalId = AgentPendingApprovalID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let approval = try storage.agentConversationRepository.fetchPendingApproval(id: approvalId),
                  let conversation = try storage.agentConversationRepository.fetchConversation(id: approval.conversationId)
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try validateAgentConversationScope(
                conversation,
                entityId: entityId,
                taxYearId: taxYearId,
                toolName: toolName
            )
        case .agentRun:
            let runId = AgentRunID(rawValue: try issueUUID(from: ref, toolName: toolName))
            guard let run = try storage.agentConversationRepository.fetchAgentRun(id: runId),
                  let conversation = try storage.agentConversationRepository.fetchConversation(id: run.conversationId)
            else {
                throw WorkspaceAgentToolError.invalidInput(toolName)
            }
            try validateAgentConversationScope(
                conversation,
                entityId: entityId,
                taxYearId: taxYearId,
                toolName: toolName
            )
        case .evidenceLink, .auditEvent:
            _ = try issueUUID(from: ref, toolName: toolName)
        }
    }

    private func issueUUID(from ref: ObjectRef, toolName: String) throws -> UUID {
        guard let uuid = UUID(uuidString: ref.id) else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return uuid
    }

    private func issueLegalEntity(_ entityId: LegalEntityID, toolName: String) throws -> LegalEntity {
        guard let entity = try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first(where: { $0.id == entityId })
        else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return entity
    }

    private func issueTaxYearScope(
        _ taxYearId: TaxYearID,
        toolName: String
    ) throws -> (entityId: LegalEntityID, taxYear: TaxYear) {
        let entities = try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
        for entity in entities {
            if let taxYear = try storage.taxYearRepository
                .fetchTaxYears(entityId: entity.id)
                .first(where: { $0.id == taxYearId }) {
                return (entity.id, taxYear)
            }
        }
        throw WorkspaceAgentToolError.invalidInput(toolName)
    }

    private func issueFinancialAccount(_ ref: ObjectRef, toolName: String) throws -> FinancialAccount {
        let accountId = FinancialAccountID(rawValue: try issueUUID(from: ref, toolName: toolName))
        guard let account = try storage.financialAccountRepository.fetchFinancialAccount(id: accountId) else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return account
    }

    private func issueTransactionScope(
        _ ref: ObjectRef,
        toolName: String
    ) throws -> (transaction: Transaction, account: FinancialAccount) {
        let transactionId = TransactionID(rawValue: try issueUUID(from: ref, toolName: toolName))
        guard let transaction = try storage.transactionRepository.fetchTransactions(ids: [transactionId]).first,
              let account = try storage.financialAccountRepository.fetchFinancialAccount(id: transaction.accountId)
        else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        return (transaction, account)
    }

    private func issueRequirement(
        _ requirementId: RequirementID,
        entityId: LegalEntityID?,
        toolName: String
    ) throws -> Requirement {
        let entities: [LegalEntity]
        if let entityId {
            entities = [try issueLegalEntity(entityId, toolName: toolName)]
        } else {
            entities = try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
        }

        for entity in entities {
            if let requirement = try storage.requirementRepository
                .fetchRequirements(entityId: entity.id)
                .first(where: { $0.id == requirementId }) {
                return requirement
            }
        }
        throw WorkspaceAgentToolError.invalidInput(toolName)
    }

    private func issueLedgerAccount(
        _ ledgerAccountId: LedgerAccountID,
        entityId: LegalEntityID?,
        toolName: String
    ) throws -> LedgerAccount {
        let entities: [LegalEntity]
        if let entityId {
            entities = [try issueLegalEntity(entityId, toolName: toolName)]
        } else {
            entities = try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
        }

        for entity in entities {
            if let account = try storage.ledgerAccountRepository
                .fetchLedgerAccounts(entityId: entity.id)
                .first(where: { $0.id == ledgerAccountId }) {
                return account
            }
        }
        throw WorkspaceAgentToolError.invalidInput(toolName)
    }

    private func issueJournalLineScope(
        _ lineId: JournalLineID,
        entityId: LegalEntityID?,
        toolName: String
    ) throws -> (entry: JournalEntry, line: JournalLine) {
        let entities: [LegalEntity]
        if let entityId {
            entities = [try issueLegalEntity(entityId, toolName: toolName)]
        } else {
            entities = try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
        }

        for entity in entities {
            for entry in try storage.journalEntryRepository.fetchJournalEntries(entityId: entity.id, taxYearId: nil) {
                if let line = entry.lines.first(where: { $0.id == lineId }) {
                    return (entry, line)
                }
            }
        }
        throw WorkspaceAgentToolError.invalidInput(toolName)
    }

    private func issueStatementImportScope(
        _ statementImportId: StatementImportID,
        entityId: LegalEntityID?,
        toolName: String
    ) throws -> (statementImport: StatementImport, account: FinancialAccount) {
        let entities: [LegalEntity]
        if let entityId {
            entities = [try issueLegalEntity(entityId, toolName: toolName)]
        } else {
            entities = try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
        }

        for entity in entities {
            for account in try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id) {
                if let statementImport = try storage.statementImportRepository
                    .fetchStatementImports(accountId: account.id)
                    .first(where: { $0.id == statementImportId }) {
                    return (statementImport, account)
                }
            }
        }
        throw WorkspaceAgentToolError.invalidInput(toolName)
    }

    private func validateAgentConversationScope(
        _ conversation: AgentConversation,
        entityId: LegalEntityID?,
        taxYearId: TaxYearID?,
        toolName: String
    ) throws {
        guard conversation.workspaceId == storage.manifest.workspace.id else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
        if let activeEntityId = conversation.activeEntityId {
            try requireIssueEntity(activeEntityId, matches: entityId, toolName: toolName)
        }
        if let activeTaxYearId = conversation.activeTaxYearId {
            try requireIssueTaxYear(activeTaxYearId, matches: taxYearId, toolName: toolName)
        }
    }

    private func requireIssueEntity(
        _ actualEntityId: LegalEntityID,
        matches expectedEntityId: LegalEntityID?,
        toolName: String
    ) throws {
        guard let expectedEntityId else {
            return
        }
        guard actualEntityId == expectedEntityId else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
    }

    private func requireIssueTaxYear(
        _ actualTaxYearId: TaxYearID,
        matches expectedTaxYearId: TaxYearID?,
        toolName: String
    ) throws {
        guard let expectedTaxYearId else {
            return
        }
        guard actualTaxYearId == expectedTaxYearId else {
            throw WorkspaceAgentToolError.invalidInput(toolName)
        }
    }

    private func closingAccrualFingerprint(
        input: AgentClosingAccrualProposalInput,
        sourceRef: ObjectRef?,
        lines: [AgentClosingAccrualLineOutput]
    ) -> String {
        let lineFingerprint = lines
            .map {
                [
                    $0.ledgerAccount.ledgerAccountId.description,
                    String($0.debitMinor),
                    String($0.creditMinor),
                    $0.taxCode ?? "none",
                ].joined(separator: ":")
            }
            .joined(separator: ";")
        let taxYearKey = input.taxYearId?.description ?? "none"
        let sourceKey = sourceRef?.stringValue ?? "none"
        return [
            "closing.propose_accrual",
            input.entityId.description,
            taxYearKey,
            String(Int(input.effectiveDate.timeIntervalSince1970)),
            lineFingerprint,
            sourceKey,
        ].joined(separator: "|")
    }

    private func closingAccrualSummary(memo: String, taxYear: TaxYear?) -> String {
        let prefix = taxYear.map { "Review closing accrual for \($0.year)" } ?? "Review closing accrual"
        let boundedMemo = memo.count > 80 ? "\(memo.prefix(80))..." : memo
        return "\(prefix): \(boundedMemo)"
    }

    private func closingAccrualProposalRationale(
        rationale: String,
        draftEntry: JournalEntry,
        lines: [AgentClosingAccrualLineOutput]
    ) -> String {
        var parts = [
            rationale,
            "Proposed draft journal entry:",
            "Entry \(draftEntry.entryNumber); status \(draftEntry.status.rawValue); createdBy \(draftEntry.createdBy)",
        ]
        for (index, line) in lines.enumerated() {
            let taxCode = line.taxCode ?? "none"
            let memo = line.memo.map { "; memo \($0)" } ?? ""
            parts.append(
                "\(index + 1). Account \(line.ledgerAccount.code) \(line.ledgerAccount.name); debit \(line.debitMinor); credit \(line.creditMinor); taxCode \(taxCode)\(memo)"
            )
        }
        return parts.joined(separator: "\n")
    }

    private func mappingProposalRationale(
        rationale: String,
        category: TransactionCategory?,
        taxCode: String?
    ) -> String {
        var parts = [rationale, "Proposed transaction mapping:"]
        if let category {
            parts.append("Category: \(category.code) (\(category.displayName))")
        }
        if let taxCode {
            parts.append("Tax code: \(taxCode)")
        }
        return parts.joined(separator: "\n")
    }

    private func emptyFinanceSearchProvenance(
        input: AgentFinanceSearchTransactionsInput,
        scopedAccounts: [FinancialAccount]
    ) -> [ObjectRef] {
        if let accountId = input.accountId {
            return [ObjectRef(kind: .financialAccount, id: accountId.rawValue)]
        }
        if scopedAccounts.isEmpty == false {
            return scopedAccounts.map { ObjectRef(kind: .financialAccount, id: $0.id.rawValue) }
        }
        return [ObjectRef(kind: .legalEntity, id: input.entityId.rawValue)]
    }

    private func statementCoverageProvenanceRefs(
        accounts: [FinancialAccount],
        requirements: [Requirement],
        rows: [AgentStatementCoverageRowOutput]
    ) -> [ObjectRef] {
        var refs: [ObjectRef] = []
        for account in accounts {
            appendUnique(ObjectRef(kind: .financialAccount, id: account.id.rawValue), to: &refs)
        }
        for requirement in requirements {
            appendUnique(ObjectRef(kind: .requirement, id: requirement.id.rawValue), to: &refs)
        }
        for row in rows {
            if let issueId = row.issueId {
                appendUnique(ObjectRef(kind: .issue, id: issueId.rawValue), to: &refs)
            }
            if let satisfiedByRef = row.satisfiedByRef {
                appendUnique(satisfiedByRef, to: &refs)
            }
        }
        return refs
    }

    private func fallbackTaxReadiness(
        currentFactCount: Int,
        pendingRequirementCount: Int,
        openIssueCount: Int
    ) -> AgentTaxReadinessToolOutput {
        let state: AgentTaxReadinessState
        if currentFactCount == 0 {
            state = .notStarted
        } else if pendingRequirementCount > 0 || openIssueCount > 0 {
            state = .needsAttention
        } else {
            state = .readyForReview
        }
        return AgentTaxReadinessToolOutput(
            state: state,
            openIssueCount: openIssueCount,
            pendingRequirementCount: pendingRequirementCount,
            currentFactCount: currentFactCount,
            missingConceptCodes: []
        )
    }

    private func taxContextProvenanceRefs(entityId: LegalEntityID, taxYearId: TaxYearID?) -> [ObjectRef] {
        var refs = [ObjectRef(kind: .legalEntity, id: entityId.rawValue)]
        if let taxYearId {
            refs.append(ObjectRef(kind: .taxYear, id: taxYearId.rawValue))
        }
        return refs
    }

    private func taxPreviewStatusProvenanceRefs(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        facts: [TaxFact],
        requirements: [Requirement],
        issues: [Issue]
    ) -> [ObjectRef] {
        var refs = taxContextProvenanceRefs(entityId: entityId, taxYearId: taxYearId)
        for fact in facts {
            appendUnique(ObjectRef(kind: .taxFact, id: fact.id.rawValue), to: &refs)
        }
        for requirement in requirements {
            appendUnique(ObjectRef(kind: .requirement, id: requirement.id.rawValue), to: &refs)
        }
        for issue in issues {
            appendUnique(ObjectRef(kind: .issue, id: issue.id.rawValue), to: &refs)
        }
        return refs
    }

    private func taxFactSourceSummary(for sourceRef: ObjectRef) throws -> AgentTaxFactSourceSummaryOutput? {
        switch sourceRef.kind {
        case .document:
            guard let uuid = UUID(uuidString: sourceRef.id),
                  let document = try storage.documentRepository.fetchDocument(id: DocumentID(rawValue: uuid))
            else {
                return nil
            }
            return AgentTaxFactSourceSummaryOutput(
                sourceRef: sourceRef,
                title: document.originalFilename,
                detail: "\(document.documentType.rawValue), \(document.metadataStatus.rawValue)"
            )
        case .transaction:
            guard let uuid = UUID(uuidString: sourceRef.id),
                  let transaction = try storage.transactionRepository
                    .fetchTransactions(ids: [TransactionID(rawValue: uuid)])
                    .first
            else {
                return nil
            }
            return AgentTaxFactSourceSummaryOutput(
                sourceRef: sourceRef,
                title: transaction.counterpartyName,
                detail: "\(transaction.memo), \(transaction.currency.rawValue) \(transaction.amountMinor)"
            )
        default:
            return nil
        }
    }

    private func taxFactExplanationSummary(
        fact: TaxFact,
        resolvedSourceCount: Int,
        missingSourceCount: Int
    ) -> String {
        if fact.status == .overridden {
            return "Tax fact \(fact.conceptCode) is a user override with \(resolvedSourceCount) resolved source ref(s) and \(missingSourceCount) missing source ref(s)."
        }
        return "Tax fact \(fact.conceptCode) is \(fact.status.rawValue) with \(resolvedSourceCount) resolved source ref(s) and \(missingSourceCount) missing source ref(s)."
    }

    private func appendUnique(_ ref: ObjectRef, to refs: inout [ObjectRef]) {
        if refs.contains(ref) == false {
            refs.append(ref)
        }
    }
}
