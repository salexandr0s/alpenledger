import Foundation
import Testing
@testable import ALAudit
@testable import ALDocuments
@testable import ALEvidence
@testable import ALDomain
@testable import ALImports
@testable import ALStorage
@testable import ALTaxCH
@testable import ALTaxCore
@testable import ALWorkspace

@Test
func realisticEndToEndScenarioCoversPersonalBusinessEvidenceVATAndRecovery() throws {
    let fixedNow = try scenarioDate("2026-07-15T12:00:00Z")
    let fileManager = FileManager.default
    let scenarioRoot = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let secretStore = InMemorySecretStore()
    let workspaceService = WorkspaceService(
        storageManager: WorkspaceStorageManager(
            secretStore: secretStore,
            workspacesRootURL: scenarioRoot.appendingPathComponent("workspaces", isDirectory: true)
        ),
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { fixedNow }
    )
    let storage = try workspaceService.createWorkspace(named: "Zurich Household + Studio Scenario")
    let auditLogger = AuditLogger(storage: storage)
    let documentService = DocumentService(storage: storage, auditLogger: auditLogger)
    let importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
    let legalEntityService = LegalEntityService(
        storage: storage,
        auditLogger: auditLogger,
        nowProvider: { fixedNow }
    )
    let rulePackRegistry = RulePackRegistry()
    rulePackRegistry.registerPersonalTaxRulePack(ZurichPersonalTaxAdapter2026())
    let taxFactService = TaxFactService(storage: storage)
    let taxComputationService = TaxComputationService(
        storage: storage,
        rulePackRegistry: rulePackRegistry,
        factService: taxFactService,
        nowProvider: { fixedNow }
    )
    let taxValidationService = TaxValidationService(
        storage: storage,
        rulePackRegistry: rulePackRegistry
    )
    let evidenceRefreshService = EvidenceRefreshService(
        storage: storage,
        auditLogger: auditLogger,
        nowProvider: { fixedNow }
    )
    let vatPeriodService = VATPeriodService(
        storage: storage,
        codeBook: SwissVATCodeBook.current2026(),
        auditLogger: auditLogger
    )

    let personalEntity = try #require(
        try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first(where: { $0.kind == .naturalPerson })
    )
    let personalTaxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: personalEntity.id).first)

    for fixturePath in [
        "Fixtures/Tax/Zurich/2026/salary-certificate.txt",
        "Fixtures/Tax/Zurich/2026/health-insurance-certificate.txt",
        "Fixtures/Tax/Zurich/2026/pillar3a-certificate.txt",
    ] {
        _ = try documentService.importDocument(from: try scenarioFixtureURL(fixturePath))
    }

    let personalFacts = try taxComputationService.refreshFacts(
        entityId: personalEntity.id,
        taxYearId: personalTaxYear.id
    )
    let personalReadiness = try taxValidationService.readinessSummary(
        entityId: personalEntity.id,
        taxYearId: personalTaxYear.id
    )

    #expect(personalFacts.count == 6)
    #expect(personalFacts.allSatisfy { $0.status == .observed })
    #expect(personalReadiness.state == .readyForReview)

    let businessEntity = try legalEntityService.createSoleProprietor(name: "Scenario Studio")
    let businessTaxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: businessEntity.id).first)
    let businessAccount = try #require(
        try storage.financialAccountRepository.fetchFinancialAccounts(entityId: businessEntity.id).first
    )

    _ = try importJobService.importStatement(
        from: try scenarioFixtureURL("Fixtures/Bank/sample-bank-statement.csv"),
        accountId: businessAccount.id
    )
    let importedBusinessTransactions = try storage.transactionRepository.fetchTransactions(accountId: businessAccount.id)
    let importDiagnostics = try storage.importDiagnosticRepository
        .fetchImportDiagnostics(workspaceId: storage.manifest.workspace.id)

    #expect(importedBusinessTransactions.count == 3)
    #expect(importDiagnostics.isEmpty)

    let businessFacts = try taxComputationService.refreshFacts(
        entityId: businessEntity.id,
        taxYearId: businessTaxYear.id
    )
    let businessFactsByConcept = Dictionary(uniqueKeysWithValues: businessFacts.map { ($0.conceptCode, $0) })

    #expect(businessFactsByConcept["personal.self_employment.revenue_gross"]?.moneyMinor == 250_000)
    #expect(businessFactsByConcept["personal.self_employment.expense_total"]?.moneyMinor == 16_250)
    #expect(businessFactsByConcept["personal.self_employment.net_profit"]?.moneyMinor == 233_750)

    try evidenceRefreshService.refresh()
    let openBusinessIssues = try evidenceRefreshService.listIssues(status: .open)
        .filter { $0.entityId == businessEntity.id }
    let pendingBusinessRequirements = try storage.requirementRepository
        .fetchRequirements(entityId: businessEntity.id, taxYearId: businessTaxYear.id)
        .filter { $0.status == .pending }

    #expect(openBusinessIssues.contains { $0.issueCode == .missingExpenseEvidence })
    #expect(openBusinessIssues.contains { $0.issueCode == .missingStatementCoverage })
    #expect(pendingBusinessRequirements.contains { $0.requirementCode == .expenseEvidence })
    #expect(pendingBusinessRequirements.contains { $0.requirementCode == .statementCoverage })

    let vatFixture = try loadScenarioVATFixture()
    let vatTransactions = vatFixture.transactions.map { $0.transaction(accountId: businessAccount.id) }
    try storage.transactionRepository.saveTransactions(vatTransactions)
    let vatPeriod = try vatPeriodService.createVATPeriod(
        entityId: businessEntity.id,
        periodStart: vatFixture.period.startDate,
        periodEnd: vatFixture.period.endDate,
        currency: vatFixture.period.currency
    )
    let vatReport = try vatPeriodService.reconcileVATPeriod(vatPeriod.id)
    let lockedVATPeriod = try vatPeriodService.lockVATPeriod(vatPeriod.id)

    #expect(vatReport.lines.count == vatFixture.expected.lineCount)
    #expect(vatReport.outputTaxMinor == vatFixture.expected.outputTaxMinor)
    #expect(vatReport.inputTaxMinor == vatFixture.expected.inputTaxMinor)
    #expect(vatReport.netTaxPayableMinor == vatFixture.expected.netTaxPayableMinor)
    #expect(vatReport.issues.count == vatFixture.expected.issueCount)
    #expect(lockedVATPeriod.status == .locked)

    let supportBundleURL = scenarioRoot
        .appendingPathComponent("exports", isDirectory: true)
        .appendingPathComponent("scenario-support.json")
    let supportBundle = try storage.exportSupportBundle(
        to: supportBundleURL,
        generatedAt: fixedNow
    )
    let backupURL = scenarioRoot
        .appendingPathComponent("backups", isDirectory: true)
        .appendingPathComponent("scenario.alpenledgerbackup", isDirectory: true)
    _ = try workspaceService.createBackup(for: storage, at: backupURL)
    let backupIntegrity = try workspaceService.validateBackup(at: backupURL)

    #expect(supportBundle.diagnostics.databaseHealth.isHealthy)
    #expect(supportBundle.auditLog.totalEventCount > 0)
    #expect(supportBundle.privacy.includesWorkspaceName == false)
    #expect(fileManager.fileExists(atPath: supportBundleURL.path))
    #expect(backupIntegrity.isRestorable)
    #expect(backupIntegrity.issues.isEmpty)
}

