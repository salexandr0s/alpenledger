import Foundation
import Testing
@testable import ALDomain
@testable import ALTaxCH
@testable import ALTaxCore

@Test
func rulePackCatalogMatchesRegisteredZurichAdapter() throws {
    let catalog = try loadRulePackCatalog()
    let registry = registeredRulePackRegistry()
    let registeredPacks = registry.registeredPersonalTaxRulePacks()

    #expect(catalog.schemaVersion == 1)
    #expect(registeredPacks.count == catalog.rulePacks.count)

    for entry in catalog.rulePacks {
        let rulePack = try #require(registry.personalTaxRulePack(
            jurisdictionCode: entry.jurisdictionCode,
            rulesetVersion: entry.rulesetVersion
        ))
        #expect(String(describing: type(of: rulePack)) == entry.adapterType)

        let workspaceId = WorkspaceID()
        for rawKind in entry.appliesToEntityKinds {
            let kind = try #require(LegalEntityKind(rawValue: rawKind))
            let expectedConcepts = try #require(entry.expectedConceptCodesByEntityKind[rawKind])
            let entity = makeEntity(kind: kind, workspaceId: workspaceId)

            #expect(rulePack.expectedConceptCodes(for: entity) == Set(expectedConcepts))
        }
    }
}

@Test
func rulePackValidationAcceptsCatalogFixtureSamples() throws {
    let registry = registeredRulePackRegistry()
    let samples = try makeCatalogValidationSamples()

    let report = RulePackValidationService(registry: registry)
        .validateRegisteredPersonalRulePacks(samples: samples)

    #expect(report.checkedRulePackCount == 1)
    #expect(report.checkedSampleCount == 2)
    #expect(report.issues.isEmpty)
    #expect(report.isValid)
}

@Test
func rulePackValidationRejectsUndeclaredFactsAndInvalidValueShape() throws {
    let registry = RulePackRegistry()
    registry.registerPersonalTaxRulePack(BrokenRulePack())

    let sample = try naturalPersonValidationSample(
        rulesetVersion: "broken-v1",
        expectedComputedConceptCodes: ["personal.income.salary_gross"]
    )

    let report = RulePackValidationService(registry: registry)
        .validateRegisteredPersonalRulePacks(samples: [sample])
    let issueCodes = Set(report.issues.map(\.code))

    #expect(report.isValid == false)
    #expect(issueCodes.contains("rulepack.computed_concept.unexpected"))
    #expect(issueCodes.contains("rulepack.computed_concept.missing"))
    #expect(issueCodes.contains("rulepack.fact.field_missing"))
    #expect(issueCodes.contains("rulepack.fact.provenance_missing"))
    #expect(issueCodes.contains("rulepack.fact.confidence_invalid"))
}

private struct BrokenRulePack: PersonalTaxRulePack {
    let jurisdictionCode = "CH-ZH"
    let rulesetVersion = "broken-v1"

    func computeFacts(context: TaxComputationContext) throws -> [ComputedTaxFact] {
        [
            ComputedTaxFact(
                conceptCode: "personal.income.unlisted",
                valueType: .money,
                moneyMinor: 1,
                status: .observed,
                confidence: 1.5
            ),
        ]
    }

    func expectedConceptCodes(for entity: LegalEntity) -> Set<String> {
        ["personal.income.salary_gross"]
    }
}

private struct RulePackCatalog: Decodable {
    let schemaVersion: Int
    let rulePacks: [RulePackCatalogEntry]
}

private struct RulePackCatalogEntry: Decodable {
    let id: String
    let adapterType: String
    let jurisdictionCode: String
    let rulesetVersion: String
    let appliesToEntityKinds: [String]
    let expectedConceptCodesByEntityKind: [String: [String]]
}

private func loadRulePackCatalog() throws -> RulePackCatalog {
    let data = try Data(contentsOf: try fixtureURL("config/rule-pack-catalog.json"))
    return try JSONDecoder().decode(RulePackCatalog.self, from: data)
}

private func registeredRulePackRegistry() -> RulePackRegistry {
    let registry = RulePackRegistry()
    registry.registerPersonalTaxRulePack(ZurichPersonalTaxAdapter2026())
    return registry
}

private func makeCatalogValidationSamples() throws -> [PersonalRulePackValidationSample] {
    let catalog = try loadRulePackCatalog()
    let zurichEntry = try #require(catalog.rulePacks.first { $0.id == "ch-zh-personal-2026-v1" })
    let naturalExpectedConcepts = try loadExpectedTaxFactConceptCodes()
    let soleProprietorExpectedConcepts = Set(try #require(
        zurichEntry.expectedConceptCodesByEntityKind["soleProprietor"]
    ))

    return [
        try naturalPersonValidationSample(
            rulesetVersion: zurichEntry.rulesetVersion,
            expectedComputedConceptCodes: naturalExpectedConcepts
        ),
        try soleProprietorValidationSample(
            rulesetVersion: zurichEntry.rulesetVersion,
            expectedComputedConceptCodes: soleProprietorExpectedConcepts
        ),
    ]
}

