import Foundation

public enum TransactionOriginKind: String, Codable, CaseIterable, Sendable {
    case imported
    case manual
}

public enum ReviewState: String, Codable, CaseIterable, Sendable {
    case pending
    case reviewed
}

public struct Transaction: Hashable, Codable, Sendable {
    public let id: TransactionID
    public let accountId: FinancialAccountID
    public var statementImportId: StatementImportID?
    public var originKind: TransactionOriginKind
    public var sourceLineRef: String
    public var bookingDate: Date
    public var valueDate: Date?
    public var amountMinor: Int64
    public var currency: CurrencyCode
    public var counterpartyName: String
    public var memo: String
    public var reference: String?
    public var balanceAfterMinor: Int64?
    public var reviewState: ReviewState

    public init(
        id: TransactionID = TransactionID(),
        accountId: FinancialAccountID,
        statementImportId: StatementImportID? = nil,
        originKind: TransactionOriginKind = .imported,
        sourceLineRef: String,
        bookingDate: Date,
        valueDate: Date? = nil,
        amountMinor: Int64,
        currency: CurrencyCode,
        counterpartyName: String,
        memo: String,
        reference: String? = nil,
        balanceAfterMinor: Int64? = nil,
        reviewState: ReviewState = .pending
    ) {
        self.id = id
        self.accountId = accountId
        self.statementImportId = statementImportId
        self.originKind = originKind
        self.sourceLineRef = sourceLineRef
        self.bookingDate = bookingDate
        self.valueDate = valueDate
        self.amountMinor = amountMinor
        self.currency = currency
        self.counterpartyName = counterpartyName
        self.memo = memo
        self.reference = reference
        self.balanceAfterMinor = balanceAfterMinor
        self.reviewState = reviewState
    }
}
