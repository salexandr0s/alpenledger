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
    public let vatPeriodRepository: any VATPeriodRepository
    public let ledgerAccountRepository: any LedgerAccountRepository
    public let financialAccountRepository: any FinancialAccountRepository
    public let counterpartyRepository: any CounterpartyRepository
    public let importJobRepository: any ImportJobRepository
    public let importDiagnosticRepository: any ImportDiagnosticRepository
    public let statementImportRepository: any StatementImportRepository
    public let transactionRepository: any TransactionRepository
    public let journalEntryRepository: any JournalEntryRepository
    public let documentRepository: any DocumentRepository
    public let evidenceLinkRepository: any EvidenceLinkRepository
    public let requirementRepository: any RequirementRepository
    public let issueRepository: any IssueRepository
    public let taxFactRepository: any TaxFactRepository
    public let agentProposalRepository: any AgentProposalRepository
    public let agentConversationRepository: any AgentConversationRepository
    public let entityWorkspaceRepository: any EntityWorkspaceRepository
    public let taxProfileRepository: any TaxProfileRepository
    public let categoryRepository: any TransactionCategoryRepository
    public let invoiceRecordRepository: any InvoiceRecordRepository
    public let filingPackageRepository: any FilingPackageRepository
    public let auditEventRepository: any AuditEventRepository

    public func inTransaction(_ work: (GRDB.Database) throws -> Void) throws {
        try dbPool.write(work)
    }
}

public final class WorkspaceStorageManager: @unchecked Sendable {
    let secretStore: any SecretStore
    let databasePoolProvider: any DatabasePoolProvider
    let databaseMigrator: (DatabasePool) throws -> Void
    let fileManager: FileManager
    let workspacesRootURL: URL?

    public init(
        secretStore: any SecretStore = KeychainSecretStore(),
        databasePoolProvider: any DatabasePoolProvider = SQLCipherDatabasePoolProvider(),
        fileManager: FileManager = .default,
        workspacesRootURL: URL? = nil
    ) {
        self.secretStore = secretStore
        self.databasePoolProvider = databasePoolProvider
        databaseMigrator = { dbPool in
            try migrate(dbPool: dbPool)
        }
        self.fileManager = fileManager
        self.workspacesRootURL = workspacesRootURL
    }

