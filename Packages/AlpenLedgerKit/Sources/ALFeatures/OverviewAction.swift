import Foundation
import ALDomain

public enum OverviewAction: Hashable, Sendable {
    case openInbox(selection: InboxSelection?)
    case openLedger(accountId: FinancialAccountID?, transactionId: TransactionID?)
    case openDocuments(documentId: DocumentID?)
    case openTaxStudio(entityId: LegalEntityID?, taxYearId: TaxYearID?, factId: TaxFactID?)
    case importSampleCSV
    case importSampleDocument
    case importDocument
}
