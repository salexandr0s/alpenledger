import Foundation
import GRDB
import ALDomain

public protocol FinancialAccountRepository: Sendable {
    func fetchFinancialAccount(id: FinancialAccountID) throws -> FinancialAccount?
    func fetchFinancialAccounts(entityId: LegalEntityID) throws -> [FinancialAccount]
    func saveFinancialAccount(_ account: FinancialAccount) throws
    func deleteFinancialAccounts(entityId: LegalEntityID) throws
}

public final class GRDBFinancialAccountRepository: FinancialAccountRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchFinancialAccount(id: FinancialAccountID) throws -> FinancialAccount? {
        try dbPool.read { db in
            try FinancialAccount
                .filter(Column("id") == id)
                .fetchOne(db)
        }
    }

    public func fetchFinancialAccounts(entityId: LegalEntityID) throws -> [FinancialAccount] {
        try dbPool.read { db in
            try FinancialAccount
                .filter(Column("entityId") == entityId)
                .order(Column("displayName"))
                .fetchAll(db)
        }
    }

    public func saveFinancialAccount(_ account: FinancialAccount) throws {
        try dbPool.write { db in
            try account.save(db)
        }
    }

    public func deleteFinancialAccounts(entityId: LegalEntityID) throws {
        try dbPool.write { db in
            _ = try FinancialAccount.filter(Column("entityId") == entityId).deleteAll(db)
        }
    }
}
