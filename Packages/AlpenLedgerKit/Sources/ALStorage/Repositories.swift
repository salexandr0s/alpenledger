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
    func deleteLegalEntity(_ entityId: LegalEntityID) throws
}

public protocol TaxYearRepository: Sendable {
    func fetchTaxYears(entityId: LegalEntityID) throws -> [TaxYear]
    func saveTaxYear(_ taxYear: TaxYear) throws
    func deleteTaxYears(entityId: LegalEntityID) throws
}

public protocol LedgerAccountRepository: Sendable {
    func fetchLedgerAccounts(entityId: LegalEntityID) throws -> [LedgerAccount]
    func saveLedgerAccount(_ account: LedgerAccount) throws
    func deleteLedgerAccounts(entityId: LegalEntityID) throws
}

public protocol FinancialAccountRepository: Sendable {
    func fetchFinancialAccounts(entityId: LegalEntityID) throws -> [FinancialAccount]
    func saveFinancialAccount(_ account: FinancialAccount) throws
    func deleteFinancialAccounts(entityId: LegalEntityID) throws
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

public protocol RequirementRepository: Sendable {
    func fetchRequirements(entityId: LegalEntityID, taxYearId: TaxYearID?) throws -> [Requirement]
    func fetchRequirement(fingerprint: String) throws -> Requirement?
    func saveRequirement(_ requirement: Requirement) throws
}

public extension RequirementRepository {
    func fetchRequirements(entityId: LegalEntityID) throws -> [Requirement] {
        try fetchRequirements(entityId: entityId, taxYearId: nil)
    }
}

public protocol IssueRepository: Sendable {
    func fetchIssues(workspaceId: WorkspaceID, entityId: LegalEntityID?, taxYearId: TaxYearID?, status: IssueStatus?) throws -> [Issue]
    func fetchIssue(id: IssueID) throws -> Issue?
    func fetchIssue(fingerprint: String) throws -> Issue?
    func saveIssue(_ issue: Issue) throws
}

public extension IssueRepository {
    func fetchIssues(workspaceId: WorkspaceID, status: IssueStatus?) throws -> [Issue] {
        try fetchIssues(workspaceId: workspaceId, entityId: nil, taxYearId: nil, status: status)
    }
}

public protocol TaxFactRepository: Sendable {
    func fetchTaxFacts(entityId: LegalEntityID, taxYearId: TaxYearID, currentOnly: Bool) throws -> [TaxFact]
    func fetchTaxFact(fingerprint: String, isCurrent: Bool?) throws -> TaxFact?
    func saveTaxFact(_ fact: TaxFact) throws
}

public protocol AgentProposalRepository: Sendable {
    func fetchAgentProposals(workspaceId: WorkspaceID, status: ProposalStatus?) throws -> [AgentProposal]
    func fetchAgentProposal(id: AgentProposalID) throws -> AgentProposal?
    func fetchAgentProposal(fingerprint: String) throws -> AgentProposal?
    func saveAgentProposal(_ proposal: AgentProposal) throws
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
extension Requirement: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "requirements"
}
extension Issue: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "issues"
}
extension AgentProposal: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "agentProposals"
}
extension AuditEvent: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "auditEvents"
}

