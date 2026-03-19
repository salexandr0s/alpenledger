import Foundation

public enum LedgerTemplates {
    public static func accounts(for kind: LegalEntityKind, entityId: LegalEntityID) -> [LedgerAccount] {
        switch kind {
        case .naturalPerson:
            return [
                LedgerAccount(entityId: entityId, code: "1000", name: "Personal Bank", category: .asset, normalBalance: .debit, isControlAccount: true),
                LedgerAccount(entityId: entityId, code: "2000", name: "Personal Liabilities", category: .liability, normalBalance: .credit),
                LedgerAccount(entityId: entityId, code: "3000", name: "Net Worth", category: .equity, normalBalance: .credit),
                LedgerAccount(entityId: entityId, code: "4000", name: "Salary Income", category: .income, normalBalance: .credit),
                LedgerAccount(entityId: entityId, code: "5000", name: "Living Expenses", category: .expense, normalBalance: .debit),
            ]
        case .soleProprietor:
            return [
                LedgerAccount(entityId: entityId, code: "1000", name: "Business Bank", category: .asset, normalBalance: .debit, isControlAccount: true),
                LedgerAccount(entityId: entityId, code: "1100", name: "Accounts Receivable", category: .asset, normalBalance: .debit),
                LedgerAccount(entityId: entityId, code: "2000", name: "Accounts Payable", category: .liability, normalBalance: .credit),
                LedgerAccount(entityId: entityId, code: "3200", name: "Owner Equity", category: .equity, normalBalance: .credit),
                LedgerAccount(entityId: entityId, code: "4000", name: "Service Revenue", category: .income, normalBalance: .credit),
                LedgerAccount(entityId: entityId, code: "5000", name: "Operating Expenses", category: .expense, normalBalance: .debit),
            ]
        case .corporation:
            return [
                LedgerAccount(entityId: entityId, code: "1000", name: "Corporate Bank", category: .asset, normalBalance: .debit, isControlAccount: true),
            ]
        }
    }
}
