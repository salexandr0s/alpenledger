import Foundation
import GRDB
import ALDomain

public protocol WorkspaceRepository: Sendable {
    func fetchWorkspace() throws -> Workspace?
    func saveWorkspace(_ workspace: Workspace) throws
}

public protocol LegalEntityRepository: Sendable {
    func fetchLegalEntities(workspaceId: WorkspaceID) throws -> [LegalEntity]
    func saveLegalEntity(_ entity: LegalEntity) throws
}

public protocol TaxYearRepository: Sendable {
    func fetchTaxYears(entityId: LegalEntityID) throws -> [TaxYear]
    func saveTaxYear(_ taxYear: TaxYear) throws
}

public protocol LedgerAccountRepository: Sendable {
    func fetchLedgerAccounts(entityId: LegalEntityID) throws -> [LedgerAccount]
    func saveLedgerAccount(_ account: LedgerAccount) throws
}

public protocol FinancialAccountRepository: Sendable {
    func fetchFinancialAccounts(entityId: LegalEntityID) throws -> [FinancialAccount]
    func saveFinancialAccount(_ account: FinancialAccount) throws
}

public protocol ImportJobRepository: Sendable {
    func fetchImportJobs(workspaceId: WorkspaceID) throws -> [ImportJob]
    func saveImportJob(_ job: ImportJob) throws
}

public protocol StatementImportRepository: Sendable {
    func fetchStatementImports(accountId: FinancialAccountID) throws -> [StatementImport]
    func saveStatementImport(_ statementImport: StatementImport) throws
    func fetchStatementImport(accountId: FinancialAccountID, fingerprint: String) throws -> StatementImport?
}

public protocol TransactionRepository: Sendable {
    func fetchTransactions(accountId: FinancialAccountID) throws -> [Transaction]
    func fetchTransactions(ids: [TransactionID]) throws -> [Transaction]
    func saveTransactions(_ transactions: [Transaction]) throws
}

public protocol DocumentRepository: Sendable {
    func fetchDocuments(workspaceId: WorkspaceID) throws -> [Document]
    func fetchDocument(id: DocumentID) throws -> Document?
    func fetchDocument(workspaceId: WorkspaceID, blobHash: String) throws -> Document?
    func fetchDocuments(ids: [DocumentID]) throws -> [Document]
    func saveDocument(_ document: Document) throws
}

public protocol EvidenceLinkRepository: Sendable {
    func fetchEvidenceLinks(for objectRef: ObjectRef) throws -> [EvidenceLink]
    func saveEvidenceLink(_ evidenceLink: EvidenceLink) throws
}

public protocol AuditEventRepository: Sendable {
    func fetchAuditEvents(workspaceId: WorkspaceID, objectRef: ObjectRef?) throws -> [AuditEvent]
    func saveAuditEvent(_ event: AuditEvent) throws
}

extension EntityID: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        description.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let rawValue = String.fromDatabaseValue(dbValue), let uuid = UUID(uuidString: rawValue) else {
            return nil
        }
        return Self(rawValue: uuid)
    }
}

extension ObjectRef: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        stringValue.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> ObjectRef? {
        guard let value = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return ObjectRef.parse(value)
    }
}

extension Workspace: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "workspaces"
}
extension LegalEntity: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "legalEntities"
}
extension TaxYear: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "taxYears"
}
extension LedgerAccount: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "ledgerAccounts"
}
extension FinancialAccount: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "financialAccounts"
}
extension ImportJob: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "importJobs"
}
extension StatementImport: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "statementImports"
}
extension Transaction: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "transactions"
}
extension Document: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "documents"
}
extension EvidenceLink: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "evidenceLinks"
}
extension AuditEvent: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "auditEvents"
}

public final class GRDBWorkspaceRepository: WorkspaceRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchWorkspace() throws -> Workspace? {
        try dbPool.read { db in
            try Workspace.fetchOne(db, sql: "SELECT * FROM workspaces LIMIT 1")
        }
    }

    public func saveWorkspace(_ workspace: Workspace) throws {
        try dbPool.write { db in
            try workspace.save(db)
        }
    }
}

