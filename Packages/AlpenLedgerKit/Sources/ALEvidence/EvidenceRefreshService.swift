import Foundation
import ALAudit
import ALDomain
import ALStorage

public final class EvidenceRefreshService: Sendable {
    private let storage: WorkspaceStorage
    private let requirementService: RequirementService
    private let issueService: IssueService
    private let reconciliationService: ReconciliationService
    private let nowProvider: @Sendable () -> Date
    private let calendar = Calendar(identifier: .gregorian)

    public init(
        storage: WorkspaceStorage,
        auditLogger: AuditLogger,
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.storage = storage
        self.requirementService = RequirementService(storage: storage)
        self.issueService = IssueService(storage: storage, auditLogger: auditLogger)
        self.reconciliationService = ReconciliationService(storage: storage, auditLogger: auditLogger)
        self.nowProvider = nowProvider
    }

    public func refresh() throws {
        let now = nowProvider()
        let entities = try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
        for entity in entities {
            guard let taxYear = try activeTaxYear(for: entity.id, now: now) else {
                continue
            }

            let accounts = try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id)
            for account in accounts {
                try refreshStatementCoverage(for: account, entityId: entity.id, taxYear: taxYear, now: now)
                try refreshExpenseEvidence(for: account, entityId: entity.id, taxYear: taxYear, now: now)
            }
        }

