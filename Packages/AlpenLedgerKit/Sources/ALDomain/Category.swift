import Foundation

public struct TransactionCategory: Hashable, Codable, Sendable {
    public let id: TransactionCategoryID
    public let entityId: LegalEntityID
    public var code: String
    public var displayName: String
    public let parentId: TransactionCategoryID?
    public var taxRole: String?
    public var isSystemDefined: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: TransactionCategoryID = TransactionCategoryID(),
        entityId: LegalEntityID,
        code: String,
        displayName: String,
        parentId: TransactionCategoryID? = nil,
        taxRole: String? = nil,
        isSystemDefined: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.entityId = entityId
        self.code = code
        self.displayName = displayName
        self.parentId = parentId
        self.taxRole = taxRole
        self.isSystemDefined = isSystemDefined
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
