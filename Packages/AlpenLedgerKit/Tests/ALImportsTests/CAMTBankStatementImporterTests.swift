import Foundation
import Testing
@testable import ALAudit
@testable import ALDomain
@testable import ALImports
@testable import ALLedger
@testable import ALStorage
@testable import ALWorkspace

@Test
func camt053ImporterRecognizesFixture() throws {
    let importer = CAMTBankStatementImporter()
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-camt053-statement.xml")

    #expect(try importer.canRecognize(fixtureURL))
}

@Test
func camt052ImporterRecognizesFixture() throws {
    let importer = CAMTBankStatementImporter(format: .camt052)
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-camt052-report.xml")

    #expect(try importer.canRecognize(fixtureURL))
}

@Test
func camt054ImporterRecognizesFixture() throws {
    let importer = CAMTBankStatementImporter(format: .camt054)
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-camt054-notification.xml")

    #expect(try importer.canRecognize(fixtureURL))
}

@Test
func camt053ImporterParsesBalancesAndTransactions() throws {
    let importer = CAMTBankStatementImporter()
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-camt053-statement.xml")
    let payload = try importer.parse(
        fixtureURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "fixture"
    )

    #expect(payload.statementImport.sourceFormat == "camt.053")
    #expect(payload.statementImport.openingBalanceMinor == 0)
    #expect(payload.statementImport.closingBalanceMinor == 233_750)
    #expect(payload.parseLog.parserKey == "camt.053.bankstatement")
    #expect(payload.parseLog.importedRowCount == 3)
    #expect(payload.parseLog.warnings.isEmpty)

    #expect(payload.transactions.map(\.amountMinor) == [250_000, -4_250, -12_000])
    #expect(payload.transactions.map(\.currency) == [.chf, .chf, .chf])
    #expect(payload.transactions.map(\.counterpartyName) == [
        "Alpine Consulting Client AG",
        "Coffee Bar Zurich",
        "SBB",
    ])
    #expect(payload.transactions.map(\.reference) == ["INV-1001", "POS-444", "TRV-220"])
    #expect(payload.transactions.map(\.sourceLineRef) == ["camt:1", "camt:2", "camt:3"])
}

@Test
func camt052ImporterParsesReportBalancesAndTransactions() throws {
    let importer = CAMTBankStatementImporter(format: .camt052)
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-camt052-report.xml")
    let payload = try importer.parse(
        fixtureURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "fixture"
    )

    #expect(payload.statementImport.sourceFormat == "camt.052")
    #expect(payload.statementImport.openingBalanceMinor == 100_000)
    #expect(payload.statementImport.closingBalanceMinor == 87_500)
    #expect(payload.parseLog.parserKey == "camt.052.bankstatement")
    #expect(payload.parseLog.importedRowCount == 2)
    #expect(payload.parseLog.warnings.isEmpty)

    #expect(payload.transactions.map(\.amountMinor) == [50_000, -62_500])
    #expect(payload.transactions.map(\.currency) == [.chf, .chf])
    #expect(payload.transactions.map(\.counterpartyName) == [
        "Health Insurer AG",
        "Office Rent AG",
    ])
    #expect(payload.transactions.map(\.reference) == ["HLT-2026-02", "RENT-2026-02"])
    #expect(payload.transactions.map(\.sourceLineRef) == ["camt:1", "camt:2"])
}

@Test
func camt052ImporterParsesMultiReportCoverageAndBalances() throws {
    let importer = CAMTBankStatementImporter(format: .camt052)
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-camt052-multi-report.xml")
    let payload = try importer.parse(
        fixtureURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "fixture"
    )

    #expect(try importer.canRecognize(fixtureURL))
    #expect(payload.statementImport.sourceFormat == "camt.052")
    #expect(payload.statementImport.coverageStart == isoDate("2026-04-01T00:00:00Z"))
    #expect(payload.statementImport.coverageEnd == isoDate("2026-04-30T23:59:59Z"))
    #expect(payload.statementImport.openingBalanceMinor == 200_000)
    #expect(payload.statementImport.closingBalanceMinor == 232_500)
    #expect(payload.parseLog.importedRowCount == 2)
    #expect(payload.parseLog.warnings.isEmpty)
    #expect(payload.transactions.map(\.amountMinor) == [50_000, -17_500])
    #expect(payload.transactions.map(\.reference) == ["WORK-2026-04", "CLOUD-2026-04"])
    #expect(payload.transactions.map(\.sourceLineRef) == ["camt:1", "camt:2"])
}