        let documents = try storage.documentRepository.fetchDocuments(workspaceId: storage.manifest.workspace.id)
        for document in documents where document.documentType == .receipt || document.documentType == .invoice {
            let hasLink = try reconciliationService.hasConfirmedTransactionLink(for: document.id)
            _ = try reconciliationService.syncDocumentLinkProposal(for: document, hasConfirmedLink: hasLink, now: now)
        }
    }

    public func listIssues(status: IssueStatus? = nil) throws -> [Issue] {
        try issueService.listIssues(status: status)
    }

    public func listProposals(status: ProposalStatus? = nil) throws -> [AgentProposal] {
        try reconciliationService.listProposals(status: status)
    }

    private func makeDayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func makeMonthFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }

    private func activeTaxYear(for entityId: LegalEntityID, now: Date) throws -> TaxYear? {
        try storage.taxYearRepository
            .fetchTaxYears(entityId: entityId)
            .first(where: { $0.periodStart <= now && now <= $0.periodEnd })
    }

    private func refreshStatementCoverage(
        for account: FinancialAccount,
        entityId: LegalEntityID,
        taxYear: TaxYear,
        now: Date
    ) throws {
        guard account.statementCadence != .adHoc else {
            return
        }

        let statementImports = try storage.statementImportRepository.fetchStatementImports(accountId: account.id)
        let dayFmt = makeDayFormatter()
        let monthFmt = makeMonthFormatter()
        for bucket in completedBuckets(for: taxYear, account: account, now: now) {
            let satisfiedImport = statementImports.first(where: { statementImport in
                statementImport.coverageStart <= bucket.end && statementImport.coverageEnd >= bucket.start
            })
            let accountRef = ObjectRef(kind: .financialAccount, id: account.id.rawValue)
            let requirementFingerprint = "statement-coverage|\(account.id)|\(dayFmt.string(from: bucket.start))"
            let requirement = try requirementService.syncRequirement(
                fingerprint: requirementFingerprint,
                entityId: entityId,
                taxYearId: taxYear.id,
                code: .statementCoverage,
                subjectRef: accountRef,
                summary: "Statement coverage for \(monthFmt.string(from: bucket.start))",
                coverageStart: bucket.start,
                coverageEnd: bucket.end,
                status: satisfiedImport == nil ? .pending : .satisfied,
                satisfiedByRef: satisfiedImport.map { ObjectRef(kind: .statementImport, id: $0.id.rawValue) },
                now: now
            )

            let issueFingerprint = "missing-statement-coverage|\(account.id)|\(dayFmt.string(from: bucket.start))"
            let summary = "Missing \(account.statementCadence.rawValue) statement for \(account.displayName) in \(monthFmt.string(from: bucket.start))"
            _ = try issueService.syncIssue(
                fingerprint: issueFingerprint,
                entityId: entityId,
                taxYearId: taxYear.id,
                code: .missingStatementCoverage,
                severity: .blocking,
                status: satisfiedImport == nil ? .open : .resolved,
                summary: summary,
                objectRef: accountRef,
                relatedRef: ObjectRef(kind: .requirement, id: requirement.id.rawValue),
                now: now
            )
        }
    }

    private func refreshExpenseEvidence(
        for account: FinancialAccount,
        entityId: LegalEntityID,
        taxYear: TaxYear,
        now: Date
    ) throws {
        guard account.accountType == .bank || account.accountType == .card else {
            return
        }

        let threshold = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let transactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)
        for transaction in transactions
        where transaction.originKind == .imported &&
            transaction.amountMinor < 0 &&
            transaction.bookingDate <= threshold &&
            taxYear.periodStart <= transaction.bookingDate &&
            transaction.bookingDate <= taxYear.periodEnd {
            let transactionRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
            let supportingDocumentRef = try reconciliationService.hasConfirmedDocumentLink(for: transaction.id)
            let amountValue = Decimal(abs(transaction.amountMinor)) / 100
            let amountString = NSDecimalNumber(decimal: amountValue).stringValue
            let requirement = try requirementService.syncRequirement(
                fingerprint: "expense-evidence|\(transaction.id)",
                entityId: entityId,
                taxYearId: taxYear.id,
                code: .expenseEvidence,
                subjectRef: transactionRef,
                summary: "Supporting evidence for \(transaction.counterpartyName) (\(amountString) \(transaction.currency))",
                coverageStart: nil,
                coverageEnd: nil,
                status: supportingDocumentRef == nil ? .pending : .satisfied,
                satisfiedByRef: supportingDocumentRef,
                now: now
            )

            _ = try issueService.syncIssue(
                fingerprint: "missing-expense-evidence|\(transaction.id)",
                entityId: entityId,
                taxYearId: taxYear.id,
                code: .missingExpenseEvidence,
                severity: .warning,
                status: supportingDocumentRef == nil ? .open : .resolved,
                summary: "Missing supporting evidence for \(transaction.counterpartyName)",
                objectRef: transactionRef,
                relatedRef: ObjectRef(kind: .requirement, id: requirement.id.rawValue),
                now: now
            )
        }
    }

    private func completedBuckets(for taxYear: TaxYear, account: FinancialAccount, now: Date) -> [CoverageBucket] {
        var buckets: [CoverageBucket] = []
        var bucketStart = taxYear.periodStart

        while bucketStart <= taxYear.periodEnd {
            let nextStart = nextBucketStart(after: bucketStart, cadence: account.statementCadence)
            let bucketEnd = min(nextStart.addingTimeInterval(-1), taxYear.periodEnd)
            defer { bucketStart = nextStart }

            guard bucketEnd < now else {
                continue
            }
            guard bucketEnd >= account.openedAt else {
                continue
            }
            if let closedAt = account.closedAt, bucketStart > closedAt {
                continue
            }
            buckets.append(CoverageBucket(start: bucketStart, end: bucketEnd))
        }

        return buckets
    }

    private func nextBucketStart(after bucketStart: Date, cadence: StatementCadence) -> Date {
        switch cadence {
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: bucketStart) ?? bucketStart
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: bucketStart) ?? bucketStart
        case .annual:
            return calendar.date(byAdding: .year, value: 1, to: bucketStart) ?? bucketStart
        case .adHoc:
            return calendar.date(byAdding: .year, value: 100, to: bucketStart) ?? bucketStart
        }
    }
}

private struct CoverageBucket {
    let start: Date
    let end: Date
}
