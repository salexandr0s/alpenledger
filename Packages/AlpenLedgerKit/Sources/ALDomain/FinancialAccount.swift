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
    public var openingBalanceMinor: Int64?
    public var openingBalanceDate: Date?
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
        openingBalanceMinor: Int64? = nil,
        openingBalanceDate: Date? = nil,
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
        self.openingBalanceMinor = openingBalanceMinor
        self.openingBalanceDate = openingBalanceDate
        self.openedAt = openedAt
        self.closedAt = closedAt
    }

    public func currentBalanceMinor(transactions: [Transaction]) -> Int64? {
        let orderedTransactions = transactions.sorted { lhs, rhs in
            if lhs.bookingDate != rhs.bookingDate {
                return lhs.bookingDate < rhs.bookingDate
            }
            return lhs.sourceLineRef < rhs.sourceLineRef
        }

        if let latestBalanceIndex = orderedTransactions.lastIndex(where: { $0.balanceAfterMinor != nil }),
           let latestBalance = orderedTransactions[latestBalanceIndex].balanceAfterMinor {
            let nextIndex = orderedTransactions.index(after: latestBalanceIndex)
            guard nextIndex < orderedTransactions.endIndex else {
                return latestBalance
            }
            return orderedTransactions[nextIndex...].reduce(latestBalance) { balance, transaction in
                balance + transaction.amountMinor
            }
        }

        guard let openingBalanceMinor else {
            return nil
        }
        return orderedTransactions.reduce(openingBalanceMinor) { balance, transaction in
            balance + transaction.amountMinor
        }
    }
}