@Test
func camt054ImporterParsesNotificationTransactions() throws {
    let importer = CAMTBankStatementImporter(format: .camt054)
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-camt054-notification.xml")
    let payload = try importer.parse(
        fixtureURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "fixture"
    )

    #expect(payload.statementImport.sourceFormat == "camt.054")
    #expect(payload.statementImport.openingBalanceMinor == nil)
    #expect(payload.statementImport.closingBalanceMinor == nil)
    #expect(payload.parseLog.parserKey == "camt.054.bankstatement")
    #expect(payload.parseLog.importedRowCount == 2)
    #expect(payload.parseLog.warnings.isEmpty)

    #expect(payload.transactions.map(\.amountMinor) == [150_000, -3_000])
    #expect(payload.transactions.map(\.currency) == [.chf, .chf])
    #expect(payload.transactions.map(\.counterpartyName) == [
        "QR Payment Customer AG",
        "Bank Service Fees",
    ])
    #expect(payload.transactions.map(\.reference) == ["QR-2026-03", "FEE-2026-03"])
    #expect(payload.transactions.map(\.sourceLineRef) == ["camt:1", "camt:2"])
}

@Test
func camt053ImporterParsesMultiStatementCoverageAndBalances() throws {
    let importer = CAMTBankStatementImporter(format: .camt053)
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-camt053-multi-statement.xml")
    let payload = try importer.parse(
        fixtureURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "fixture"
    )

    #expect(try importer.canRecognize(fixtureURL))
    #expect(payload.statementImport.sourceFormat == "camt.053")
    #expect(payload.statementImport.coverageStart == isoDate("2026-05-01T00:00:00Z"))
    #expect(payload.statementImport.coverageEnd == isoDate("2026-05-31T23:59:59Z"))
    #expect(payload.statementImport.openingBalanceMinor == 100_000)
    #expect(payload.statementImport.closingBalanceMinor == 95_000)
    #expect(payload.parseLog.importedRowCount == 2)
    #expect(payload.parseLog.warnings.isEmpty)
    #expect(payload.transactions.map(\.amountMinor) == [10_000, -15_000])
    #expect(payload.transactions.map(\.reference) == ["STUDIO-2026-05", "INS-2026-05"])
    #expect(payload.transactions.map(\.sourceLineRef) == ["camt:1", "camt:2"])
}

@Test
func camt054ImporterParsesBatchAndMultiNotificationTransactions() throws {
    let importer = CAMTBankStatementImporter(format: .camt054)
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-camt054-batch-notification.xml")
    let payload = try importer.parse(
        fixtureURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "fixture"
    )

    #expect(try importer.canRecognize(fixtureURL))
    #expect(payload.statementImport.sourceFormat == "camt.054")
    #expect(payload.statementImport.coverageStart == isoDate("2026-06-01T00:00:00Z"))
    #expect(payload.statementImport.coverageEnd == isoDate("2026-06-30T23:59:59Z"))
    #expect(payload.statementImport.openingBalanceMinor == nil)
    #expect(payload.statementImport.closingBalanceMinor == nil)
    #expect(payload.parseLog.importedRowCount == 3)
    #expect(payload.parseLog.warnings.isEmpty)
    #expect(payload.transactions.map(\.amountMinor) == [45_000, 30_000, -8_000])
    #expect(payload.transactions.map(\.counterpartyName) == [
        "Marketplace Customer AG",
        "Subscription Customer AG",
        "Payment Terminal AG",
    ])
    #expect(payload.transactions.map(\.reference) == ["BATCH-450", "BATCH-300", "TERM-2026-06"])
    #expect(payload.transactions.map(\.sourceLineRef) == ["camt:1.1", "camt:1.2", "camt:2"])
}

