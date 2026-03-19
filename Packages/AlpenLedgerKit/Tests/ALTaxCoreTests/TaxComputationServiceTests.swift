import Foundation
import Testing
@testable import ALAudit
@testable import ALDocuments
@testable import ALImports
@testable import ALTaxCH
@testable import ALTaxCore
@testable import ALDomain
@testable import ALStorage
@testable import ALWorkspace

@Test
func zurichNaturalPersonFixtureImportProducesObservedFacts() throws {
    let harness = try TaxHarness()

    try harness.importTaxFixtures()
    let facts = try harness.taxComputationService.refreshFacts(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id
    )
    let expectedFacts = try loadExpectedTaxFacts()
    let factsByConcept = Dictionary(uniqueKeysWithValues: facts.map { ($0.conceptCode, $0) })

    #expect(facts.count == expectedFacts.count)
    #expect(facts.allSatisfy { $0.status == .observed })

    for expected in expectedFacts {
        let fact = try #require(factsByConcept[expected.conceptCode])
        #expect(fact.valueType.rawValue == expected.valueType)
        #expect(fact.moneyMinor == expected.moneyMinor)
        #expect(fact.boolValue == expected.boolValue)
        #expect(fact.currency == expected.currency)
    }
}

@Test
func zurichSoleProprietorFixtureImportProducesProfitAndLossFacts() throws {
    let harness = try TaxHarness()
    let soleProp = try harness.createSoleProprietor(named: "Studio Sole Prop")

    try harness.importFixtureStatement(accountId: soleProp.account.id)
    let facts = try harness.taxComputationService.refreshFacts(
        entityId: soleProp.entity.id,
        taxYearId: soleProp.taxYear.id
    )
    let factsByConcept = Dictionary(uniqueKeysWithValues: facts.map { ($0.conceptCode, $0) })

    #expect(factsByConcept["personal.self_employment.revenue_gross"]?.moneyMinor == 250000)
    #expect(factsByConcept["personal.self_employment.expense_total"]?.moneyMinor == 16250)
    #expect(factsByConcept["personal.self_employment.net_profit"]?.moneyMinor == 233750)
}

@Test
func recomputingUnchangedFactsDoesNotDuplicateCurrentRows() throws {
    let harness = try TaxHarness()

    try harness.importTaxFixtures()
    _ = try harness.taxComputationService.refreshFacts(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id
    )
    _ = try harness.taxComputationService.refreshFacts(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id
    )

    let currentFacts = try harness.taxFactService.listTaxFacts(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id
    )
    let allFacts = try harness.taxFactService.listTaxFacts(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id,
        currentOnly: false
    )

    #expect(currentFacts.count == 6)
    #expect(allFacts.count == 6)
}

@Test
func recomputingChangedFixtureSupersedesPriorCurrentFact() throws {
    let harness = try TaxHarness()

    try harness.importTaxFixtures()
    _ = try harness.taxComputationService.refreshFacts(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id
    )

    var salaryDocument = try #require(
        try harness.storage.documentRepository
            .fetchDocuments(workspaceId: harness.storage.manifest.workspace.id)
            .first(where: { $0.documentType == .salaryCertificate })
    )
    salaryDocument.extractedText = """
    document_type: salary certificate
    tax_year: 2026
    salary_gross_minor: 9950000
    currency: CHF
    """
    try harness.storage.documentRepository.saveDocument(salaryDocument)

    _ = try harness.taxComputationService.refreshFacts(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id
    )

    let fingerprint = TaxFactService.fingerprint(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "personal.income.salary_gross"
    )
    let currentFact = try #require(try harness.storage.taxFactRepository.fetchTaxFact(fingerprint: fingerprint, isCurrent: true))
    let allFacts = try harness.storage.taxFactRepository
        .fetchTaxFacts(entityId: harness.naturalPerson.id, taxYearId: harness.naturalPersonTaxYear.id, currentOnly: false)
        .filter { $0.fingerprint == fingerprint }

    #expect(currentFact.moneyMinor == 9950000)
    #expect(allFacts.count == 2)
    #expect(allFacts.filter { $0.isCurrent }.count == 1)
}

