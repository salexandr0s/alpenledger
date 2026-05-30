import Foundation
import Testing
@testable import ALAudit
@testable import ALDomain
@testable import ALImports
@testable import ALStorage
@testable import ALTaxCH
@testable import ALTaxCore
@testable import ALWorkspace

@Test
func vatPeriodServiceReconcilesPersistedPeriodFromEntityLedger() throws {
    let harness = try VATPeriodHarness()
    let period = try harness.vatPeriodService.createVATPeriod(
        entityId: harness.entity.id,
        periodStart: date("2026-04-01T00:00:00Z"),
        periodEnd: date("2026-06-30T23:59:59Z")
    )
    try harness.saveTransactions([
        harness.transaction(
            sourceLineRef: "vat-output",
            bookingDate: date("2026-04-12T00:00:00Z"),
            amountMinor: 10_810,
            memo: "Standard-rate sale",
            taxCode: "CH-VAT-OUTPUT-STD"
        ),
        harness.transaction(
            sourceLineRef: "vat-input",
            bookingDate: date("2026-05-03T00:00:00Z"),
            amountMinor: -5_405,
            memo: "Standard-rate supplier invoice",
            taxCode: "CH-VAT-INPUT-STD"
        ),
        harness.transaction(
            sourceLineRef: "outside-period",
            bookingDate: date("2026-07-01T00:00:00Z"),
            amountMinor: 10_810,
            memo: "Outside period",
            taxCode: "CH-VAT-OUTPUT-STD"
        ),
    ])

    let report = try harness.vatPeriodService.reconcileVATPeriod(period.id)

    #expect(report.lines.count == 2)
    #expect(report.outputTaxMinor == 810)
    #expect(report.inputTaxMinor == 405)
    #expect(report.netTaxPayableMinor == 405)
    #expect(report.blockerCount == 0)
}

@Test
func vatPeriodLockAuditsStatusTransitions() throws {
    let harness = try VATPeriodHarness()
    let period = try harness.vatPeriodService.createVATPeriod(
        entityId: harness.entity.id,
        periodStart: date("2026-04-01T00:00:00Z"),
        periodEnd: date("2026-06-30T23:59:59Z")
    )
    try harness.saveTransactions([
        harness.transaction(
            sourceLineRef: "vat-output",
            bookingDate: date("2026-04-12T00:00:00Z"),
            amountMinor: 10_810,
            memo: "Standard-rate sale",
            taxCode: "CH-VAT-OUTPUT-STD"
        ),
    ])

    let locked = try harness.vatPeriodService.lockVATPeriod(period.id)
    let unlocked = try harness.vatPeriodService.unlockVATPeriod(period.id)
    let persisted = try #require(try harness.storage.vatPeriodRepository.fetchVATPeriod(id: period.id))
    let events = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .vatPeriod, id: period.id.rawValue)
    )

    #expect(locked.status == .locked)
    #expect(unlocked.status == .open)
    #expect(persisted.status == .open)
    #expect(events.contains { $0.eventType == .vatPeriodCreated })
    #expect(events.contains { $0.eventType == .vatPeriodLocked && $0.payload == "open->locked" })
    #expect(events.contains { $0.eventType == .vatPeriodUnlocked && $0.payload == "locked->open" })
}

@Test
func vatPeriodLockRejectsBlockingReconciliationIssues() throws {
    let harness = try VATPeriodHarness()
    let period = try harness.vatPeriodService.createVATPeriod(
        entityId: harness.entity.id,
        periodStart: date("2026-04-01T00:00:00Z"),
        periodEnd: date("2026-06-30T23:59:59Z")
    )
    try harness.saveTransactions([
        harness.transaction(
            sourceLineRef: "missing-vat",
            bookingDate: date("2026-04-12T00:00:00Z"),
            amountMinor: 10_810,
            memo: "Sale without VAT mapping",
            taxCode: nil
        ),
    ])

    do {
        _ = try harness.vatPeriodService.lockVATPeriod(period.id)
        Issue.record("Expected VAT period lock to reject blocker issues.")
    } catch let error as DomainError {
        #expect(error == .vatPeriodHasBlockers(1))
    }

    let persisted = try #require(try harness.storage.vatPeriodRepository.fetchVATPeriod(id: period.id))
    #expect(persisted.status == .open)
}