private struct ScenarioVATFixture: Decodable {
    let period: ScenarioVATFixturePeriod
    let transactions: [ScenarioVATFixtureTransaction]
    let expected: ScenarioVATFixtureExpected
}

private struct ScenarioVATFixturePeriod: Decodable {
    let start: String
    let end: String
    let currency: CurrencyCode

    var startDate: Date { ISO8601DateFormatter().date(from: start)! }
    var endDate: Date { ISO8601DateFormatter().date(from: end)! }
}

private struct ScenarioVATFixtureTransaction: Decodable {
    let id: UUID
    let bookingDate: String
    let amountMinor: Int64
    let currency: CurrencyCode
    let counterpartyName: String
    let memo: String
    let taxCode: String?

    func transaction(accountId: FinancialAccountID) -> Transaction {
        Transaction(
            id: TransactionID(rawValue: id),
            accountId: accountId,
            sourceLineRef: "scenario-vat:\(id.uuidString.lowercased())",
            bookingDate: ISO8601DateFormatter().date(from: bookingDate)!,
            amountMinor: amountMinor,
            currency: currency,
            counterpartyName: counterpartyName,
            memo: memo,
            taxCode: taxCode,
            reviewState: .reviewed
        )
    }
}

private struct ScenarioVATFixtureExpected: Decodable {
    let lineCount: Int
    let outputTaxMinor: Int64
    let inputTaxMinor: Int64
    let netTaxPayableMinor: Int64
    let issueCount: Int
}

private func loadScenarioVATFixture() throws -> ScenarioVATFixture {
    let data = try Data(contentsOf: try scenarioFixtureURL("Fixtures/VAT/simple-quarter-2026.json"))
    return try JSONDecoder.alpenLedger.decode(ScenarioVATFixture.self, from: data)
}

private func scenarioDate(_ rawValue: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: rawValue))
}

private func scenarioFixtureURL(_ relativePath: String) throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return packageRoot.appendingPathComponent(relativePath)
}
