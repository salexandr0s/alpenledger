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
               let transaction = transactionForNavigation(transactionId) {
                openLedger(accountId: transaction.accountId, transactionId: transaction.id)
            }
        case .financialAccount:
            openLedger(accountId: financialAccountId(from: objectRef), transactionId: nil)
        case .issue:
            selectedSection = .inbox
            if let issueId = issueId(from: objectRef) {
                selectedInboxSelection = .issue(issueId)
            }
        case .counterparty:
            if let counterpartyId = counterpartyId(from: objectRef),
               let transaction = transactionForNavigation(counterpartyId: counterpartyId) {
                openLedger(accountId: transaction.accountId, transactionId: transaction.id)
            } else {
                selectedSection = .ledger
            }
        case .filingPackage:
            if let filingPackageId = filingPackageId(from: objectRef),
               let filingPackage = filingPackages.first(where: { $0.id == filingPackageId }) {
                selectedSection = .taxStudio
                selectedTaxEntityId = filingPackage.entityId
                selectedTaxYearId = filingPackage.taxYearId
                selectedTaxStudioSelection = .filingPackage(filingPackage.id)
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
        case .bankStatementCAMT:
            return "CAMT Statement"
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
        case .cancelled:
            return "Cancelled"
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
        case .cancelled:
            return .warning
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

    func filingPackageStatusLabel(_ status: FilingPackageStatus) -> String {
        switch status {
        case .draft:
            return "Draft"
        case .generated:
            return "Generated, Not Filed"
        case .finalized:
            return "Finalized, Not Filed"
        case .submitted:
            return "Submitted Externally"
        case .accepted:
            return "Accepted Externally"
        }
    }

    func filingPackageStatusTone(_ status: FilingPackageStatus) -> StatusBadge.Tone {
        switch status {
        case .draft:
            return .neutral
        case .generated:
            return .info
        case .finalized:
            return .warning
        case .submitted, .accepted:
            return .success
        }
    }

    func filingPackageTitle(_ filingPackage: FilingPackage) -> String {
        "\(filingPackage.exportFormat) package"
    }

    func filingPackageBoundaryText(_ filingPackage: FilingPackage) -> String {
        switch filingPackage.status {
        case .draft:
            return "Draft package record; no filing has been prepared."
        case .generated:
            return "Prepared for reviewer export; not filed."
        case .finalized:
            return "Reviewer finalized this export; not filed by AlpenLedger."
        case .submitted:
            return "Marked as submitted outside AlpenLedger."
        case .accepted:
            return "Marked as accepted outside AlpenLedger."
        }
    }

    func filingPackageFinalizationDetail(_ filingPackage: FilingPackage) -> String {
        guard let finalizedAt = filingPackage.finalizedAt else {
            return "n/a"
        }

        let finalizedDate = formattedDate(finalizedAt)
        guard let reviewer = filingPackage.finalizedBy, reviewer.isEmpty == false else {
            return finalizedDate
        }
        return "\(finalizedDate) by \(reviewer)"
    }

    func filingPackageSystemImage(_ status: FilingPackageStatus) -> String {
        switch status {
        case .draft:
            return "doc.badge.gearshape"
        case .generated:
            return "shippingbox"
        case .finalized:
            return "checkmark.seal"
        case .submitted:
            return "paperplane"
        case .accepted:
            return "checkmark.seal.fill"
        }
    }

    func shortIssueTitle(_ issue: Issue) -> String {
        switch issue.issueCode {
        case .missingStatementCoverage:
            return "Statement missing"
        case .missingExpenseEvidence:
            return "Expense evidence missing"
        case .copilotTask:
            return "Copilot task"
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

    func counterpartyId(from ref: ObjectRef) -> CounterpartyID? {
        guard ref.kind == .counterparty, let uuid = UUID(uuidString: ref.id) else { return nil }
        return CounterpartyID(rawValue: uuid)
    }

    func filingPackageId(from ref: ObjectRef) -> FilingPackageID? {
        guard ref.kind == .filingPackage, let uuid = UUID(uuidString: ref.id) else { return nil }
        return FilingPackageID(rawValue: uuid)
    }

    func transactionById(_ transactionId: TransactionID) -> Transaction? {
        transactions.first(where: { $0.id == transactionId })
            ?? linkedTransactions.first(where: { $0.id == transactionId })
    }

    func transactionForNavigation(_ transactionId: TransactionID) -> Transaction? {
        transactionById(transactionId)
            ?? (try? session?.storage.transactionRepository.fetchTransactions(ids: [transactionId]).first)
    }

    func transactionForNavigation(counterpartyId: CounterpartyID) -> Transaction? {
        transactions.first(where: { $0.counterpartyId == counterpartyId })
            ?? (try? session?.storage.transactionRepository.fetchTransactions(counterpartyId: counterpartyId).first)
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
        case .qrBill:
            return "QR-bill"
        case .bankStatement:
            return "Statement"
        case .salaryCertificate:
            return "Salary Certificate"
        case .healthInsuranceCertificate:
            return "Health Insurance"
        case .pillar3aCertificate:
            return "Pillar 3a"
        case .eCH0196TaxStatement:
            return "eCH-0196 Tax Statement"
        case .eCH0248PensionCertificate:
            return "eCH-0248 Pension"
        case .eCH0275HealthInsuranceCertificate:
            return "eCH-0275 Health Insurance"
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

    func documentStatusLabel(_ document: Document) -> String {
        if document.status == .archived {
            return "Archived"
        }
        return metadataLabel(document.metadataStatus)
    }

    func documentStatusTone(_ document: Document) -> StatusBadge.Tone {
        if document.status == .archived {
            return .neutral
        }
        return document.metadataStatus == .confirmed ? .success : .warning
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
        case .eCH0196TaxStatement:
            return "doc.text.magnifyingglass"
        case .eCH0248PensionCertificate:
            return "building.columns"
        case .eCH0275HealthInsuranceCertificate:
            return "cross.case"
        case .qrBill:
            return "qrcode"
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
        case .agentProposal:
            return "Agent proposal"
        case .counterparty:
            return "Counterparty"
        case .document:
            return "Source document"
        case .financialAccount:
            return "Financial account"
        case .filingPackage:
            return "Filing package"
        case .importJob:
            return "Import job"
        case .statementImport:
            return "Statement import"
        case .journalEntry:
            return "Journal entry"
        case .ledgerAccount:
            return "Ledger account"
        case .legalEntity:
            return "Legal entity"
        case .transaction:
            return "Linked transaction"
        case .transactionCategory:
            return "Transaction category"
        case .taxFact:
            return "Tax fact"
        case .taxYear:
            return "Tax year"
        case .vatPeriod:
            return "VAT period"
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
        case .agentProposal:
            return "sparkles"
        case .counterparty:
            return "person.crop.circle"
        case .document:
            return "doc.text"
        case .financialAccount:
            return "building.columns"
        case .filingPackage:
            return "shippingbox"
        case .importJob:
            return "tray.and.arrow.down"
        case .statementImport:
            return "doc.text.magnifyingglass"
        case .journalEntry:
            return "book.pages"
        case .ledgerAccount:
            return "number"
        case .legalEntity:
            return "person.text.rectangle"
        case .transaction:
            return "list.bullet.rectangle"
        case .transactionCategory:
            return "tag"
        case .taxFact:
            return "function"
        case .taxYear:
            return "calendar"
        case .vatPeriod:
            return "percent"
        case .requirement:
            return "list.bullet.clipboard"
        case .issue:
            return "exclamationmark.triangle"
        default:
            return "link"
        }
    }

    func provenanceRows(for refs: [ObjectRef]) -> [DocumentReferenceRowModel] {
        var seenRefs = Set<ObjectRef>()
        return refs.compactMap { ref in
            guard seenRefs.insert(ref).inserted else { return nil }
            return DocumentReferenceRowModel(
                id: ref.stringValue,
                title: provenanceTitle(for: ref),
                subtitle: ref.stringValue,
                systemImage: provenanceSymbol(for: ref)
            )
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
