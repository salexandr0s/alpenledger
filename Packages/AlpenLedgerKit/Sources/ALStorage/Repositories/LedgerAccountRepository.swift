import Foundation
import GRDB
import ALDomain

public protocol LedgerAccountRepository: Sendable {
    func fetchLedgerAccounts(entityId: LegalEntityID) throws -> [LedgerAccount]
    func saveLedgerAccount(_ account: LedgerAccount) throws
    func deleteLedgerAccounts(entityId: LegalEntityID) throws
}

public final class GRDBLedgerAccountRepository: LedgerAccountRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchLedgerAccounts(entityId: LegalEntityID) throws -> [LedgerAccount] {
        try dbPool.read { db in
            try LedgerAccount
                .filter(Column("entityId") == entityId)
                .order(Column("code"))
                .fetchAll(db)
        }
    }

    public func saveLedgerAccount(_ account: LedgerAccount) throws {
        try dbPool.write { db in
            try account.save(db)
        }
    }

    public func deleteLedgerAccounts(entityId: LegalEntityID) throws {
        try dbPool.write { db in
            _ = try LedgerAccount.filter(Column("entityId") == entityId).deleteAll(db)
        }
    }
}