@Test
func readinessSummaryTracksNotStartedNeedsAttentionAndReadyForReview() throws {
    let harness = try TaxHarness()

    let notStarted = try harness.taxValidationService.readinessSummary(
        entity: harness.naturalPerson,
        taxYear: harness.naturalPersonTaxYear,
        currentFacts: []
    )
    #expect(notStarted.state == .notStarted)

    _ = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Tax/Zurich/2026/salary-certificate.txt"))
    let partialFacts = try harness.taxComputationService.refreshFacts(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id
    )
    let needsAttention = try harness.taxValidationService.readinessSummary(
        entity: harness.naturalPerson,
        taxYear: harness.naturalPersonTaxYear,
        currentFacts: partialFacts
    )
    #expect(needsAttention.state == .needsAttention)

    _ = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Tax/Zurich/2026/health-insurance-certificate.txt"))
    _ = try harness.documentService.importDocument(from: try fixtureURL("Fixtures/Tax/Zurich/2026/pillar3a-certificate.txt"))
    let readyFacts = try harness.taxComputationService.refreshFacts(
        entityId: harness.naturalPerson.id,
        taxYearId: harness.naturalPersonTaxYear.id
    )
    let ready = try harness.taxValidationService.readinessSummary(
        entity: harness.naturalPerson,
        taxYear: harness.naturalPersonTaxYear,
        currentFacts: readyFacts
    )

    #expect(ready.state == .readyForReview)
    #expect(ready.missingConceptCodes.isEmpty)
}

private struct TaxHarness {
    let fixedNow = try! #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let storage: WorkspaceStorage
    let naturalPerson: LegalEntity
    let naturalPersonTaxYear: TaxYear
    let documentService: DocumentService
    let importJobService: ImportJobService
    let legalEntityService: LegalEntityService
    let taxFactService: TaxFactService
    let taxComputationService: TaxComputationService
    let taxValidationService: TaxValidationService

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
        storage = try workspaceService.createWorkspace(named: "Tax Harness Workspace")

        let auditLogger = AuditLogger(storage: storage)
        documentService = DocumentService(storage: storage, auditLogger: auditLogger)
        importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
        legalEntityService = LegalEntityService(storage: storage, auditLogger: auditLogger, nowProvider: { fixedNow })

        let registry = RulePackRegistry()
        registry.registerPersonalTaxRulePack(ZurichPersonalTaxAdapter2026())
        taxFactService = TaxFactService(storage: storage)
        taxComputationService = TaxComputationService(
            storage: storage,
            rulePackRegistry: registry,
            factService: taxFactService,
            nowProvider: { fixedNow }
        )
        taxValidationService = TaxValidationService(storage: storage, rulePackRegistry: registry)

        naturalPerson = try #require(
            try storage.legalEntityRepository
                .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
                .first(where: { $0.kind == .naturalPerson })
        )
        naturalPersonTaxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: naturalPerson.id).first)
    }

    func importTaxFixtures() throws {
        _ = try documentService.importDocument(from: try fixtureURL("Fixtures/Tax/Zurich/2026/salary-certificate.txt"))
        _ = try documentService.importDocument(from: try fixtureURL("Fixtures/Tax/Zurich/2026/health-insurance-certificate.txt"))
        _ = try documentService.importDocument(from: try fixtureURL("Fixtures/Tax/Zurich/2026/pillar3a-certificate.txt"))
    }

    func createSoleProprietor(named name: String) throws -> SolePropHarness {
        let entity = try legalEntityService.createSoleProprietor(name: name)
        let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
        let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
        return SolePropHarness(entity: entity, account: account, taxYear: taxYear)
    }

    func importFixtureStatement(accountId: FinancialAccountID) throws {
        _ = try importJobService.importStatement(
            from: try fixtureURL("Fixtures/Bank/sample-bank-statement.csv"),
            accountId: accountId
        )
    }
}

private struct SolePropHarness {
    let entity: LegalEntity
    let account: FinancialAccount
    let taxYear: TaxYear
}

private struct ExpectedTaxFact: Decodable {
    let conceptCode: String
    let valueType: String
    let moneyMinor: Int64?
    let boolValue: Bool?
    let currency: String?
}

private func loadExpectedTaxFacts() throws -> [ExpectedTaxFact] {
    let data = try Data(contentsOf: try fixtureURL("Fixtures/Tax/Zurich/2026/expected-tax-facts.json"))
    return try JSONDecoder.alpenLedger.decode([ExpectedTaxFact].self, from: data)
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
