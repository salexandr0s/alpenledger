import Foundation
import GRDB
import ALDomain

public protocol TransactionRepository: Sendable {
    func fetchTransactions(accountId: FinancialAccountID) throws -> [Transaction]
    func fetchTransactions(ids: [TransactionID]) throws -> [Transaction]
    func saveTransactions(_ transactions: [Transaction]) throws
}

public final class GRDBTransactionRepository: TransactionRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchTransactions(accountId: FinancialAccountID) throws -> [Transaction] {
        try dbPool.read { db in
            try Transaction
                .filter(Column("accountId") == accountId)
                .order(Column("bookingDate").desc)
                .fetchAll(db)
        }
    }

    public func fetchTransactions(ids: [TransactionID]) throws -> [Transaction] {
        guard ids.isEmpty == false else {
            return []
        }
        return try dbPool.read { db in
            try Transaction.filter(ids.contains(Column("id"))).fetchAll(db)
        }
    }

    public func saveTransactions(_ transactions: [Transaction]) throws {
        try dbPool.write { db in
            for transaction in transactions {
                try transaction.save(db)
            }
        }
    }
}
