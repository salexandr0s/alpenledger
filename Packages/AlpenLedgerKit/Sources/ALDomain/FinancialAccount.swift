import Foundation

public enum FinancialAccountType: String, Codable, CaseIterable, Sendable {
    case bank
    case card
    case cash
    case receivable
    case payable
    case loan
}

public enum StatementCadence: String, Codable, CaseIterable, Sendable {
    case monthly
    case quarterly
    case annual
    case adHoc
}

public struct FinancialAccount: Hashable, Codable, Sendable {
    public let id: FinancialAccountID
    public let entityId: LegalEntityID
    public var accountType: FinancialAccountType
    public var institutionName: String
    public var displayName: String
    public var currency: CurrencyCode
    public var ibanMask: String?
    public var statementCadence: StatementCadence
    public let ledgerControlAccountId: LedgerAccountID
    public var openedAt: Date
    public var closedAt: Date?

    public init(
        id: FinancialAccountID = FinancialAccountID(),
        entityId: LegalEntityID,
        accountType: FinancialAccountType,
        institutionName: String,
        displayName: String,
        currency: CurrencyCode = .chf,
        ibanMask: String? = nil,
        statementCadence: StatementCadence = .monthly,
        ledgerControlAccountId: LedgerAccountID,
        openedAt: Date = .now,
        closedAt: Date? = nil
    ) {
        self.id = id
        self.entityId = entityId
        self.accountType = accountType
        self.institutionName = institutionName
        self.displayName = displayName
        self.currency = currency
        self.ibanMask = ibanMask
        self.statementCadence = statementCadence
        self.ledgerControlAccountId = ledgerControlAccountId
        self.openedAt = openedAt
        self.closedAt = closedAt
    }
}
