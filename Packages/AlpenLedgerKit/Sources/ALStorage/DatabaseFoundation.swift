import Foundation
import GRDB
import ALDomain

public protocol DatabasePoolProvider: Sendable {
    func openDatabase(paths: WorkspacePaths, passphrase: String) throws -> DatabasePool
}

public struct SQLCipherDatabasePoolProvider: DatabasePoolProvider {
    public init() {}

    public func openDatabase(paths: WorkspacePaths, passphrase: String) throws -> DatabasePool {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.usePassphrase(passphrase)
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }
        return try DatabasePool(path: paths.databaseURL.path, configuration: configuration)
    }
}

public struct WorkspaceStorage: Sendable {
    public let manifest: WorkspaceManifest
    public let paths: WorkspacePaths
    public let dbPool: DatabasePool
    public let blobStore: any BlobStore
    public let searchIndex: any SearchIndex
    public let workspaceRepository: any WorkspaceRepository
    public let legalEntityRepository: any LegalEntityRepository
    public let taxYearRepository: any TaxYearRepository
    public let ledgerAccountRepository: any LedgerAccountRepository
    public let financialAccountRepository: any FinancialAccountRepository
    public let importJobRepository: any ImportJobRepository
    public let statementImportRepository: any StatementImportRepository
    public let transactionRepository: any TransactionRepository
    public let documentRepository: any DocumentRepository
    public let evidenceLinkRepository: any EvidenceLinkRepository
    public let requirementRepository: any RequirementRepository
    public let issueRepository: any IssueRepository
    public let taxFactRepository: any TaxFactRepository
    public let agentProposalRepository: any AgentProposalRepository
    public let auditEventRepository: any AuditEventRepository

    public func inTransaction(_ work: (GRDB.Database) throws -> Void) throws {
        try dbPool.write(work)
    }
}

public final class WorkspaceStorageManager: @unchecked Sendable {
    private let secretStore: any SecretStore
    private let databasePoolProvider: any DatabasePoolProvider
    private let fileManager: FileManager
    private let workspacesRootURL: URL?

    public init(
        secretStore: any SecretStore = KeychainSecretStore(),
        databasePoolProvider: any DatabasePoolProvider = SQLCipherDatabasePoolProvider(),
        fileManager: FileManager = .default,
        workspacesRootURL: URL? = nil
    ) {
        self.secretStore = secretStore
        self.databasePoolProvider = databasePoolProvider
        self.fileManager = fileManager
        self.workspacesRootURL = workspacesRootURL
    }

    public func defaultWorkspacesRoot() throws -> URL {
        if let workspacesRootURL {
            try fileManager.createDirectory(at: workspacesRootURL, withIntermediateDirectories: true)
            return workspacesRootURL
        }
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let rootURL = baseURL
            .appendingPathComponent("AlpenLedger", isDirectory: true)
            .appendingPathComponent("Workspaces", isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    public func createWorkspace(named name: String) throws -> WorkspaceStorage {
        let workspacesRoot = try defaultWorkspacesRoot()
        let rootURL = workspacesRoot.appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let paths = WorkspacePaths(rootURL: rootURL)
        try fileManager.createDirectory(at: paths.blobsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.exportsURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: paths.tempURL, withIntermediateDirectories: true)

        let salt = WorkspaceCrypto.generateSalt()
        let workspace = try Workspace(name: name, encryptionSaltRef: "workspace.json")
        let manifest = WorkspaceManifest(workspace: workspace, rootPath: rootURL.path, encryptionSalt: salt)
        let masterKey = WorkspaceCrypto.generateMasterKey()
        try secretStore.storeWorkspaceMasterKey(masterKey, workspaceId: workspace.id)
        try JSONEncoder.alpenLedger.encode(manifest).write(to: paths.manifestURL, options: .atomic)
        return try openWorkspace(at: rootURL)
    }

    public func openWorkspace(at rootURL: URL) throws -> WorkspaceStorage {
        let paths = WorkspacePaths(rootURL: rootURL)
        guard fileManager.fileExists(atPath: paths.manifestURL.path) else {
            throw DomainError.workspaceNotFound
        }

        let manifest = try JSONDecoder.alpenLedger.decode(
            WorkspaceManifest.self,
            from: Data(contentsOf: paths.manifestURL)
        )
        let masterKey = try secretStore.loadWorkspaceMasterKey(workspaceId: manifest.workspace.id)
        let crypto = WorkspaceCrypto(masterKeyData: masterKey, encryptionSalt: manifest.encryptionSalt)
        let dbPool = try databasePoolProvider.openDatabase(paths: paths, passphrase: crypto.databasePassphrase)
        try migrate(dbPool: dbPool)

        let blobStore = EncryptedBlobStore(paths: paths, key: crypto.blobKey, fileManager: fileManager)
        try? blobStore.cleanupMaterialized()
        let searchIndex = SQLiteSearchIndex(dbPool: dbPool)

        let workspaceRepository = GRDBWorkspaceRepository(dbPool: dbPool)
        let legalEntityRepository = GRDBLegalEntityRepository(dbPool: dbPool)
        let taxYearRepository = GRDBTaxYearRepository(dbPool: dbPool)
        let ledgerAccountRepository = GRDBLedgerAccountRepository(dbPool: dbPool)
        let financialAccountRepository = GRDBFinancialAccountRepository(dbPool: dbPool)
        let importJobRepository = GRDBImportJobRepository(dbPool: dbPool)
        let statementImportRepository = GRDBStatementImportRepository(dbPool: dbPool)
        let transactionRepository = GRDBTransactionRepository(dbPool: dbPool)
        let documentRepository = GRDBDocumentRepository(dbPool: dbPool)
        let evidenceLinkRepository = GRDBEvidenceLinkRepository(dbPool: dbPool)
        let requirementRepository = GRDBRequirementRepository(dbPool: dbPool)
        let issueRepository = GRDBIssueRepository(dbPool: dbPool)
        let taxFactRepository = GRDBTaxFactRepository(dbPool: dbPool)
        let agentProposalRepository = GRDBAgentProposalRepository(dbPool: dbPool)
        let auditEventRepository = GRDBAuditEventRepository(dbPool: dbPool)

        return WorkspaceStorage(
            manifest: manifest,
            paths: paths,
            dbPool: dbPool,
            blobStore: blobStore,
            searchIndex: searchIndex,
            workspaceRepository: workspaceRepository,
            legalEntityRepository: legalEntityRepository,
            taxYearRepository: taxYearRepository,
            ledgerAccountRepository: ledgerAccountRepository,
            financialAccountRepository: financialAccountRepository,
            importJobRepository: importJobRepository,
            statementImportRepository: statementImportRepository,
            transactionRepository: transactionRepository,
            documentRepository: documentRepository,
            evidenceLinkRepository: evidenceLinkRepository,
            requirementRepository: requirementRepository,
            issueRepository: issueRepository,
            taxFactRepository: taxFactRepository,
            agentProposalRepository: agentProposalRepository,
            auditEventRepository: auditEventRepository
        )
    }
}

public extension JSONEncoder {
    static var alpenLedger: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

public extension JSONDecoder {
    static var alpenLedger: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
