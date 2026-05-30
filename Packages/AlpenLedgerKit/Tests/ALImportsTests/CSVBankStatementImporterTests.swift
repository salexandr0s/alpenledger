import Foundation
import Testing
@testable import ALAudit
@testable import ALImports
@testable import ALLedger
@testable import ALDomain
@testable import ALStorage
@testable import ALWorkspace

@Test
func csvImporterRecognizesFixtureHeader() throws {
    let importer = CSVBankStatementImporter()
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-bank-statement.csv")

    #expect(try importer.canRecognize(fixtureURL))
}

@Test
func csvImporterParsesRowsIntoTransactions() throws {
    let importer = CSVBankStatementImporter()
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-bank-statement.csv")
    let payload = try importer.parse(
        fixtureURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "fixture"
    )

    #expect(payload.transactions.count == 3)
    #expect(payload.statementImport.sourceFormat == "csv")
    #expect(payload.parseLog.importedRowCount == 3)
}

@Test
func csvImporterExposesVersionedColumnMappingPresets() {
    let presetKeys = CSVBankStatementImporter.defaultPresets.map(\.key)

    #expect(CSVBankStatementImporter().parserVersion == "1.2.0")
    #expect(presetKeys.contains("canonical.alpenledger"))
    #expect(presetKeys.contains("generic.swiss"))
    #expect(presetKeys.contains("postfinance.ch"))
}

@Test
func csvImporterParsesSwissSemicolonMappedStatement() throws {
    let importer = CSVBankStatementImporter()
    let csvURL = try writeTemporaryCSV("""
    Buchungsdatum;Valutadatum;Betrag;Währung;Gegenpartei;Buchungstext;Referenz;Saldo
    31.01.2026;31.01.2026;-1'234.50;CHF;SBB AG;Billette;TICKET-1;10'000.25
    """)

    let payload = try importer.parse(
        csvURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "mapped"
    )

    #expect(try importer.canRecognize(csvURL))
    #expect(payload.transactions.count == 1)
    #expect(payload.transactions[0].amountMinor == -123_450)
    #expect(payload.transactions[0].balanceAfterMinor == 1_000_025)
    #expect(payload.transactions[0].counterpartyName == "SBB AG")
    #expect(payload.transactions[0].reference == "TICKET-1")
}

@Test
func csvImporterParsesDebitCreditPresetColumns() throws {
    let importer = CSVBankStatementImporter()
    let csvURL = try writeTemporaryCSV("""
    Buchungsdatum;Valutadatum;Gutschrift in CHF;Lastschrift in CHF;Buchungstext;Mitteilungen;Referenz;Saldo in CHF
    01.02.2026;01.02.2026;2'500.00;;Example GmbH;Invoice payment;INV-1;12'500.00
    02.02.2026;02.02.2026;;42.50;Coffee Bar;Team coffee;POS-1;12'457.50
    """)

    let payload = try importer.parse(
        csvURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "debit-credit"
    )

    #expect(try importer.canRecognize(csvURL))
    #expect(payload.transactions.map(\.amountMinor) == [250_000, -4_250])
    #expect(payload.transactions.map(\.balanceAfterMinor) == [1_250_000, 1_245_750])
    #expect(payload.transactions.map(\.counterpartyName) == ["Example GmbH", "Coffee Bar"])
    #expect(payload.transactions.map(\.currency) == [.chf, .chf])
}

@Test
func csvImporterRejectsUnmappedCSVHeader() throws {
    let importer = CSVBankStatementImporter()
    let csvURL = try writeTemporaryCSV("""
    product,sku,quantity
    Mug,ABC,2
    """)

    #expect(try importer.canRecognize(csvURL) == false)
    #expect(throws: DomainError.unsupportedImportFormat) {
        _ = try importer.parse(
            csvURL,
            accountId: FinancialAccountID(),
            importJobId: ImportJobID(),
            sourceBlobHash: "unmapped"
        )
    }
}

