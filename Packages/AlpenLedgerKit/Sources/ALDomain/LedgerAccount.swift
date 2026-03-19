import Foundation

public enum LedgerCategory: String, Codable, CaseIterable, Sendable {
    case asset
    case liability
    case equity
    case income
    case expense
}

public enum NormalBalance: String, Codable, CaseIterable, Sendable {
    case debit
    case credit
}

public struct LedgerAccount: Hashable, Codable, Sendable {
    public let id: LedgerAccountID
    public let entityId: LegalEntityID
    public var code: String
    public var name: String
    public var category: LedgerCategory
    public var normalBalance: NormalBalance
    public var parentId: LedgerAccountID?
    public var taxRole: String?
    public var isControlAccount: Bool

    public init(
        id: LedgerAccountID = LedgerAccountID(),
        entityId: LegalEntityID,
        code: String,
        name: String,
        category: LedgerCategory,
        normalBalance: NormalBalance,
        parentId: LedgerAccountID? = nil,
        taxRole: String? = nil,
        isControlAccount: Bool = false
    ) {
        self.id = id
        self.entityId = entityId
        self.code = code
        self.name = name
        self.category = category
        self.normalBalance = normalBalance
        self.parentId = parentId
        self.taxRole = taxRole
        self.isControlAccount = isControlAccount
    }
}