extension TaxFact: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "taxFacts"

    public init(row: Row) {
        self.init(
            id: row["id"],
            fingerprint: row["fingerprint"],
            entityId: row["entityId"],
            taxYearId: row["taxYearId"],
            jurisdictionCode: row["jurisdictionCode"],
            conceptCode: row["conceptCode"],
            valueType: TaxFactValueType(rawValue: row["valueType"]) ?? .text,
            moneyMinor: row["moneyMinor"],
            textValue: row["textValue"],
            boolValue: row["boolValue"],
            dateValue: row["dateValue"],
            currency: row["currency"],
            status: TaxFactStatus(rawValue: row["status"]) ?? .derived,
            rulesetVersion: row["rulesetVersion"],
            provenanceRefs: TaxFact.decodeProvenanceRefs(from: row["provenanceRefs"]),
            confidence: row["confidence"],
            supersedesFactId: row["supersedesFactId"],
            isCurrent: row["isCurrent"],
            overrideReason: row["overrideReason"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["fingerprint"] = fingerprint
        container["entityId"] = entityId
        container["taxYearId"] = taxYearId
        container["jurisdictionCode"] = jurisdictionCode
        container["conceptCode"] = conceptCode
        container["valueType"] = valueType.rawValue
        container["moneyMinor"] = moneyMinor
        container["textValue"] = textValue
        container["boolValue"] = boolValue
        container["dateValue"] = dateValue
        container["currency"] = currency
        container["status"] = status.rawValue
        container["rulesetVersion"] = rulesetVersion
        container["provenanceRefs"] = TaxFact.encodeProvenanceRefs(provenanceRefs)
        container["confidence"] = confidence
        container["supersedesFactId"] = supersedesFactId
        container["isCurrent"] = isCurrent
        container["overrideReason"] = overrideReason
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }

    private static func encodeProvenanceRefs(_ refs: [ObjectRef]) -> String {
        guard let data = try? JSONEncoder.alpenLedger.encode(refs),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    private static func decodeProvenanceRefs(from rawValue: String?) -> [ObjectRef] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let refs = try? JSONDecoder.alpenLedger.decode([ObjectRef].self, from: data)
        else {
            return []
        }
        return refs
    }
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

    public func deleteLegalEntity(_ entityId: LegalEntityID) throws {
        try dbPool.write { db in
            _ = try LegalEntity.deleteOne(db, key: entityId)
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

    public func deleteTaxYears(entityId: LegalEntityID) throws {
        try dbPool.write { db in
            _ = try TaxYear.filter(Column("entityId") == entityId).deleteAll(db)
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

    public func deleteLedgerAccounts(entityId: LegalEntityID) throws {
        try dbPool.write { db in
            _ = try LedgerAccount.filter(Column("entityId") == entityId).deleteAll(db)
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

    public func deleteFinancialAccounts(entityId: LegalEntityID) throws {
        try dbPool.write { db in
            _ = try FinancialAccount.filter(Column("entityId") == entityId).deleteAll(db)
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

public final class GRDBRequirementRepository: RequirementRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchRequirements(entityId: LegalEntityID, taxYearId: TaxYearID? = nil) throws -> [Requirement] {
        try dbPool.read { db in
            var request = Requirement
                .filter(Column("entityId") == entityId)
                .order(Column("updatedAt").desc)

            if let taxYearId {
                request = request.filter(Column("taxYearId") == taxYearId)
            }

            return try request.fetchAll(db)
        }
    }

    public func fetchRequirement(fingerprint: String) throws -> Requirement? {
        try dbPool.read { db in
            try Requirement
                .filter(Column("fingerprint") == fingerprint)
                .fetchOne(db)
        }
    }

    public func saveRequirement(_ requirement: Requirement) throws {
        try dbPool.write { db in
            try requirement.save(db)
        }
    }
}

public final class GRDBIssueRepository: IssueRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchIssues(
        workspaceId: WorkspaceID,
        entityId: LegalEntityID? = nil,
        taxYearId: TaxYearID? = nil,
        status: IssueStatus? = nil
    ) throws -> [Issue] {
        try dbPool.read { db in
            var request = Issue
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("lastDetectedAt").desc)

            if let entityId {
                request = request.filter(Column("entityId") == entityId)
            }
            if let taxYearId {
                request = request.filter(Column("taxYearId") == taxYearId)
            }
            if let status {
                request = request.filter(Column("status") == status.rawValue)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchIssue(fingerprint: String) throws -> Issue? {
        try dbPool.read { db in
            try Issue
                .filter(Column("fingerprint") == fingerprint)
                .fetchOne(db)
        }
    }

    public func fetchIssue(id: IssueID) throws -> Issue? {
        try dbPool.read { db in
            try Issue.fetchOne(db, key: id)
        }
    }

    public func saveIssue(_ issue: Issue) throws {
        try dbPool.write { db in
            try issue.save(db)
        }
    }
}

public final class GRDBTaxFactRepository: TaxFactRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchTaxFacts(entityId: LegalEntityID, taxYearId: TaxYearID, currentOnly: Bool = true) throws -> [TaxFact] {
        try dbPool.read { db in
            var request = TaxFact
                .filter(Column("entityId") == entityId && Column("taxYearId") == taxYearId)
                .order(Column("conceptCode"), Column("createdAt").desc)

            if currentOnly {
                request = request.filter(Column("isCurrent") == true)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchTaxFact(fingerprint: String, isCurrent: Bool? = nil) throws -> TaxFact? {
        try dbPool.read { db in
            var request = TaxFact
                .filter(Column("fingerprint") == fingerprint)
                .order(Column("createdAt").desc)

            if let isCurrent {
                request = request.filter(Column("isCurrent") == isCurrent)
            }
            return try request.fetchOne(db)
        }
    }

    public func saveTaxFact(_ fact: TaxFact) throws {
        try dbPool.write { db in
            try fact.save(db)
        }
    }
}

public final class GRDBAgentProposalRepository: AgentProposalRepository, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchAgentProposals(workspaceId: WorkspaceID, status: ProposalStatus? = nil) throws -> [AgentProposal] {
        try dbPool.read { db in
            var request = AgentProposal
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("createdAt").desc)

            if let status {
                request = request.filter(Column("status") == status.rawValue)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchAgentProposal(fingerprint: String) throws -> AgentProposal? {
        try dbPool.read { db in
            try AgentProposal
                .filter(Column("fingerprint") == fingerprint)
                .fetchOne(db)
        }
    }

    public func fetchAgentProposal(id: AgentProposalID) throws -> AgentProposal? {
        try dbPool.read { db in
            try AgentProposal.fetchOne(db, key: id)
        }
    }

    public func saveAgentProposal(_ proposal: AgentProposal) throws {
        try dbPool.write { db in
            try proposal.save(db)
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