@Test
func importJobServicePersistsCSVParseDiagnostics() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: tempRoot
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "CSV Diagnostics Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let csvURL = try writeTemporaryCSV("""
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,100.00,CHF,Valid,Payment,REF1,100.00
    2026-01-16,2026-01-16,abc,CHF,Invalid,Payment,REF2,100.00
    """)

    let parseLog = try importJobService.importStatement(from: csvURL, accountId: account.id)

    let importJob = try #require(try importJobService.listImportJobs().first)
    let diagnostics = try importJobService.listImportDiagnostics(importJobId: importJob.id)

    #expect(parseLog.diagnostics.count == 1)
    #expect(parseLog.warnings.count == 1)
    #expect(importJob.warningCount == 1)
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.severity == .warning)
    #expect(diagnostics.first?.code == "csv.unparseable_amount")
    #expect(diagnostics.first?.location == "csv:3")
    #expect(diagnostics.first?.message.contains("unparseable amount") == true)
}

@Test
func importJobServiceBracketsStatementSourceWithSecurityScopedAccess() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: tempRoot
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "Security Scoped Statement Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let recorder = ImportSecurityScopeRecorder()
    let importJobService = ImportJobService(
        storage: storage,
        auditLogger: AuditLogger(storage: storage),
        fileAccess: recorder.access
    )
    let csvURL = try writeTemporaryCSV("""
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,100.00,CHF,Scoped Shop,Payment,REF1,100.00
    """)

    let parseLog = try importJobService.importStatement(from: csvURL, accountId: account.id)

    #expect(parseLog.importedRowCount == 1)
    #expect(recorder.startedPaths == [csvURL.standardizedFileURL.path])
    #expect(recorder.stoppedPaths == [csvURL.standardizedFileURL.path])
}

@Test
func importJobServiceCommitsSuccessfulCSVRowsAndAuditEventsTogether() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: tempRoot
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "CSV Atomic Audit Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let csvURL = try writeTemporaryCSV("""
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,100.00,CHF,Audit Vendor,Payment,AUDIT-1,100.00
    """)

    let parseLog = try importJobService.importStatement(from: csvURL, accountId: account.id)

    let importJob = try #require(try importJobService.listImportJobs().first)
    let statement = try #require(try storage.statementImportRepository.fetchStatementImports(accountId: account.id).first)
    let transactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)
    let importJobAuditEvents = try storage.auditEventRepository.fetchAuditEvents(
        workspaceId: storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .importJob, id: importJob.id.rawValue)
    )
    let statementAuditEvents = try storage.auditEventRepository.fetchAuditEvents(
        workspaceId: storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .statementImport, id: statement.id.rawValue)
    )

    #expect(parseLog.importedRowCount == 1)
    #expect(transactions.count == 1)
    #expect(importJob.status == .completed)
    #expect(importJobAuditEvents.contains { $0.eventType == .importJobCompleted })
    #expect(statementAuditEvents.contains { $0.eventType == .statementImported })
}

@Test
func importJobServicePersistsFailureDiagnosticForRejectedCSV() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: tempRoot
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "CSV Failure Diagnostics Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let csvURL = try writeTemporaryCSV("""
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    """)

    #expect(throws: DomainError.self) {
        _ = try importJobService.importStatement(from: csvURL, accountId: account.id)
    }

    let importJob = try #require(try importJobService.listImportJobs().first)
    let diagnostics = try importJobService.listImportDiagnostics(importJobId: importJob.id)

    #expect(importJob.status == .failed)
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.severity == .error)
    #expect(diagnostics.first?.code == "import.unsupported_format")
    #expect(diagnostics.first?.message.contains("not supported") == true)
}

@Test
func importJobServiceRejectsCorruptCSVWithoutPersistingPartialRows() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: tempRoot
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "CSV Corrupt File Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let csvURL = try writeTemporaryCSV("""
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    not-a-date,2026-01-15,abc,CHF,Corrupt Vendor,Payment,BAD-1,100.00
    2026-01-16,2026-01-16,also-bad,CHF,Corrupt Vendor,Payment,BAD-2,100.00
    """)

    #expect(throws: DomainError.self) {
        _ = try importJobService.importStatement(from: csvURL, accountId: account.id)
    }

    let importJob = try #require(try importJobService.listImportJobs().first)
    let diagnostics = try importJobService.listImportDiagnostics(importJobId: importJob.id)
    let statements = try storage.statementImportRepository.fetchStatementImports(accountId: account.id)
    let transactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)

    #expect(importJob.status == .failed)
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.severity == .error)
    #expect(diagnostics.first?.code == "import.corrupt_file")
    #expect(diagnostics.first?.message.contains("CSV parse error") == true)
    #expect(statements.isEmpty)
    #expect(transactions.isEmpty)
}

@Test
func importJobServiceCancelsCSVWithoutPersistingRowsAndAllowsResume() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: tempRoot
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "CSV Cancellation Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let csvURL = try writeTemporaryCSV("""
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,100.00,CHF,Resume Vendor,Payment,RESUME-1,100.00
    """)
    let cancellationProbe = CancellationProbe(cancelOnCheck: 2)

    #expect(throws: ImportCancellationError.self) {
        _ = try importJobService.importStatement(
            from: csvURL,
            accountId: account.id,
            isCancellationRequested: cancellationProbe.shouldCancel
        )
    }

    let cancelledJob = try #require(try importJobService.listImportJobs().first)
    let cancelledDiagnostics = try importJobService.listImportDiagnostics(importJobId: cancelledJob.id)
    let auditEvents = try storage.auditEventRepository.fetchAuditEvents(
        workspaceId: storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .importJob, id: cancelledJob.id.rawValue)
    )
    #expect(cancelledJob.status == .cancelled)
    #expect(cancelledDiagnostics.count == 1)
    #expect(cancelledDiagnostics.first?.severity == .warning)
    #expect(cancelledDiagnostics.first?.code == "import.cancelled")
    #expect(try storage.statementImportRepository.fetchStatementImports(accountId: account.id).isEmpty)
    #expect(try storage.transactionRepository.fetchTransactions(accountId: account.id).isEmpty)
    #expect(auditEvents.contains { $0.eventType == .importJobCancelled })

    let parseLog = try importJobService.importStatement(from: csvURL, accountId: account.id)
    let importJobs = try importJobService.listImportJobs()
    let statements = try storage.statementImportRepository.fetchStatementImports(accountId: account.id)
    let transactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)

    #expect(parseLog.importedRowCount == 1)
    #expect(importJobs.contains { $0.id == cancelledJob.id && $0.status == .cancelled })
    #expect(importJobs.contains { $0.id != cancelledJob.id && $0.status == .completed })
    #expect(statements.count == 1)
    #expect(transactions.count == 1)
}

@Test
func importJobServiceRetriesCancelledCSVFromStoredSourceBlob() throws {
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: tempRoot
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "CSV Stored Retry Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let csvURL = try writeTemporaryCSV("""
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,100.00,CHF,Stored Retry Vendor,Payment,RETRY-1,100.00
    """)
    let cancellationProbe = CancellationProbe(cancelOnCheck: 2)

    #expect(throws: ImportCancellationError.self) {
        _ = try importJobService.importStatement(
            from: csvURL,
            accountId: account.id,
            isCancellationRequested: cancellationProbe.shouldCancel
        )
    }

    let cancelledJob = try #require(try importJobService.listImportJobs().first)
    let sourceBlobHash = try #require(cancelledJob.sourceBlobHash)
    try FileManager.default.removeItem(at: csvURL)

    let parseLog = try importJobService.retryStatementImport(importJobId: cancelledJob.id, accountId: account.id)

    let importJobs = try importJobService.listImportJobs()
    let retriedJob = try #require(importJobs.first { $0.id != cancelledJob.id && $0.sourceBlobHash == sourceBlobHash })
    let statements = try storage.statementImportRepository.fetchStatementImports(accountId: account.id)
    let transactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)

    #expect(cancelledJob.status == .cancelled)
    #expect(try storage.blobStore.contains(hash: sourceBlobHash))
    #expect(parseLog.importedRowCount == 1)
    #expect(retriedJob.status == .completed)
    #expect(retriedJob.source == csvURL.lastPathComponent)
    #expect(statements.count == 1)
    #expect(transactions.count == 1)
    #expect(throws: DomainError.self) {
        _ = try importJobService.retryStatementImport(importJobId: cancelledJob.id, accountId: account.id)
    }
}

@Test
func importJobServiceRecoversInterruptedStartedImports() throws {
    let recoveryDate = Date(timeIntervalSince1970: 1_767_270_000)
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: tempRoot
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "CSV Recovery Workspace")
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let interruptedJob = ImportJob(
        workspaceId: storage.manifest.workspace.id,
        kind: .bankStatementCSV,
        source: "interrupted-statement.csv",
        sourceBlobHash: "interrupted-source",
        parserKey: "csv.bankstatement",
        parserVersion: "1.1.0",
        startedAt: Date(timeIntervalSince1970: 1_767_180_000)
    )
    let completedJob = ImportJob(
        workspaceId: storage.manifest.workspace.id,
        kind: .bankStatementCSV,
        source: "completed-statement.csv",
        sourceBlobHash: "completed-source",
        parserKey: "csv.bankstatement",
        parserVersion: "1.1.0",
        status: .completed,
        startedAt: Date(timeIntervalSince1970: 1_767_181_000),
        completedAt: Date(timeIntervalSince1970: 1_767_181_120)
    )
    try storage.importJobRepository.saveImportJob(interruptedJob)
    try storage.importJobRepository.saveImportJob(completedJob)

    let recoveredJobs = try importJobService.recoverInterruptedImports(recoveredAt: recoveryDate)

    let importJobs = try importJobService.listImportJobs()
    let recoveredJob = try #require(importJobs.first { $0.id == interruptedJob.id })
    let untouchedJob = try #require(importJobs.first { $0.id == completedJob.id })
    let diagnostics = try importJobService.listImportDiagnostics(importJobId: interruptedJob.id)
    let auditEvents = try storage.auditEventRepository.fetchAuditEvents(
        workspaceId: storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .importJob, id: interruptedJob.id.rawValue)
    )

    #expect(recoveredJobs.map(\.id) == [interruptedJob.id])
    #expect(recoveredJob.status == .failed)
    #expect(recoveredJob.completedAt == recoveryDate)
    #expect(recoveredJob.warningCount == 1)
    #expect(untouchedJob.status == .completed)
    #expect(untouchedJob.completedAt == completedJob.completedAt)
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.severity == .error)
    #expect(diagnostics.first?.code == "import.interrupted")
    #expect(diagnostics.first?.createdAt == recoveryDate)
    #expect(auditEvents.contains { $0.eventType == .importJobRecovered })
}

private final class CancellationProbe: @unchecked Sendable {
    private let cancelOnCheck: Int
    private var checkCount = 0

    init(cancelOnCheck: Int) {
        self.cancelOnCheck = cancelOnCheck
    }

    func shouldCancel() -> Bool {
        checkCount += 1
        return checkCount >= cancelOnCheck
    }
}

@Test
func csvImportJobHandlesCustomerScaleFixtureWithinRegressionBudget() throws {
    let rowCount = 2_500
    let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: tempRoot
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "CSV Throughput Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let csvURL = try fixtureURL("Fixtures/Bank/sample-bank-statement-customer-scale.csv")

    let clock = ContinuousClock()
    let startedAt = clock.now
    let parseLog = try importJobService.importStatement(from: csvURL, accountId: account.id)
    let elapsed = startedAt.duration(to: clock.now)

    let transactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)
    let statements = try storage.statementImportRepository.fetchStatementImports(accountId: account.id)
    let importJob = try #require(try importJobService.listImportJobs().first)
    let counterparties = try storage.counterpartyRepository.fetchCounterparties(entityId: entity.id, includeMerged: false)
    let auditEvents = try storage.auditEventRepository.fetchAuditEvents(
        workspaceId: storage.manifest.workspace.id,
        objectRef: nil
    )

    #expect(parseLog.importedRowCount == rowCount)
    #expect(parseLog.diagnostics.isEmpty)
    #expect(transactions.count == rowCount)
    #expect(statements.count == 1)
    #expect(importJob.status == .completed)
    #expect(importJob.warningCount == 0)
    #expect(counterparties.count == 80)
    #expect(auditEvents.contains { $0.eventType == .importJobCreated })
    #expect(auditEvents.contains { $0.eventType == .importJobCompleted })
    #expect(auditEvents.contains { $0.eventType == .statementImported })
    if enforcePerformanceBudgets {
        #expect(elapsed < .seconds(12))
    }
}

@Test
func customerScaleStatementImportSurvivesBackupRestoreDrill() throws {
    let rowCount = 2_500
    let fileManager = FileManager.default
    let tempRoot = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("customer-scale-import.alpenledgerbackup", isDirectory: true)
    let secretStore = InMemorySecretStore()
    let storageManager = WorkspaceStorageManager(
        secretStore: secretStore,
        workspacesRootURL: tempRoot
    )
    let defaultsSuiteName = "CustomerScaleRestore.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
    defaults.removePersistentDomain(forName: defaultsSuiteName)
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: defaults),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "Customer Scale Restore Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let csvURL = try fixtureURL("Fixtures/Bank/sample-bank-statement-customer-scale.csv")
    let sourceBytes = try Data(contentsOf: csvURL)

    let parseLog = try importJobService.importStatement(from: csvURL, accountId: account.id)
    let importJob = try #require(try importJobService.listImportJobs().first)
    let sourceBlobHash = try #require(importJob.sourceBlobHash)
    let sourceFingerprint = try #require(importJob.sourceFingerprint)
    let statement = try #require(try storage.statementImportRepository.fetchStatementImports(accountId: account.id).first)

    #expect(parseLog.importedRowCount == rowCount)
    #expect(parseLog.diagnostics.isEmpty)
    #expect(try storage.transactionRepository.fetchTransactions(accountId: account.id).count == rowCount)
    #expect(statement.sourceBlobHash == sourceBlobHash)
    #expect(statement.sourceFingerprint == sourceFingerprint)
    #expect(try storage.blobStore.read(hash: sourceBlobHash) == sourceBytes)

    let backupManifest = try workspaceService.createBackup(for: storage, at: backupURL)
    #expect(backupManifest.fileHashes.contains { $0.relativePath.hasPrefix("workspace/blobs/") })
    let backupIntegrityReport = try workspaceService.validateBackup(at: backupURL)
    #expect(backupIntegrityReport.isRestorable)
    #expect(backupIntegrityReport.issues.isEmpty)

    try secretStore.deleteWorkspaceMasterKey(workspaceId: storage.manifest.workspace.id)
    let restoredStorage = try workspaceService.restoreBackup(from: backupURL)
    let restoredImportJobs = try restoredStorage.importJobRepository.fetchImportJobs(workspaceId: restoredStorage.manifest.workspace.id)
    let restoredImportJob = try #require(restoredImportJobs.first { $0.id == importJob.id })
    let restoredStatements = try restoredStorage.statementImportRepository.fetchStatementImports(accountId: account.id)
    let restoredTransactions = try restoredStorage.transactionRepository.fetchTransactions(accountId: account.id)
    let restoredCounterparties = try restoredStorage.counterpartyRepository.fetchCounterparties(
        entityId: entity.id,
        includeMerged: false
    )
    let restoredAuditEvents = try restoredStorage.auditEventRepository.fetchAuditEvents(
        workspaceId: restoredStorage.manifest.workspace.id,
        objectRef: nil
    )

    #expect(restoredStorage.paths.rootURL != storage.paths.rootURL)
    #expect(restoredImportJob.status == .completed)
    #expect(restoredImportJob.sourceBlobHash == sourceBlobHash)
    #expect(restoredImportJob.sourceFingerprint == sourceFingerprint)
    #expect(restoredStatements.count == 1)
    #expect(restoredStatements.first?.sourceBlobHash == sourceBlobHash)
    #expect(restoredStatements.first?.sourceFingerprint == sourceFingerprint)
    #expect(restoredTransactions.count == rowCount)
    #expect(restoredCounterparties.count == 80)
    #expect(try restoredStorage.blobStore.read(hash: sourceBlobHash) == sourceBytes)
    #expect(restoredAuditEvents.contains { $0.eventType == .workspaceRestored })
    #expect(workspaceService.recentWorkspaces().first?.path == restoredStorage.paths.rootURL.path)
}

private func fixtureURL(_ relativePath: String) throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let url = packageRoot.appendingPathComponent(relativePath)
    return url
}

private var enforcePerformanceBudgets: Bool {
    ProcessInfo.processInfo.environment["ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS"] == "1"
}

private func writeTemporaryCSV(_ content: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("csv")
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private final class ImportSecurityScopeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var starts: [String] = []
    private var stops: [String] = []

    var access: SecurityScopedResourceAccess {
        SecurityScopedResourceAccess(
            startAccessing: { [self] url in
                recordStart(url)
                return true
            },
            stopAccessing: { [self] url in
                recordStop(url)
            }
        )
    }

    var startedPaths: [String] {
        withLock { starts }
    }

    var stoppedPaths: [String] {
        withLock { stops }
    }

    private func recordStart(_ url: URL) {
        withLock {
            starts.append(url.standardizedFileURL.path)
        }
    }

    private func recordStop(_ url: URL) {
        withLock {
            stops.append(url.standardizedFileURL.path)
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
