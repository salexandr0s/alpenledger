import Foundation
import Testing
@testable import ALAudit
@testable import ALDomain
@testable import ALImports
@testable import ALStorage
@testable import ALWorkspace

@Test
func legalEntityDeleteRemovesEmptySoleProprietor() throws {
    let harness = try LegalEntityHarness()
    let entity = try harness.legalEntityService.createSoleProprietor(name: "Side Gig")

    let deletionCheck = try harness.legalEntityService.deleteEntity(entity.id)
    #expect(deletionCheck.canDelete)

    let entities = try harness.legalEntityService.listEntities()
    #expect(entities.contains(where: { $0.id == entity.id }) == false)

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: nil
    )
    #expect(auditEvents.contains(where: { $0.eventType == .legalEntityRemoved }))
}

@Test
func legalEntityDeleteReturnsBlockingDependenciesWhenTransactionsExist() throws {
    let harness = try LegalEntityHarness()
    let entity = try harness.legalEntityService.createSoleProprietor(name: "Busy Side Gig")
    let account = try #require(try harness.storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)

    _ = try harness.importJobService.importStatement(
        from: try fixtureURL("Fixtures/Bank/sample-bank-statement.csv"),
        accountId: account.id
    )

    let deletionCheck = try harness.legalEntityService.deleteEntity(entity.id)
    #expect(deletionCheck.canDelete == false)
    #expect(deletionCheck.statementImportCount == 1)
    #expect(deletionCheck.transactionCount > 0)

    let entities = try harness.legalEntityService.listEntities()
    #expect(entities.contains(where: { $0.id == entity.id }))
}

private struct LegalEntityHarness {
    let fixedNow = try! #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let storage: WorkspaceStorage
    let legalEntityService: LegalEntityService
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
        storage = try workspaceService.createWorkspace(named: "Legal Entity Harness")

        let auditLogger = AuditLogger(storage: storage)
        legalEntityService = LegalEntityService(storage: storage, auditLogger: auditLogger, nowProvider: { fixedNow })
        importJobService = ImportJobService(storage: storage, auditLogger: auditLogger)
    }
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
