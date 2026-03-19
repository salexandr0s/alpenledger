import Foundation

public struct JournalLine: Hashable, Codable, Sendable {
    public let id: JournalLineID
    public let journalEntryId: JournalEntryID
    public let ledgerAccountId: LedgerAccountID
    public var debitMinor: Int64
    public var creditMinor: Int64
    public var currency: String
    public var taxCode: String?
    public var sourceObjectRef: ObjectRef?
    public var memo: String

    public init(
        id: JournalLineID = JournalLineID(),
        journalEntryId: JournalEntryID,
        ledgerAccountId: LedgerAccountID,
        debitMinor: Int64,
        creditMinor: Int64,
        currency: String,
        taxCode: String? = nil,
        sourceObjectRef: ObjectRef? = nil,
        memo: String = ""
    ) throws {
        let debitIsPositive = debitMinor > 0
        let creditIsPositive = creditMinor > 0
        guard debitIsPositive != creditIsPositive else {
            throw DomainError.invalidJournalLine
        }
        self.id = id
        self.journalEntryId = journalEntryId
        self.ledgerAccountId = ledgerAccountId
        self.debitMinor = debitMinor
        self.creditMinor = creditMinor
        self.currency = currency.uppercased()
        self.taxCode = taxCode
        self.sourceObjectRef = sourceObjectRef
        self.memo = memo
    }
}
