import Foundation
import ALDesignSystem
import ALDomain
import ALFeatures
import ALTaxCore
import ALWorkspace

// MARK: - Presentation Helpers

extension WorkspaceAppModel {

    // MARK: Navigation

    func openObjectRef(_ objectRef: ObjectRef) {
        switch objectRef.kind {
        case .document:
            openDocuments(documentId: documentId(from: objectRef))
        case .transaction:
            if let transactionId = transactionId(from: objectRef),
               let transaction = transactionById(transactionId) {
                openLedger(accountId: transaction.accountId, transactionId: transaction.id)
            }
        case .financialAccount:
            openLedger(accountId: financialAccountId(from: objectRef), transactionId: nil)
        case .issue:
            selectedSection = .inbox
            if let issueId = issueId(from: objectRef) {
                selectedInboxSelection = .issue(issueId)
            }
        default:
            break
        }
    }

    // MARK: Entity Deletion

    func blockedEntityDeletionMessage(for check: LegalEntityService.DeletionCheck) -> String {
        var reasons: [String] = []
        if check.statementImportCount > 0 {
            reasons.append("\(check.statementImportCount) statement import\(check.statementImportCount == 1 ? "" : "s")")
        }
        if check.transactionCount > 0 {
            reasons.append("\(check.transactionCount) transaction\(check.transactionCount == 1 ? "" : "s")")
        }
        if check.documentCount > 0 {
            reasons.append("\(check.documentCount) document\(check.documentCount == 1 ? "" : "s")")
        }
        if check.taxFactCount > 0 {
            reasons.append("\(check.taxFactCount) tax fact\(check.taxFactCount == 1 ? "" : "s")")
        }
        if check.issueCount > 0 {
            reasons.append("\(check.issueCount) issue\(check.issueCount == 1 ? "" : "s")")
        }
        if check.requirementCount > 0 {
            reasons.append("\(check.requirementCount) requirement\(check.requirementCount == 1 ? "" : "s")")
        }
        return "This entity still has dependent data: \(reasons.joined(separator: ", "))."
    }

    func deletionRemovalHint(_ check: LegalEntityService.DeletionCheck?) -> String? {
        guard let check, check.canDelete == false else { return nil }
        return blockedEntityDeletionMessage(for: check)
    }

    // MARK: Import Labels

    func importSortOrder(lhs: ImportJob, rhs: ImportJob) -> Bool {
        let lhsDate = lhs.completedAt ?? lhs.startedAt
        let rhsDate = rhs.completedAt ?? rhs.startedAt
        return lhsDate > rhsDate
    }

    func importKindLabel(_ kind: ImportJobKind) -> String {
        switch kind {
        case .bankStatementCSV:
            return "Bank Statement"
        case .documentIntake:
            return "Document Intake"
        }
    }