@Test
func importJobServiceImportsCAMTFixtureThroughDefaultPipeline() throws {
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
    let storage = try workspaceService.createWorkspace(named: "CAMT Import Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let auditLogger = AuditLogger(storage: storage)
    let importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
    let transactionService = TransactionService(storage: storage)

    let parseLog = try importJobService.importStatement(
        from: try fixtureURL("Fixtures/Bank/sample-camt053-statement.xml"),
        accountId: account.id
    )

    let importJobs = try importJobService.listImportJobs()
    let statementImport = try #require(try storage.statementImportRepository.fetchStatementImports(accountId: account.id).first)
    let transactions = try transactionService.listTransactions(accountId: account.id)

    #expect(parseLog.parserKey == "camt.053.bankstatement")
    #expect(importJobs.count == 1)
    #expect(importJobs.first?.kind == .bankStatementCAMT)
    #expect(importJobs.first?.status == .completed)
    #expect(importJobs.first?.sourceBlobHash == statementImport.sourceBlobHash)
    #expect(importJobs.first?.sourceFingerprint == statementImport.sourceFingerprint)
    #expect(statementImport.sourceFormat == "camt.053")
    #expect(transactions.count == 3)
    #expect(transactions.allSatisfy { $0.statementImportId == statementImport.id })
}

@Test
func importJobServiceRejectsDuplicateRawSourceBeforeCreatingSecondStatementJob() throws {
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
    let storage = try workspaceService.createWorkspace(named: "CAMT Idempotency Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let auditLogger = AuditLogger(storage: storage)
    let importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
    let transactionService = TransactionService(storage: storage)
    let statementURL = try fixtureURL("Fixtures/Bank/sample-camt053-statement.xml")

    _ = try importJobService.importStatement(from: statementURL, accountId: account.id)

    do {
        _ = try importJobService.importStatement(from: statementURL, accountId: account.id)
        Issue.record("Expected duplicate source import rejection")
    } catch let error as DomainError {
        #expect(error == .duplicateStatementImport)
    }

    let importJobs = try importJobService.listImportJobs()
    let statementImport = try #require(try storage.statementImportRepository.fetchStatementImports(accountId: account.id).first)
    let transactions = try transactionService.listTransactions(accountId: account.id)

    #expect(importJobs.count == 1)
    #expect(importJobs.first?.status == .completed)
    #expect(importJobs.first?.sourceBlobHash == statementImport.sourceBlobHash)
    #expect(importJobs.first?.sourceFingerprint == statementImport.sourceFingerprint)
    #expect(transactions.count == 3)
}

@Test
func importJobServiceRejectsCorruptCAMTWithoutPersistingPartialRows() throws {
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
    let storage = try workspaceService.createWorkspace(named: "CAMT Corrupt File Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let importJobService = ImportJobService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let malformedCAMTURL = try writeTemporaryCAMT("""
    <?xml version="1.0" encoding="UTF-8"?>
    <Document xmlns="urn:iso:std:iso:20022:tech:xsd:camt.053.001.08">
      <BkToCstmrStmt>
        <Stmt>
          <Ntry><Amt Ccy="CHF">100.00</Amt>
        </Stmt>
      </BkToCstmrStmt>
    </Document>
    """)

    #expect(throws: DomainError.self) {
        _ = try importJobService.importStatement(from: malformedCAMTURL, accountId: account.id)
    }

    let importJob = try #require(try importJobService.listImportJobs().first)
    let diagnostics = try importJobService.listImportDiagnostics(importJobId: importJob.id)
    let statements = try storage.statementImportRepository.fetchStatementImports(accountId: account.id)
    let transactions = try storage.transactionRepository.fetchTransactions(accountId: account.id)

    #expect(importJob.kind == .bankStatementCAMT)
    #expect(importJob.status == .failed)
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.severity == .error)
    #expect(diagnostics.first?.code == "import.corrupt_file")
    #expect(diagnostics.first?.message.contains("CAMT.053 parse error") == true)
    #expect(statements.isEmpty)
    #expect(transactions.isEmpty)
}

@Test
func importJobServiceImportsCAMT052FixtureThroughDefaultPipeline() throws {
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
    let storage = try workspaceService.createWorkspace(named: "CAMT 052 Import Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let auditLogger = AuditLogger(storage: storage)
    let importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
    let transactionService = TransactionService(storage: storage)

    let parseLog = try importJobService.importStatement(
        from: try fixtureURL("Fixtures/Bank/sample-camt052-report.xml"),
        accountId: account.id
    )

    let importJobs = try importJobService.listImportJobs()
    let statementImport = try #require(try storage.statementImportRepository.fetchStatementImports(accountId: account.id).first)
    let transactions = try transactionService.listTransactions(accountId: account.id)

    #expect(parseLog.parserKey == "camt.052.bankstatement")
    #expect(importJobs.count == 1)
    #expect(importJobs.first?.kind == .bankStatementCAMT)
    #expect(importJobs.first?.status == .completed)
    #expect(statementImport.sourceFormat == "camt.052")
    #expect(transactions.count == 2)
    #expect(transactions.allSatisfy { $0.statementImportId == statementImport.id })
}

@Test
func importJobServiceImportsCAMT054FixtureThroughDefaultPipeline() throws {
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
    let storage = try workspaceService.createWorkspace(named: "CAMT 054 Import Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    let auditLogger = AuditLogger(storage: storage)
    let importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
    let transactionService = TransactionService(storage: storage)

    let parseLog = try importJobService.importStatement(
        from: try fixtureURL("Fixtures/Bank/sample-camt054-notification.xml"),
        accountId: account.id
    )

    let importJobs = try importJobService.listImportJobs()
    let statementImport = try #require(try storage.statementImportRepository.fetchStatementImports(accountId: account.id).first)
    let transactions = try transactionService.listTransactions(accountId: account.id)

    #expect(parseLog.parserKey == "camt.054.bankstatement")
    #expect(importJobs.count == 1)
    #expect(importJobs.first?.kind == .bankStatementCAMT)
    #expect(importJobs.first?.status == .completed)
    #expect(statementImport.sourceFormat == "camt.054")
    #expect(transactions.count == 2)
    #expect(transactions.allSatisfy { $0.statementImportId == statementImport.id })
}

private func fixtureURL(_ relativePath: String) throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return packageRoot.appendingPathComponent(relativePath)
}

private func writeTemporaryCAMT(_ content: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("xml")
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
}

private func isoDate(_ text: String) -> Date {
    ISO8601DateFormatter().date(from: text)!
}
