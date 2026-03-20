import Foundation
import Testing
@testable import ALDomain
@testable import ALTaxCore
@testable import ALWorkspace
@testable import ALStorage

@Test
func workspaceServiceCreatesEncryptedWorkspaceInTempDirectory() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)

    let storage = try workspaceService.createWorkspace(named: "Spec Workspace")

    #expect(FileManager.default.fileExists(atPath: storage.paths.databaseURL.path))
    #expect(FileManager.default.fileExists(atPath: storage.paths.manifestURL.path))
    #expect(try storage.workspaceRepository.fetchWorkspace()?.name == "Spec Workspace")
    #expect((try storage.auditEventRepository.fetchAuditEvents(workspaceId: storage.manifest.workspace.id, objectRef: nil)).isEmpty == false)
}

@Test
func evidenceTablesRoundTrip() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Round Trip Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)

    let requirement = Requirement(
        fingerprint: "requirement-roundtrip",
        entityId: entity.id,
        taxYearId: taxYear.id,
        requirementCode: .statementCoverage,
        subjectRef: ObjectRef(kind: .financialAccount, id: UUID()),
        summary: "Requirement round trip",
        status: .pending
    )
    try storage.requirementRepository.saveRequirement(requirement)

    let issue = Issue(
        fingerprint: "issue-roundtrip",
        workspaceId: storage.manifest.workspace.id,
        entityId: entity.id,
        taxYearId: taxYear.id,
        issueCode: .missingStatementCoverage,
        severity: .blocking,
        status: .open,
        summary: "Issue round trip",
        objectRef: ObjectRef(kind: .requirement, id: requirement.id.rawValue)
    )
    try storage.issueRepository.saveIssue(issue)

    let proposal = AgentProposal(
        fingerprint: "proposal-roundtrip",
        workspaceId: storage.manifest.workspace.id,
        agentKind: .systemHeuristics,
        proposalType: .documentLinkReview,
        targetRef: ObjectRef(kind: .document, id: UUID()),
        summary: "Proposal round trip",
        rationale: "Round trip",
        confidence: 0.25
    )
    try storage.agentProposalRepository.saveAgentProposal(proposal)

    #expect(try storage.requirementRepository.fetchRequirement(fingerprint: "requirement-roundtrip")?.summary == "Requirement round trip")
    #expect(try storage.issueRepository.fetchIssue(fingerprint: "issue-roundtrip")?.summary == "Issue round trip")
    #expect(try storage.agentProposalRepository.fetchAgentProposal(fingerprint: "proposal-roundtrip")?.summary == "Proposal round trip")
}

@Test
func taxFactsRoundTripProvenanceAsJSON() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Tax Storage Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)

    let fact = TaxFact(
        fingerprint: "zh|salary",
        entityId: entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "personal.income.salary_gross",
        valueType: .money,
        moneyMinor: 9800000,
        currency: .chf,
        status: .observed,
        rulesetVersion: "zh-personal-2026-v1",
        provenanceRefs: [
            ObjectRef(kind: .document, id: UUID()),
            ObjectRef(kind: .transaction, id: UUID()),
        ]
    )
    try storage.taxFactRepository.saveTaxFact(fact)

    let loaded = try #require(try storage.taxFactRepository.fetchTaxFact(fingerprint: "zh|salary", isCurrent: true))
    #expect(loaded.moneyMinor == 9800000)
    #expect(loaded.provenanceRefs == fact.provenanceRefs)
}

@Test
func taxFactRepositoryPreservesSingleCurrentVersionAfterSupersession() throws {
    let fixedNow = try #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        nowProvider: { fixedNow }
    )
    let storage = try workspaceService.createWorkspace(named: "Tax History Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
    let factService = TaxFactService(storage: storage)

    _ = try factService.syncFacts(
        [
            ComputedTaxFact(
                conceptCode: "personal.income.salary_gross",
                valueType: .money,
                moneyMinor: 9800000,
                currency: .chf,
                status: .observed,
                provenanceRefs: [ObjectRef(kind: .document, id: UUID())]
            )
        ],
        entityId: entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        rulesetVersion: "zh-personal-2026-v1",
        now: fixedNow
    )

    _ = try factService.syncFacts(
        [
            ComputedTaxFact(
                conceptCode: "personal.income.salary_gross",
                valueType: .money,
                moneyMinor: 9900000,
                currency: .chf,
                status: .observed,
                provenanceRefs: [ObjectRef(kind: .document, id: UUID())]
            )
        ],
        entityId: entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        rulesetVersion: "zh-personal-2026-v1",
        now: fixedNow.addingTimeInterval(60)
    )

    let currentFacts = try storage.taxFactRepository.fetchTaxFacts(entityId: entity.id, taxYearId: taxYear.id, currentOnly: true)
    let allFacts = try storage.taxFactRepository.fetchTaxFacts(entityId: entity.id, taxYearId: taxYear.id, currentOnly: false)

    #expect(currentFacts.count == 1)
    #expect(currentFacts.first?.moneyMinor == 9900000)
    #expect(allFacts.count == 2)
    #expect(allFacts.filter { $0.isCurrent }.count == 1)
    #expect(allFacts.first(where: { $0.isCurrent })?.supersedesFactId != nil)
}
