import Foundation
import Testing
@testable import ALAudit
@testable import ALDomain
@testable import ALStorage
@testable import ALWorkspace

@Test
func taxYearServiceLocksAndUnlocksTaxYearWithAuditTrail() throws {
    let harness = try TaxYearHarness()
    let taxYear = try #require(try harness.taxYearService.listTaxYears(entityId: harness.entity.id).first)

    let locked = try harness.taxYearService.lockTaxYear(entityId: harness.entity.id, taxYearId: taxYear.id)
    #expect(locked.status == .locked)

    let unlocked = try harness.taxYearService.unlockTaxYear(entityId: harness.entity.id, taxYearId: taxYear.id)
    #expect(unlocked.status == .open)

    let persisted = try #require(try harness.taxYearService.listTaxYears(entityId: harness.entity.id).first)
    #expect(persisted.status == .open)

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .taxYear, id: taxYear.id.rawValue)
    )
    #expect(auditEvents.contains { $0.eventType == .taxYearLocked && $0.payload == "open->locked" })
    #expect(auditEvents.contains { $0.eventType == .taxYearUnlocked && $0.payload == "locked->open" })
}

@Test
func taxYearServiceDoesNotReopenFiledTaxYear() throws {
    let harness = try TaxYearHarness()
    var taxYear = try #require(try harness.taxYearService.listTaxYears(entityId: harness.entity.id).first)
    taxYear.status = .filed
    try harness.storage.taxYearRepository.saveTaxYear(taxYear)

    do {
        _ = try harness.taxYearService.unlockTaxYear(entityId: harness.entity.id, taxYearId: taxYear.id)
        Issue.record("Expected filed tax year reopen to be rejected.")
    } catch let error as DomainError {
        #expect(error == .invalidTaxYearStatusTransition)
    }

    let persisted = try #require(try harness.taxYearService.listTaxYears(entityId: harness.entity.id).first)
    #expect(persisted.status == .filed)
}

private struct TaxYearHarness {
    let fixedNow = try! #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let storage: WorkspaceStorage
    let entity: LegalEntity
    let taxYearService: TaxYearService

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
        storage = try workspaceService.createWorkspace(named: "Tax Year Harness")
        entity = try #require(try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first)

        let auditLogger = AuditLogger(storage: storage)
        taxYearService = TaxYearService(storage: storage, auditLogger: auditLogger)
    }
}