@Test
func lockedVATPeriodRejectsStatementImportsThatWouldChangeThePeriod() throws {
    let harness = try VATPeriodHarness()
    let period = try harness.vatPeriodService.createVATPeriod(
        entityId: harness.entity.id,
        periodStart: date("2026-01-01T00:00:00Z"),
        periodEnd: date("2026-03-31T23:59:59Z")
    )
    _ = try harness.vatPeriodService.lockVATPeriod(period.id)

    do {
        _ = try harness.importJobService.importStatement(
            from: try fixtureURL("Fixtures/Bank/sample-bank-statement.csv"),
            accountId: harness.account.id
        )
        Issue.record("Expected locked VAT period to reject statement import.")
    } catch let error as DomainError {
        #expect(error == .lockedPeriod)
    }

    let transactions = try harness.storage.transactionRepository.fetchTransactions(accountId: harness.account.id)
    #expect(transactions.isEmpty)
}

@Test
func vatPeriodServiceRejectsOverlappingPeriods() throws {
    let harness = try VATPeriodHarness()
    _ = try harness.vatPeriodService.createVATPeriod(
        entityId: harness.entity.id,
        periodStart: date("2026-01-01T00:00:00Z"),
        periodEnd: date("2026-03-31T23:59:59Z")
    )

    do {
        _ = try harness.vatPeriodService.createVATPeriod(
            entityId: harness.entity.id,
            periodStart: date("2026-03-15T00:00:00Z"),
            periodEnd: date("2026-06-30T23:59:59Z")
        )
        Issue.record("Expected overlapping VAT period to be rejected.")
    } catch let error as DomainError {
        guard case .invalidVATPeriod = error else {
            Issue.record("Expected invalid VAT period, got \(error).")
            return
        }
    }
}

private struct VATPeriodHarness {
    let fixedNow = try! #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let storage: WorkspaceStorage
    let entity: LegalEntity
    let account: FinancialAccount
    let vatPeriodService: VATPeriodService
    let importJobService: ImportJobService

    init() throws {
        let fixedNow = self.fixedNow
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storageManager = WorkspaceStorageManager(
            secretStore: InMemorySecretStore(),
            workspacesRootURL: tempRoot
        )
        let recentStore = RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let workspaceService = WorkspaceService(
            storageManager: storageManager,
            recentStore: recentStore,
            nowProvider: { fixedNow }
        )
        storage = try workspaceService.createWorkspace(named: "VAT Period Harness Workspace")

        let auditLogger = AuditLogger(storage: storage)
        let legalEntityService = LegalEntityService(storage: storage, auditLogger: auditLogger, nowProvider: { fixedNow })
        entity = try legalEntityService.createSoleProprietor(name: "VAT Harness Business")
        account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
        vatPeriodService = VATPeriodService(
            storage: storage,
            codeBook: SwissVATCodeBook.current2026(),
            auditLogger: auditLogger
        )
        importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
    }

    func transaction(
        sourceLineRef: String,
        bookingDate: Date,
        amountMinor: Int64,
        memo: String,
        taxCode: String?
    ) -> Transaction {
        Transaction(
            accountId: account.id,
            originKind: .manual,
            sourceLineRef: sourceLineRef,
            bookingDate: bookingDate,
            amountMinor: amountMinor,
            currency: .chf,
            counterpartyName: "VAT Counterparty",
            memo: memo,
            taxCode: taxCode
        )
    }

    func saveTransactions(_ transactions: [Transaction]) throws {
        try storage.transactionRepository.saveTransactions(transactions)
    }
}

private func date(_ rawValue: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: rawValue))
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