    init(
        secretStore: any SecretStore = KeychainSecretStore(),
        databasePoolProvider: any DatabasePoolProvider = SQLCipherDatabasePoolProvider(),
        databaseMigrator: @escaping (DatabasePool) throws -> Void,
        fileManager: FileManager = .default,
        workspacesRootURL: URL? = nil
    ) {
        self.secretStore = secretStore
        self.databasePoolProvider = databasePoolProvider
        self.databaseMigrator = databaseMigrator
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
        let migrationRecoverySnapshot = try migrationSnapshotNeeded(dbPool: dbPool)
            ? createMigrationRecoverySnapshot(paths: paths)
            : nil
        do {
            try databaseMigrator(dbPool)
            try removeMigrationRecoverySnapshots(paths: paths)
        } catch {
            try? dbPool.close()
            if let migrationRecoverySnapshot {
                try? restoreMigrationRecoverySnapshot(migrationRecoverySnapshot, paths: paths)
            }
            throw error
        }

        let blobStore = EncryptedBlobStore(paths: paths, key: crypto.blobKey, fileManager: fileManager)
        try? blobStore.cleanupMaterialized()
        let searchIndex = SQLiteSearchIndex(dbPool: dbPool)

        let workspaceRepository = GRDBWorkspaceRepository(dbPool: dbPool)
        let legalEntityRepository = GRDBLegalEntityRepository(dbPool: dbPool)
        let taxYearRepository = GRDBTaxYearRepository(dbPool: dbPool)
        let vatPeriodRepository = GRDBVATPeriodRepository(dbPool: dbPool)
        let ledgerAccountRepository = GRDBLedgerAccountRepository(dbPool: dbPool)
        let financialAccountRepository = GRDBFinancialAccountRepository(dbPool: dbPool)
        let counterpartyRepository = GRDBCounterpartyRepository(dbPool: dbPool)
        let importJobRepository = GRDBImportJobRepository(dbPool: dbPool)
        let importDiagnosticRepository = GRDBImportDiagnosticRepository(dbPool: dbPool)
        let statementImportRepository = GRDBStatementImportRepository(dbPool: dbPool)
        let transactionRepository = GRDBTransactionRepository(dbPool: dbPool)
        let journalEntryRepository = GRDBJournalEntryRepository(dbPool: dbPool)
        let documentRepository = GRDBDocumentRepository(dbPool: dbPool)
        let evidenceLinkRepository = GRDBEvidenceLinkRepository(dbPool: dbPool)
        let requirementRepository = GRDBRequirementRepository(dbPool: dbPool)
        let issueRepository = GRDBIssueRepository(dbPool: dbPool)
        let taxFactRepository = GRDBTaxFactRepository(dbPool: dbPool)
        let agentProposalRepository = GRDBAgentProposalRepository(dbPool: dbPool)
        let agentConversationRepository = GRDBAgentConversationRepository(dbPool: dbPool)
        let entityWorkspaceRepository = GRDBEntityWorkspaceRepository(dbPool: dbPool)
        let taxProfileRepository = GRDBTaxProfileRepository(dbPool: dbPool)
        let categoryRepository = GRDBTransactionCategoryRepository(dbPool: dbPool)
        let invoiceRecordRepository = GRDBInvoiceRecordRepository(dbPool: dbPool)
        let filingPackageRepository = GRDBFilingPackageRepository(dbPool: dbPool)
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
            vatPeriodRepository: vatPeriodRepository,
            ledgerAccountRepository: ledgerAccountRepository,
            financialAccountRepository: financialAccountRepository,
            counterpartyRepository: counterpartyRepository,
            importJobRepository: importJobRepository,
            importDiagnosticRepository: importDiagnosticRepository,
            statementImportRepository: statementImportRepository,
            transactionRepository: transactionRepository,
            journalEntryRepository: journalEntryRepository,
            documentRepository: documentRepository,
            evidenceLinkRepository: evidenceLinkRepository,
            requirementRepository: requirementRepository,
            issueRepository: issueRepository,
            taxFactRepository: taxFactRepository,
            agentProposalRepository: agentProposalRepository,
            agentConversationRepository: agentConversationRepository,
            entityWorkspaceRepository: entityWorkspaceRepository,
            taxProfileRepository: taxProfileRepository,
            categoryRepository: categoryRepository,
            invoiceRecordRepository: invoiceRecordRepository,
            filingPackageRepository: filingPackageRepository,
            auditEventRepository: auditEventRepository
        )
    }

    public func deleteWorkspace(
        _ storage: WorkspaceStorage,
        confirmingWorkspaceName confirmation: String
    ) throws {
        let expectedName = storage.manifest.workspace.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirmedName = confirmation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard confirmedName == expectedName else {
            throw DomainError.workspaceDeletionConfirmationMismatch
        }

        let rootURL = storage.paths.rootURL.standardizedFileURL
        guard fileManager.fileExists(atPath: storage.paths.manifestURL.path) else {
            throw DomainError.workspaceNotFound
        }

        try storage.dbPool.close()
        try fileManager.removeItem(at: rootURL)
        try secretStore.deleteWorkspaceMasterKey(workspaceId: storage.manifest.workspace.id)
    }

    private struct MigrationRecoverySnapshot {
        let rootURL: URL
        let files: [MigrationRecoveryFile]
    }

    private struct MigrationRecoveryFile {
        let filename: String
        let originalURL: URL
    }

    private func migrationSnapshotNeeded(dbPool: DatabasePool) throws -> Bool {
        try dbPool.read { db in
            guard try db.tableExists("grdb_migrations") else {
                return true
            }
            let appliedMigrationIdentifiers = try Set(String.fetchAll(
                db,
                sql: "SELECT identifier FROM grdb_migrations"
            ))
            return AlpenLedgerDatabaseMigrations.identifiers.contains {
                appliedMigrationIdentifiers.contains($0) == false
            }
        }
    }

    private func createMigrationRecoverySnapshot(paths: WorkspacePaths) throws -> MigrationRecoverySnapshot? {
        let sourceFiles = migrationDatabaseFileURLs(paths: paths).filter {
            fileManager.fileExists(atPath: $0.path)
        }
        guard sourceFiles.isEmpty == false else { return nil }

        let snapshotRoot = paths.rootURL
            .appendingPathComponent(".migration-recovery", isDirectory: true)
            .appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
        try fileManager.createDirectory(at: snapshotRoot, withIntermediateDirectories: true)

        var files: [MigrationRecoveryFile] = []
        do {
            for sourceURL in sourceFiles {
                let destinationURL = snapshotRoot.appendingPathComponent(sourceURL.lastPathComponent)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                files.append(MigrationRecoveryFile(filename: sourceURL.lastPathComponent, originalURL: sourceURL))
            }
            return MigrationRecoverySnapshot(rootURL: snapshotRoot, files: files)
        } catch {
            try? fileManager.removeItem(at: snapshotRoot)
            throw error
        }
    }

    private func restoreMigrationRecoverySnapshot(
        _ snapshot: MigrationRecoverySnapshot,
        paths: WorkspacePaths
    ) throws {
        for fileURL in migrationDatabaseFileURLs(paths: paths) where fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        for file in snapshot.files {
            let snapshotFileURL = snapshot.rootURL.appendingPathComponent(file.filename)
            if fileManager.fileExists(atPath: snapshotFileURL.path) {
                try fileManager.copyItem(at: snapshotFileURL, to: file.originalURL)
            }
        }
    }

    private func removeMigrationRecoverySnapshots(paths: WorkspacePaths) throws {
        let recoveryRoot = migrationRecoveryRootURL(paths: paths)
        if fileManager.fileExists(atPath: recoveryRoot.path) {
            try fileManager.removeItem(at: recoveryRoot)
        }
    }

    private func migrationRecoveryRootURL(paths: WorkspacePaths) -> URL {
        paths.rootURL.appendingPathComponent(".migration-recovery", isDirectory: true)
    }

    private func migrationDatabaseFileURLs(paths: WorkspacePaths) -> [URL] {
        let databasePath = paths.databaseURL.path
        return [
            paths.databaseURL,
            URL(fileURLWithPath: "\(databasePath)-wal"),
            URL(fileURLWithPath: "\(databasePath)-shm"),
            URL(fileURLWithPath: "\(databasePath)-journal"),
        ]
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