public final class GRDBLegalEntityRepository: LegalEntityRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchLegalEntities(workspaceId: WorkspaceID) throws -> [LegalEntity] {
        try dbPool.read { db in
            try LegalEntity
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("displayName"))
                .fetchAll(db)
        }
    }

    public func saveLegalEntity(_ entity: LegalEntity) throws {
        try dbPool.write { db in
            try entity.save(db)
        }
    }
}

public final class GRDBTaxYearRepository: TaxYearRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchTaxYears(entityId: LegalEntityID) throws -> [TaxYear] {
        try dbPool.read { db in
            try TaxYear
                .filter(Column("entityId") == entityId)
                .order(Column("year").desc)
                .fetchAll(db)
        }
    }

    public func saveTaxYear(_ taxYear: TaxYear) throws {
        try dbPool.write { db in
            try taxYear.save(db)
        }
    }
}

public final class GRDBLedgerAccountRepository: LedgerAccountRepository, @unchecked Sendable {
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
}

public final class GRDBFinancialAccountRepository: FinancialAccountRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
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
}

public final class GRDBImportJobRepository: ImportJobRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchImportJobs(workspaceId: WorkspaceID) throws -> [ImportJob] {
        try dbPool.read { db in
            try ImportJob
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("startedAt").desc)
                .fetchAll(db)
        }
    }

    public func saveImportJob(_ job: ImportJob) throws {
        try dbPool.write { db in
            try job.save(db)
        }
    }
}

public final class GRDBStatementImportRepository: StatementImportRepository, @unchecked Sendable {
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

public final class GRDBTransactionRepository: TransactionRepository, @unchecked Sendable {
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

public final class GRDBDocumentRepository: DocumentRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchDocuments(workspaceId: WorkspaceID) throws -> [Document] {
        try dbPool.read { db in
            try Document
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("rowid").desc)
                .fetchAll(db)
        }
    }

    public func fetchDocument(id: DocumentID) throws -> Document? {
        try dbPool.read { db in
            try Document.fetchOne(db, key: id)
        }
    }

    public func fetchDocument(workspaceId: WorkspaceID, blobHash: String) throws -> Document? {
        try dbPool.read { db in
            try Document
                .filter(Column("workspaceId") == workspaceId && Column("blobHash") == blobHash)
                .fetchOne(db)
        }
    }

    public func fetchDocuments(ids: [DocumentID]) throws -> [Document] {
        guard ids.isEmpty == false else {
            return []
        }
        return try dbPool.read { db in
            try Document.filter(ids.contains(Column("id"))).fetchAll(db)
        }
    }

    public func saveDocument(_ document: Document) throws {
        try dbPool.write { db in
            try document.save(db)
        }
    }
}

public final class GRDBEvidenceLinkRepository: EvidenceLinkRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchEvidenceLinks(for objectRef: ObjectRef) throws -> [EvidenceLink] {
        try dbPool.read { db in
            try EvidenceLink
                .filter(Column("sourceRef") == objectRef || Column("targetRef") == objectRef)
                .fetchAll(db)
        }
    }

    public func saveEvidenceLink(_ evidenceLink: EvidenceLink) throws {
        try dbPool.write { db in
            try evidenceLink.save(db)
        }
    }
}

public final class GRDBAuditEventRepository: AuditEventRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchAuditEvents(workspaceId: WorkspaceID, objectRef: ObjectRef? = nil) throws -> [AuditEvent] {
        try dbPool.read { db in
            var request = AuditEvent
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("occurredAt").desc)

            if let objectRef {
                request = request.filter(Column("objectRef") == objectRef)
            }
            return try request.fetchAll(db)
        }
    }

    public func saveAuditEvent(_ event: AuditEvent) throws {
        try dbPool.write { db in
            try event.save(db)
        }
    }
}