private func naturalPersonValidationSample(
    rulesetVersion: String,
    expectedComputedConceptCodes: Set<String>
) throws -> PersonalRulePackValidationSample {
    let workspaceId = WorkspaceID()
    let entity = makeEntity(kind: .naturalPerson, workspaceId: workspaceId)
    let taxYear = try makeTaxYear(entityId: entity.id, rulesetVersion: rulesetVersion)
    let documents = try [
        taxDocument(
            path: "Fixtures/Tax/Zurich/2026/salary-certificate.txt",
            type: .salaryCertificate,
            workspaceId: workspaceId,
            entity: entity,
            taxYear: taxYear
        ),
        taxDocument(
            path: "Fixtures/Tax/Zurich/2026/health-insurance-certificate.txt",
            type: .healthInsuranceCertificate,
            workspaceId: workspaceId,
            entity: entity,
            taxYear: taxYear
        ),
        taxDocument(
            path: "Fixtures/Tax/Zurich/2026/pillar3a-certificate.txt",
            type: .pillar3aCertificate,
            workspaceId: workspaceId,
            entity: entity,
            taxYear: taxYear
        ),
    ]

    return PersonalRulePackValidationSample(
        label: "zh-personal-2026-natural-person-golden",
        context: TaxComputationContext(
            entity: entity,
            taxYear: taxYear,
            documents: documents,
            financialAccounts: [],
            transactions: []
        ),
        expectedComputedConceptCodes: expectedComputedConceptCodes
    )
}

private func soleProprietorValidationSample(
    rulesetVersion: String,
    expectedComputedConceptCodes: Set<String>
) throws -> PersonalRulePackValidationSample {
    let workspaceId = WorkspaceID()
    let entity = makeEntity(kind: .soleProprietor, workspaceId: workspaceId)
    let taxYear = try makeTaxYear(entityId: entity.id, rulesetVersion: rulesetVersion)
    let account = FinancialAccount(
        entityId: entity.id,
        accountType: .bank,
        institutionName: "Synthetic Bank",
        displayName: "Business account",
        ledgerControlAccountId: LedgerAccountID(),
        openedAt: try date("2026-01-01T00:00:00Z")
    )
    let transactions = [
        Transaction(
            accountId: account.id,
            sourceLineRef: "rule-pack-validation:1",
            bookingDate: try date("2026-03-01T00:00:00Z"),
            amountMinor: 250_000,
            currency: .chf,
            counterpartyName: "Synthetic Client",
            memo: "Synthetic consulting revenue",
            reviewState: .reviewed
        ),
        Transaction(
            accountId: account.id,
            sourceLineRef: "rule-pack-validation:2",
            bookingDate: try date("2026-03-02T00:00:00Z"),
            amountMinor: -16_250,
            currency: .chf,
            counterpartyName: "Synthetic Supplier",
            memo: "Synthetic operating expense",
            reviewState: .reviewed
        ),
    ]

    return PersonalRulePackValidationSample(
        label: "zh-personal-2026-sole-proprietor-profit-loss",
        context: TaxComputationContext(
            entity: entity,
            taxYear: taxYear,
            documents: [],
            financialAccounts: [account],
            transactions: transactions
        ),
        expectedComputedConceptCodes: expectedComputedConceptCodes
    )
}

private func makeEntity(kind: LegalEntityKind, workspaceId: WorkspaceID) -> LegalEntity {
    LegalEntity(
        workspaceId: workspaceId,
        kind: kind,
        legalName: "Synthetic \(kind.rawValue)",
        displayName: "Synthetic \(kind.rawValue)",
        canton: .zh
    )
}

private func makeTaxYear(entityId: LegalEntityID, rulesetVersion: String) throws -> TaxYear {
    TaxYear(
        entityId: entityId,
        year: 2026,
        periodStart: try date("2026-01-01T00:00:00Z"),
        periodEnd: try date("2026-12-31T23:59:59Z"),
        canton: .zh,
        rulesetVersion: rulesetVersion
    )
}

private func taxDocument(
    path: String,
    type: DocumentType,
    workspaceId: WorkspaceID,
    entity: LegalEntity,
    taxYear: TaxYear
) throws -> Document {
    let url = try fixtureURL(path)
    return Document(
        workspaceId: workspaceId,
        blobHash: "fixture-\(url.lastPathComponent)",
        originalFilename: url.lastPathComponent,
        mediaType: "text/plain",
        documentType: type,
        issueDate: try date("2026-02-01T00:00:00Z"),
        detectedEntityId: entity.id,
        entityId: entity.id,
        detectedTaxYearId: taxYear.id,
        extractedText: try String(contentsOf: url, encoding: .utf8),
        metadataStatus: .confirmed
    )
}

private struct ExpectedTaxFactConcept: Decodable {
    let conceptCode: String
}

private func loadExpectedTaxFactConceptCodes() throws -> Set<String> {
    let data = try Data(contentsOf: try fixtureURL("Fixtures/Tax/Zurich/2026/expected-tax-facts.json"))
    let facts = try JSONDecoder().decode([ExpectedTaxFactConcept].self, from: data)
    return Set(facts.map(\.conceptCode))
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
