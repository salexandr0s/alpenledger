import Foundation
import Testing
@testable import ALDomain

@Test
func financialAccountComputesBalanceFromOpeningBalanceWhenRunningBalanceIsMissing() {
    let account = FinancialAccount(
        entityId: LegalEntityID(),
        accountType: .bank,
        institutionName: "Opening Bank",
        displayName: "Opening Bank",
        ledgerControlAccountId: LedgerAccountID(),
        openingBalanceMinor: 100_000,
        openingBalanceDate: Date(timeIntervalSince1970: 1_704_067_200)
    )
    let transactions = [
        Transaction(
            accountId: account.id,
            sourceLineRef: "row-2",
            bookingDate: Date(timeIntervalSince1970: 1_704_240_000),
            amountMinor: -12_500,
            currency: .chf,
            counterpartyName: "Rent",
            memo: "Office rent"
        ),
        Transaction(
            accountId: account.id,
            sourceLineRef: "row-1",
            bookingDate: Date(timeIntervalSince1970: 1_704_153_600),
            amountMinor: 45_000,
            currency: .chf,
            counterpartyName: "Client",
            memo: "Invoice payment"
        ),
    ]

    #expect(account.currentBalanceMinor(transactions: transactions) == 132_500)
}

@Test
func financialAccountExtendsLatestRunningBalanceWithLaterTransactions() {
    let account = FinancialAccount(
        entityId: LegalEntityID(),
        accountType: .bank,
        institutionName: "Running Bank",
        displayName: "Running Bank",
        ledgerControlAccountId: LedgerAccountID(),
        openingBalanceMinor: 50_000
    )
    let transactions = [
        Transaction(
            accountId: account.id,
            sourceLineRef: "row-1",
            bookingDate: Date(timeIntervalSince1970: 1_704_153_600),
            amountMinor: 10_000,
            currency: .chf,
            counterpartyName: "Client",
            memo: "Invoice payment",
            balanceAfterMinor: 60_000
        ),
        Transaction(
            accountId: account.id,
            sourceLineRef: "row-2",
            bookingDate: Date(timeIntervalSince1970: 1_704_240_000),
            amountMinor: -7_500,
            currency: .chf,
            counterpartyName: "Supplier",
            memo: "Supplies"
        ),
    ]

    #expect(account.currentBalanceMinor(transactions: transactions) == 52_500)
}