    func importStatusLabel(_ status: ImportJobStatus) -> String {
        switch status {
        case .started:
            return "Started"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    func importTimestampLabel(_ job: ImportJob) -> String {
        let timestamp = job.completedAt ?? job.startedAt
        return timestamp.formatted(date: .abbreviated, time: .shortened)
    }

    func tone(for status: ImportJobStatus) -> StatusBadge.Tone {
        switch status {
        case .started:
            return .warning
        case .completed:
            return .success
        case .failed:
            return .critical
        }
    }

    // MARK: Issue / Readiness Labels

    func issuePriority(_ severity: IssueSeverity) -> Int {
        switch severity {
        case .blocking:
            return 2
        case .warning:
            return 1
        }
    }

    func readinessTone(_ state: TaxReadinessState) -> StatusBadge.Tone {
        switch state {
        case .notStarted:
            return .neutral
        case .needsAttention:
            return .warning
        case .readyForReview:
            return .success
        }
    }

    func readinessTitle(_ state: TaxReadinessState) -> String {
        switch state {
        case .notStarted:
            return "Not Started"
        case .needsAttention:
            return "Needs Attention"
        case .readyForReview:
            return "Ready for Review"
        }
    }

    func shortIssueTitle(_ issue: Issue) -> String {
        switch issue.issueCode {
        case .missingStatementCoverage:
            return "Statement missing"
        case .missingExpenseEvidence:
            return "Expense evidence missing"
        }
    }

    func shortRequirementTitle(_ requirement: Requirement) -> String {
        switch requirement.requirementCode {
        case .statementCoverage:
            return "Statement coverage required"
        case .expenseEvidence:
            return "Supporting evidence required"
        }
    }

    // MARK: Entity / Object Lookups

    func entityName(for entityId: LegalEntityID?) -> String? {
        guard let entityId else { return nil }
        return entities.first(where: { $0.id == entityId })?.displayName
    }

    func financialAccountId(from ref: ObjectRef) -> FinancialAccountID? {
        guard ref.kind == .financialAccount, let uuid = UUID(uuidString: ref.id) else { return nil }
        return FinancialAccountID(rawValue: uuid)
    }

    func transactionId(from ref: ObjectRef) -> TransactionID? {
        guard ref.kind == .transaction, let uuid = UUID(uuidString: ref.id) else { return nil }
        return TransactionID(rawValue: uuid)
    }

    func documentId(from ref: ObjectRef) -> DocumentID? {
        guard ref.kind == .document, let uuid = UUID(uuidString: ref.id) else { return nil }
        return DocumentID(rawValue: uuid)
    }

    func issueId(from ref: ObjectRef) -> IssueID? {
        guard ref.kind == .issue, let uuid = UUID(uuidString: ref.id) else { return nil }
        return IssueID(rawValue: uuid)
    }

    func transactionById(_ transactionId: TransactionID) -> Transaction? {
        transactions.first(where: { $0.id == transactionId })
            ?? linkedTransactions.first(where: { $0.id == transactionId })
    }

    // MARK: Date / Money Formatting

    func coverageLabel(start: Date?, end: Date?) -> String {
        let startText = formattedDate(start)
        let endText = formattedDate(end)
        if start == nil && end == nil {
            return "n/a"
        }
        return "\(startText) to \(endText)"
    }

    func formattedDate(_ date: Date?) -> String {
        guard let date else { return "n/a" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: container.nowProvider())
    }

    func amountString(_ amountMinor: Int64, currency: CurrencyCode) -> String {
        MoneyFormatter().format(minorUnits: amountMinor, currency: currency)
    }

    // MARK: Account Labels / Symbols

    func accountTypeLabel(_ accountType: FinancialAccountType) -> String {
        switch accountType {
        case .bank:
            return "Bank"
        case .card:
            return "Card"
        case .cash:
            return "Cash"
        case .receivable:
            return "Receivable"
        case .payable:
            return "Payable"
        case .loan:
            return "Loan"
        }
    }

    func symbol(for accountType: FinancialAccountType) -> String {
        switch accountType {
        case .bank:
            return "building.columns"
        case .card:
            return "creditcard"
        case .cash:
            return "banknote"
        case .receivable:
            return "arrow.down.circle"
        case .payable:
            return "arrow.up.circle"
        case .loan:
            return "chart.bar.doc.horizontal"
        }
    }

    // MARK: Document Labels / Symbols

    func documentTypeLabel(_ documentType: DocumentType) -> String {
        switch documentType {
        case .unknown:
            return "Unsorted"
        case .receipt:
            return "Receipt"
        case .invoice:
            return "Invoice"
        case .bankStatement:
            return "Statement"
        case .salaryCertificate:
            return "Salary Certificate"
        case .healthInsuranceCertificate:
            return "Health Insurance"
        case .pillar3aCertificate:
            return "Pillar 3a"
        }
    }

    func metadataLabel(_ status: MetadataStatus) -> String {
        switch status {
        case .proposed:
            return "Proposed"
        case .confirmed:
            return "Confirmed"
        }
    }

    func documentSymbol(_ documentType: DocumentType) -> String {
        switch documentType {
        case .bankStatement:
            return "doc.text"
        case .salaryCertificate:
            return "doc.badge.gearshape"
        case .healthInsuranceCertificate:
            return "cross.case"
        case .pillar3aCertificate:
            return "leaf"
        case .receipt, .invoice:
            return "doc.richtext"
        case .unknown:
            return "doc"
        }
    }

    // MARK: Entity Kind

    func entityKindLabel(_ kind: LegalEntityKind) -> String {
        switch kind {
        case .naturalPerson:
            return "Natural Person"
        case .soleProprietor:
            return "Sole Proprietor"
        case .corporation:
            return "Corporation"
        }
    }

    // MARK: Tax Fact Labels

    func factLabel(for conceptCode: String) -> String {
        switch conceptCode {
        case "personal.income.salary_gross":
            return "Salary Gross"
        case "personal.deduction.health_insurance_premiums":
            return "Health Insurance Premiums"
        case "personal.deduction.pillar3a_contributions":
            return "Pillar 3a Contributions"
        case "personal.self_employment.revenue_gross":
            return "Revenue Gross"
        case "personal.self_employment.expense_total":
            return "Expense Total"
        case "personal.self_employment.net_profit":
            return "Net Profit"
        default:
            return conceptCode
        }
    }

    func valueString(for fact: TaxFact) -> String {
        switch fact.valueType {
        case .money:
            return MoneyFormatter().format(minorUnits: fact.moneyMinor ?? 0, currency: fact.currency ?? .chf)
        case .text:
            return fact.textValue ?? "n/a"
        case .bool:
            return (fact.boolValue ?? false) ? "Yes" : "No"
        case .date:
            guard let dateValue = fact.dateValue else {
                return "n/a"
            }
            return DateFormatter.localizedString(from: dateValue, dateStyle: .medium, timeStyle: .none)
        }
    }

    func statusTone(_ status: TaxFactStatus) -> StatusBadge.Tone {
        switch status {
        case .observed:
            return .info
        case .derived:
            return .success
        case .overridden:
            return .warning
        }
    }

    func symbol(for status: TaxFactStatus) -> String {
        switch status {
        case .observed:
            return "eye"
        case .derived:
            return "function"
        case .overridden:
            return "slider.horizontal.3"
        }
    }

    // MARK: Provenance

    func provenanceTitle(for ref: ObjectRef) -> String {
        switch ref.kind {
        case .document:
            return "Source document"
        case .transaction:
            return "Linked transaction"
        case .requirement:
            return "Requirement"
        case .issue:
            return "Issue"
        default:
            return ref.kind.rawValue.capitalized
        }
    }

    func provenanceSymbol(for ref: ObjectRef) -> String {
        switch ref.kind {
        case .document:
            return "doc.text"
        case .transaction:
            return "list.bullet.rectangle"
        case .requirement:
            return "list.bullet.clipboard"
        case .issue:
            return "exclamationmark.triangle"
        default:
            return "link"
        }
    }

    // MARK: Document Search

    func documentMatchesSearch(_ document: Document) -> Bool {
        let trimmedQuery = documentSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return true }

        let searchableContent = [
            document.originalFilename,
            document.extractedText ?? "",
            document.mediaType,
            document.documentType.rawValue
        ]
        .joined(separator: "\n")

        return searchableContent.localizedStandardContains(trimmedQuery)
    }
}
