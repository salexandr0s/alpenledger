import Foundation
import GRDB
import ALDomain

public protocol TransactionCategoryRepository: Sendable {
    func fetchCategories(entityId: LegalEntityID) throws -> [TransactionCategory]
    func fetchTransactionCategory(id: TransactionCategoryID) throws -> TransactionCategory?
    func saveTransactionCategory(_ category: TransactionCategory) throws
    func deleteTransactionCategory(id: TransactionCategoryID) throws
}

public final class GRDBTransactionCategoryRepository: TransactionCategoryRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchCategories(entityId: LegalEntityID) throws -> [TransactionCategory] {
        try dbPool.read { db in
            try TransactionCategory
                .filter(Column("entityId") == entityId)
                .order(Column("code"))
                .fetchAll(db)
        }
    }

    public func fetchTransactionCategory(id: TransactionCategoryID) throws -> TransactionCategory? {
        try dbPool.read { db in
            try TransactionCategory.fetchOne(db, key: id)
        }
    }

    public func saveTransactionCategory(_ category: TransactionCategory) throws {
        try dbPool.write { db in
            try category.save(db)
        }
    }

    public func deleteTransactionCategory(id: TransactionCategoryID) throws {
        try dbPool.write { db in
            _ = try TransactionCategory.deleteOne(db, key: id)
        }
    }
}
