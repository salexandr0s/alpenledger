import Foundation
import GRDB
import ALDomain

public protocol StatementImportRepository: Sendable {
    func fetchStatementImports(accountId: FinancialAccountID) throws -> [StatementImport]
    func saveStatementImport(_ statementImport: StatementImport) throws
    func fetchStatementImport(accountId: FinancialAccountID, fingerprint: String) throws -> StatementImport?
}

public final class GRDBStatementImportRepository: StatementImportRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchStatementImports(accountId: FinancialAccountID) throws -> [StatementImport] {
        try dbPool.read { db in
            try StatementImport
                .filter(Column("accountId") == accountId)
                .order(Column("coverageEnd").desc)
                .fetchAll(db)
        }
    }

    public func saveStatementImport(_ statementImport: StatementImport) throws {
        try dbPool.write { db in
            try statementImport.save(db)
        }
    }

    public func fetchStatementImport(accountId: FinancialAccountID, fingerprint: String) throws -> StatementImport? {
        try dbPool.read { db in
            try StatementImport
                .filter(Column("accountId") == accountId && Column("sourceFingerprint") == fingerprint)
                .fetchOne(db)
        }
    }
}
