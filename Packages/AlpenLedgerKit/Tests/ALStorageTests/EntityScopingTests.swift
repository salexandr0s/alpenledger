import Foundation
import Testing
@testable import ALDomain
@testable import ALAudit
@testable import ALWorkspace
@testable import ALStorage

@Test
func migrationV5BackfillsEntityIdAndCreatesEntityWorkspaces() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Migration V5 Workspace")
    let workspaceId = storage.manifest.workspace.id
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: workspaceId).first)

    // Insert a document with detectedEntityId — migration v5 should have backfilled entityId
    let doc = Document(
        workspaceId: workspaceId,
        blobHash: "backfill-test-\(UUID().uuidString)",
        originalFilename: "test.pdf",
        mediaType: "application/pdf",
        detectedEntityId: entity.id,
        entityId: entity.id
    )
    try storage.documentRepository.saveDocument(doc)

    let loaded = try #require(try storage.documentRepository.fetchDocument(id: doc.id))
    #expect(loaded.entityId == entity.id)

    // Migration v5 auto-creates entityWorkspaces for existing legalEntities
    let entityWorkspaces = try storage.entityWorkspaceRepository.fetchEntityWorkspaces(workspaceId: workspaceId)
    #expect(entityWorkspaces.isEmpty == false)
    #expect(entityWorkspaces.contains(where: { $0.entityId == entity.id }))

    // New tables accept inserts
    let taxProfile = TaxProfile(
        entityId: entity.id,
        taxationType: .personal,
        canton: .zh,
        maritalStatus: .single,
        numberOfDependents: 0
    )
    try storage.taxProfileRepository.saveTaxProfile(taxProfile)
    #expect(try storage.taxProfileRepository.fetchTaxProfile(entityId: entity.id)?.canton == .zh)

    let category = TransactionCategory(
        entityId: entity.id,
        code: "expense.office",
        displayName: "Office Supplies",
        isSystemDefined: true
    )
    try storage.categoryRepository.saveTransactionCategory(category)
    #expect(try storage.categoryRepository.fetchCategories(entityId: entity.id).count == 1)

    let invoice = InvoiceRecord(
        documentId: doc.id,
        entityId: entity.id,
        counterpartyName: "Test Supplier",
        totalAmountMinor: 50000,
        currency: .chf,
        direction: .payable
    )
    try storage.invoiceRecordRepository.saveInvoiceRecord(invoice)
    #expect(try storage.invoiceRecordRepository.fetchInvoiceRecords(entityId: entity.id).count == 1)

    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
    let filingPackage = FilingPackage(
        entityId: entity.id,
        taxYearId: taxYear.id,
        exportFormat: "eCH-0119"
    )
    try storage.filingPackageRepository.saveFilingPackage(filingPackage)
    #expect(try storage.filingPackageRepository.fetchFilingPackages(entityId: entity.id).count == 1)
}

@Test
func entityScopedDocumentFetchReturnsOnlyMatchingEntity() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Scoped Fetch Workspace")
    let workspaceId = storage.manifest.workspace.id
    let entity1 = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: workspaceId).first)

    // Create a second entity via LegalEntityService
    let auditLogger = AuditLogger(storage: storage)
    let entityService = LegalEntityService(storage: storage, auditLogger: auditLogger)
    let entity2 = try entityService.createSoleProprietor(name: "Consulting AG")

    // Insert documents scoped to each entity
    let doc1 = Document(
        workspaceId: workspaceId,
        blobHash: "entity1-doc-\(UUID().uuidString)",
        originalFilename: "entity1-receipt.pdf",
        mediaType: "application/pdf",
        entityId: entity1.id
    )
    let doc2 = Document(
        workspaceId: workspaceId,
        blobHash: "entity2-doc-\(UUID().uuidString)",
        originalFilename: "entity2-invoice.pdf",
        mediaType: "application/pdf",
        entityId: entity2.id
    )
    let docUnscoped = Document(
        workspaceId: workspaceId,
        blobHash: "unscoped-doc-\(UUID().uuidString)",
        originalFilename: "unscoped.pdf",
        mediaType: "application/pdf"
    )
    try storage.documentRepository.saveDocument(doc1)
    try storage.documentRepository.saveDocument(doc2)
    try storage.documentRepository.saveDocument(docUnscoped)

    let entity1Docs = try storage.documentRepository.fetchDocuments(entityId: entity1.id)
    let entity2Docs = try storage.documentRepository.fetchDocuments(entityId: entity2.id)

    #expect(entity1Docs.count == 1)
    #expect(entity1Docs.first?.id == doc1.id)
    #expect(entity2Docs.count == 1)
    #expect(entity2Docs.first?.id == doc2.id)

    // Workspace-wide fetch returns all
    let allDocs = try storage.documentRepository.fetchDocuments(workspaceId: workspaceId)
    #expect(allDocs.count == 3)
}

@Test
func entityWorkspaceCRUDAndUniqueConstraint() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "EW CRUD Workspace")
    let workspaceId = storage.manifest.workspace.id
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: workspaceId).first)

    // Migration v5 auto-creates one — fetch it
    let existing = try #require(try storage.entityWorkspaceRepository.fetchEntityWorkspace(workspaceId: workspaceId, entityId: entity.id))
    #expect(existing.displayName == entity.displayName)
    #expect(existing.isDefault == true)

    // Update lastAccessedAt
    var updated = existing
    let newDate = Date(timeIntervalSince1970: 1800000000)
    updated.lastAccessedAt = newDate
    try storage.entityWorkspaceRepository.saveEntityWorkspace(updated)

    let reloaded = try #require(try storage.entityWorkspaceRepository.fetchEntityWorkspace(id: existing.id))
    #expect(reloaded.lastAccessedAt == newDate)

    // Delete
    try storage.entityWorkspaceRepository.deleteEntityWorkspace(id: existing.id)
    #expect(try storage.entityWorkspaceRepository.fetchEntityWorkspace(id: existing.id) == nil)

    // Re-create and verify unique constraint on (workspaceId, entityId) allows re-insert after delete
    let replacement = EntityWorkspace(
        workspaceId: workspaceId,
        entityId: entity.id,
        displayName: "Replacement"
    )
    try storage.entityWorkspaceRepository.saveEntityWorkspace(replacement)
    #expect(try storage.entityWorkspaceRepository.fetchEntityWorkspace(workspaceId: workspaceId, entityId: entity.id)?.displayName == "Replacement")

    // Inserting a duplicate (workspaceId, entityId) should fail
    let duplicate = EntityWorkspace(
        workspaceId: workspaceId,
        entityId: entity.id,
        displayName: "Duplicate"
    )
    #expect(throws: (any Error).self) {
        try storage.entityWorkspaceRepository.saveEntityWorkspace(duplicate)
    }
}
