import Foundation
import GRDB
import ALDomain

public protocol TransactionRepository: Sendable {
    func fetchTransactions(accountId: FinancialAccountID) throws -> [Transaction]
    func fetchTransactions(counterpartyId: CounterpartyID) throws -> [Transaction]
    func fetchTransactions(entityId: LegalEntityID, from start: Date, through end: Date) throws -> [Transaction]
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

    public func fetchTransactions(counterpartyId: CounterpartyID) throws -> [Transaction] {
        try dbPool.read { db in
            try Transaction
                .filter(Column("counterpartyId") == counterpartyId)
                .order(Column("bookingDate").desc)
                .fetchAll(db)
        }
    }

    public func fetchTransactions(entityId: LegalEntityID, from start: Date, through end: Date) throws -> [Transaction] {
        try dbPool.read { db in
            try Transaction.fetchAll(
                db,
                sql: """
                SELECT transactions.*
                FROM transactions
                JOIN financialAccounts ON financialAccounts.id = transactions.accountId
                WHERE financialAccounts.entityId = ?
                  AND transactions.bookingDate >= ?
                  AND transactions.bookingDate <= ?
                ORDER BY transactions.bookingDate, transactions.sourceLineRef
                """,
                arguments: [entityId, start, end]
            )
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
                let linkedTransaction = try transactionByEnsuringCounterparty(transaction, in: db)
                try linkedTransaction.save(db)
            }
        }
    }
}
