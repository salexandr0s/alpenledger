import Foundation
import Testing
@testable import ALAudit
@testable import ALDocuments
@testable import ALDomain
@testable import ALEvidence
@testable import ALImports
@testable import ALStorage
@testable import ALWorkspace

@Test
func documentServiceBracketsImportedSourceWithSecurityScopedAccess() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "Security Scoped Document Workspace")
    let recorder = DocumentSecurityScopeRecorder()
    let documentService = DocumentService(
        storage: storage,
        auditLogger: AuditLogger(storage: storage),
        fileAccess: recorder.access
    )
    let sourceURL = try textFixtureURL(
        filename: "scoped-receipt.txt",
        contents: "Receipt\nVendor: Scoped Shop\nTotal: CHF 42.00"
    )

    let document = try documentService.importDocument(from: sourceURL)

    #expect(document.originalFilename == "scoped-receipt.txt")
    #expect(document.documentType == .receipt)
    #expect(document.metadataStatus == .confirmed)
    #expect(recorder.startedPaths == [sourceURL.standardizedFileURL.path])
    #expect(recorder.stoppedPaths == [sourceURL.standardizedFileURL.path])
}

@Test
func documentServiceStoresLowConfidenceMetadataAsProposedWithDiagnostic() throws {
    let harness = try DocumentServiceHarness(name: "Low Confidence Document Workspace")
    let business = try harness.createBusinessEntity(name: "Low Confidence Business")
    let auditLogger = AuditLogger(storage: harness.storage)
    let importJobService = ImportJobService(storage: harness.storage, auditLogger: auditLogger)
    _ = try importJobService.importStatement(
        from: try fixtureURL("Fixtures/Bank/sample-bank-statement.csv"),
        accountId: business.account.id
    )

    let document = try harness.documentService.importDocument(
        from: try fixtureURL("Fixtures/Documents/sample-receipt.pdf"),
        entityId: business.entity.id
    )
    try EvidenceRefreshService(storage: harness.storage, auditLogger: auditLogger).refresh()

    let importJob = try #require(
        try harness.storage.importJobRepository
            .fetchImportJobs(workspaceId: harness.storage.manifest.workspace.id)
            .first
    )
    let diagnostics = try harness.storage.importDiagnosticRepository.fetchImportDiagnostics(importJobId: importJob.id)

    #expect(document.documentType == .receipt)
    #expect(document.extractedText == nil)
    #expect(document.metadataStatus == .proposed)
    #expect(importJob.status == .completed)
    #expect(importJob.warningCount == 1)
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.severity == .warning)
    #expect(diagnostics.first?.code == "document.low_confidence_metadata")
    #expect(diagnostics.first?.message.contains("needs review") == true)
    #expect(try harness.storage.databaseHealthReport().isHealthy)
}

@Test
func documentImportFailureRemovesNewBlobAndTempMaterialization() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "Document Failure Workspace")
    let auditLogger = AuditLogger(storage: storage)
    let documentService = DocumentService(storage: storage, auditLogger: auditLogger)
    let sourceData = Data("Receipt\nDate: 2026-05-30\nTotal: CHF 42.00".utf8)
    let sourceHash = WorkspaceCrypto.sha256Hex(for: sourceData)
    let sourceURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("receipt.txt")
    try fileManager.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try sourceData.write(to: sourceURL)

    #expect(try storage.blobStore.contains(hash: sourceHash) == false)
    try fileManager.removeItem(at: storage.paths.tempURL)
    try Data("not a directory".utf8).write(to: storage.paths.tempURL)

    do {
        _ = try documentService.importDocument(from: sourceURL)
        Issue.record("Expected document import to fail when the temp materialization path is blocked.")
    } catch {
        #expect(error.localizedDescription.isEmpty == false)
    }

    #expect(try storage.documentRepository.fetchDocument(workspaceId: storage.manifest.workspace.id, blobHash: sourceHash) == nil)
    #expect(try storage.blobStore.contains(hash: sourceHash) == false)
    #expect(fileManager.fileExists(atPath: storage.paths.tempURL.appendingPathComponent("\(sourceHash).txt").path) == false)

    let importJob = try #require(try storage.importJobRepository.fetchImportJobs(workspaceId: storage.manifest.workspace.id).first)
    #expect(importJob.status == .failed)
    #expect(importJob.sourceBlobHash == sourceHash)
    let diagnostics = try storage.importDiagnosticRepository.fetchImportDiagnostics(importJobId: importJob.id)
    #expect(diagnostics.count == 1)
    #expect(diagnostics.first?.severity == .error)
    #expect(diagnostics.first?.code == "document.import_failed")
}

@Test
func documentServiceImportsECHTaxCertificateFixturesWithDetectedTypes() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
        nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
    )
    let storage = try workspaceService.createWorkspace(named: "eCH Document Fixture Workspace")
    let documentService = DocumentService(storage: storage, auditLogger: AuditLogger(storage: storage))
    let cases: [(String, DocumentType)] = [
        ("Fixtures/Tax/eCH/eCH-0196-tax-statement-2026.xml", .eCH0196TaxStatement),
        ("Fixtures/Tax/eCH/eCH-0248-pension-contributions-2026.xml", .eCH0248PensionCertificate),
        ("Fixtures/Tax/eCH/eCH-0275-health-insurance-2026.xml", .eCH0275HealthInsuranceCertificate),
    ]

    for (path, expectedType) in cases {
        let document = try documentService.importDocument(from: try fixtureURL(path))
        let issueDate = try #require(document.issueDate)
        let year = Calendar(identifier: .gregorian).component(.year, from: issueDate)

        #expect(document.documentType == expectedType)
        #expect(document.metadataStatus == .confirmed)
        #expect(document.mediaType == "application/xml" || document.mediaType == "text/xml")
        #expect(document.extractedText?.contains("taxYear") == true)
        #expect(year == 2026)
    }

    let documents = try storage.documentRepository.fetchDocuments(workspaceId: storage.manifest.workspace.id)
    let importJobs = try storage.importJobRepository.fetchImportJobs(workspaceId: storage.manifest.workspace.id)
    #expect(documents.count == cases.count)
    #expect(importJobs.allSatisfy { $0.status == .completed })
}

@Test
func documentServiceScopesDuplicateImportsToRequestedEntity() throws {
    let harness = try DocumentServiceHarness(name: "Document Duplicate Scope Workspace")
    let business = try harness.createBusinessEntity(name: "Duplicate Scope Business")
    let sourceURL = try textFixtureURL(
        filename: "duplicate-scope-receipt.txt",
        contents: "Receipt\nVendor: Scope Shop\nTotal: CHF 42.00"
    )

    let unassigned = try harness.documentService.importDocument(from: sourceURL)
    #expect(unassigned.entityId == nil)

    let scoped = try harness.documentService.importDocument(from: sourceURL, entityId: harness.entity.id)
    #expect(scoped.id == unassigned.id)
    #expect(scoped.entityId == harness.entity.id)
    #expect(try harness.storage.documentRepository.fetchDocument(id: scoped.id)?.entityId == harness.entity.id)

    do {
        _ = try harness.documentService.importDocument(from: sourceURL, entityId: business.entity.id)
        Issue.record("Expected duplicate document import for another entity to be rejected.")
    } catch let error as DomainError {
        #expect(error == .invalidEvidenceLink)
    }
}

@Test
func documentServiceReviewsMetadataWithAuditAndSearchRefresh() throws {
    let harness = try DocumentServiceHarness(name: "Document Metadata Review Workspace")
    let sourceURL = try textFixtureURL(
        filename: "metadata-review-receipt.txt",
        contents: "Receipt\nVendor: Metadata Review Shop\nTotal: CHF 42.00"
    )
    let document = try harness.documentService.importDocument(from: sourceURL, entityId: harness.entity.id)
    var proposed = document
    proposed.documentType = .unknown
    proposed.issueDate = nil
    proposed.metadataStatus = .proposed
    try harness.storage.documentRepository.saveDocument(proposed)
    try harness.storage.searchIndex.indexDocument(proposed)

    let reviewedDate = Date(timeIntervalSince1970: 1_767_355_200)
    let reviewed = try harness.documentService.reviewDocumentMetadata(
        document.id,
        documentType: .salaryCertificate,
        issueDate: reviewedDate,
        actorId: "reviewer"
    )

    #expect(reviewed.documentType == .salaryCertificate)
    #expect(reviewed.issueDate == reviewedDate)
    #expect(reviewed.metadataStatus == .confirmed)

    let stored = try #require(try harness.storage.documentRepository.fetchDocument(id: document.id))
    #expect(stored.documentType == .salaryCertificate)
    #expect(stored.issueDate == reviewedDate)
    #expect(stored.metadataStatus == .confirmed)
    #expect(try harness.storage.searchIndex
        .searchDocumentIDs(workspaceId: harness.storage.manifest.workspace.id, query: "Metadata Review")
        .contains(document.id))

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .document, id: document.id.rawValue)
    )
    let reviewEvent = try #require(auditEvents.first { $0.eventType == .documentMetadataReviewed })
    #expect(reviewEvent.actorId == "reviewer")
    #expect(reviewEvent.payload?.contains("unknown->salaryCertificate") == true)
    #expect(reviewEvent.payload?.contains("proposed->confirmed") == true)
}

@Test
func documentServiceRejectsMetadataReviewForArchivedDocument() throws {
    let harness = try DocumentServiceHarness(name: "Document Archived Metadata Review Workspace")
    let sourceURL = try textFixtureURL(
        filename: "archived-metadata-review-receipt.txt",
        contents: "Receipt\nVendor: Archived Metadata Shop\nTotal: CHF 21.00"
    )
    let document = try harness.documentService.importDocument(from: sourceURL, entityId: harness.entity.id)
    _ = try harness.documentService.archiveDocument(
        document.id,
        actorId: "reviewer",
        reason: "Testing archived metadata review block."
    )

    do {
        _ = try harness.documentService.reviewDocumentMetadata(
            document.id,
            documentType: .invoice,
            issueDate: Date(timeIntervalSince1970: 1_767_355_200)
        )
        Issue.record("Expected archived document metadata review to be rejected.")
    } catch let error as DomainError {
        #expect(error == .invalidDocumentMetadataReview)
    }

    let stored = try #require(try harness.storage.documentRepository.fetchDocument(id: document.id))
    #expect(stored.status == .archived)
    #expect(stored.documentType == .receipt)
}

@Test
func documentServiceRejectsCrossEntityLinksAndScopesUnassignedLinks() throws {
    let harness = try DocumentServiceHarness(name: "Document Link Scope Workspace")
    let business = try harness.createBusinessEntity(name: "Document Link Business")
    let transaction = Transaction(
        accountId: harness.account.id,
        originKind: .manual,
        sourceLineRef: "document-link-personal",
        bookingDate: Date(timeIntervalSince1970: 1_767_184_000),
        amountMinor: -4_200,
        currency: .chf,
        counterpartyName: "Scope Shop",
        memo: "Personal receipt"
    )
    try harness.storage.transactionRepository.saveTransactions([transaction])

    let businessDocumentURL = try textFixtureURL(
        filename: "business-only-receipt.txt",
        contents: "Receipt\nVendor: Business Shop\nTotal: CHF 42.00"
    )
    let businessDocument = try harness.documentService.importDocument(
        from: businessDocumentURL,
        entityId: business.entity.id
    )

    do {
        try harness.documentService.linkDocument(businessDocument.id, to: transaction.id)
        Issue.record("Expected cross-entity document link to be rejected.")
    } catch let error as DomainError {
        #expect(error == .invalidEvidenceLink)
    }
    #expect(try harness.storage.evidenceLinkRepository
        .fetchEvidenceLinks(for: ObjectRef(kind: .document, id: businessDocument.id.rawValue))
        .isEmpty)

    let unassignedDocumentURL = try textFixtureURL(
        filename: "unassigned-link-receipt.txt",
        contents: "Receipt\nVendor: Personal Shop\nTotal: CHF 42.00"
    )
    let unassignedDocument = try harness.documentService.importDocument(from: unassignedDocumentURL)
    try harness.documentService.linkDocument(unassignedDocument.id, to: transaction.id)

    let scopedDocument = try #require(try harness.storage.documentRepository.fetchDocument(id: unassignedDocument.id))
    #expect(scopedDocument.entityId == harness.entity.id)
    let links = try harness.storage.evidenceLinkRepository
        .fetchEvidenceLinks(for: ObjectRef(kind: .document, id: unassignedDocument.id.rawValue))
    #expect(links.count == 1)
    #expect(links.first?.status == .confirmed)
}

@Test
func documentServiceArchivesUnlinkedDocumentWithoutDeletingSource() throws {
    let harness = try DocumentServiceHarness(name: "Document Archive Workspace")
    let sourceURL = try textFixtureURL(
        filename: "archive-receipt.txt",
        contents: "Receipt\nVendor: Archive Shop\nTotal: CHF 21.00"
    )
    let document = try harness.documentService.importDocument(from: sourceURL, entityId: harness.entity.id)
    let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)
    #expect(try harness.storage.blobStore.contains(hash: document.blobHash))
    #expect(try harness.storage.searchIndex
        .searchDocumentIDs(workspaceId: harness.storage.manifest.workspace.id, query: "Archive Shop")
        .contains(document.id))

    let archivedAt = Date(timeIntervalSince1970: 1_767_270_000)
    let archived = try harness.documentService.archiveDocument(
        document.id,
        actorId: "reviewer",
        reason: "Duplicate intake file.",
        now: archivedAt
    )

    #expect(archived.status == .archived)
    #expect(archived.archivedAt == archivedAt)
    #expect(archived.archivedBy == "reviewer")
    #expect(archived.archiveReason == "Duplicate intake file.")
    #expect(try harness.storage.blobStore.contains(hash: document.blobHash))
    #expect(try harness.storage.documentRepository
        .fetchDocuments(workspaceId: harness.storage.manifest.workspace.id)
        .map(\.id)
        .contains(document.id) == false)
    #expect(try harness.storage.documentRepository
        .fetchDocuments(entityId: harness.entity.id)
        .map(\.id)
        .contains(document.id) == false)
    #expect(try harness.storage.searchIndex
        .searchDocumentIDs(workspaceId: harness.storage.manifest.workspace.id, query: "Archive Shop")
        .contains(document.id) == false)

    let stored = try #require(try harness.storage.documentRepository.fetchDocument(id: document.id))
    #expect(stored.status == .archived)
    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: documentRef
    )
    #expect(auditEvents.contains(where: { $0.eventType == .documentArchived }))
}

@Test
func documentServiceRestoresArchivedDuplicateOnReimport() throws {
    let harness = try DocumentServiceHarness(name: "Document Archive Restore Workspace")
    let sourceURL = try textFixtureURL(
        filename: "restore-archived-receipt.txt",
        contents: "Receipt\nVendor: Restore Shop\nTotal: CHF 21.00"
    )
    let document = try harness.documentService.importDocument(from: sourceURL)
    _ = try harness.documentService.archiveDocument(
        document.id,
        actorId: "reviewer",
        reason: "Testing duplicate restore.",
        now: Date(timeIntervalSince1970: 1_767_270_000)
    )

    let restored = try harness.documentService.importDocument(from: sourceURL, entityId: harness.entity.id)

    #expect(restored.id == document.id)
    #expect(restored.status == .active)
    #expect(restored.entityId == harness.entity.id)
    #expect(restored.archivedAt == nil)
    #expect(restored.archivedBy == nil)
    #expect(restored.archiveReason == nil)
    #expect(try harness.storage.documentRepository
        .fetchDocuments(entityId: harness.entity.id)
        .map(\.id) == [document.id])
    #expect(try harness.storage.searchIndex
        .searchDocumentIDs(workspaceId: harness.storage.manifest.workspace.id, query: "Restore Shop")
        .contains(document.id))
}

@Test
func documentServiceRestoresArchivedDocumentExplicitly() throws {
    let harness = try DocumentServiceHarness(name: "Document Explicit Restore Workspace")
    let sourceURL = try textFixtureURL(
        filename: "explicit-restore-receipt.txt",
        contents: "Receipt\nVendor: Explicit Restore Shop\nTotal: CHF 21.00"
    )
    let document = try harness.documentService.importDocument(from: sourceURL, entityId: harness.entity.id)
    _ = try harness.documentService.archiveDocument(
        document.id,
        actorId: "reviewer",
        reason: "Testing explicit restore.",
        now: Date(timeIntervalSince1970: 1_767_270_000)
    )

    let restored = try harness.documentService.restoreArchivedDocument(
        document.id,
        actorId: "reviewer",
        reason: "Reviewer confirmed this source should be active."
    )

    #expect(restored.status == .active)
    #expect(restored.archivedAt == nil)
    #expect(restored.archivedBy == nil)
    #expect(restored.archiveReason == nil)
    #expect(try harness.storage.documentRepository
        .fetchDocuments(entityId: harness.entity.id)
        .map(\.id) == [document.id])
    #expect(try harness.storage.documentRepository
        .fetchDocuments(entityId: harness.entity.id, status: .archived)
        .isEmpty)
    #expect(try harness.storage.searchIndex
        .searchDocumentIDs(workspaceId: harness.storage.manifest.workspace.id, query: "Explicit Restore Shop")
        .contains(document.id))

    let auditEvents = try harness.storage.auditEventRepository.fetchAuditEvents(
        workspaceId: harness.storage.manifest.workspace.id,
        objectRef: ObjectRef(kind: .document, id: document.id.rawValue)
    )
    #expect(auditEvents.contains(where: { $0.eventType == .documentRestored }))
}

@Test
func documentServiceRejectsArchivingActiveEvidenceDocuments() throws {
    let harness = try DocumentServiceHarness(name: "Document Archive Evidence Workspace")
    let transaction = Transaction(
        accountId: harness.account.id,
        originKind: .manual,
        sourceLineRef: "document-archive-link",
        bookingDate: Date(timeIntervalSince1970: 1_767_184_000),
        amountMinor: -2_100,
        currency: .chf,
        counterpartyName: "Archive Evidence Shop",
        memo: "Linked receipt"
    )
    try harness.storage.transactionRepository.saveTransactions([transaction])
    let sourceURL = try textFixtureURL(
        filename: "archive-linked-receipt.txt",
        contents: "Receipt\nVendor: Archive Evidence Shop\nTotal: CHF 21.00"
    )
    let document = try harness.documentService.importDocument(from: sourceURL)
    try harness.documentService.linkDocument(document.id, to: transaction.id)

    do {
        _ = try harness.documentService.archiveDocument(
            document.id,
            actorId: "reviewer",
            reason: "Should be blocked."
        )
        Issue.record("Expected archiving a confirmed evidence document to be rejected.")
    } catch let error as DomainError {
        #expect(error == .invalidDocumentArchive)
    }

    let stored = try #require(try harness.storage.documentRepository.fetchDocument(id: document.id))
    #expect(stored.status == .active)
    let links = try harness.storage.evidenceLinkRepository
        .fetchEvidenceLinks(for: ObjectRef(kind: .document, id: document.id.rawValue))
    #expect(links.contains(where: { $0.status == .confirmed }))
}

@Test
func documentServiceRejectsArchivingFilingEvidenceDocuments() throws {
    let harness = try DocumentServiceHarness(name: "Document Archive Filing Evidence Workspace")
    let requirementDocument = try harness.documentService.importDocument(
        from: try textFixtureURL(
            filename: "archive-requirement-receipt.txt",
            contents: "Receipt\nVendor: Requirement Shop\nTotal: CHF 21.00"
        ),
        entityId: harness.entity.id
    )
    let requirementRef = ObjectRef(kind: .document, id: requirementDocument.id.rawValue)
    let requirement = Requirement(
        fingerprint: "archive-document-requirement",
        entityId: harness.entity.id,
        requirementCode: .expenseEvidence,
        subjectRef: ObjectRef(kind: .workspace, id: harness.storage.manifest.workspace.id.rawValue),
        summary: "Requirement satisfied by document",
        status: .satisfied,
        satisfiedByRef: requirementRef
    )
    try harness.storage.requirementRepository.saveRequirement(requirement)

    do {
        _ = try harness.documentService.archiveDocument(
            requirementDocument.id,
            actorId: "reviewer",
            reason: "Should be blocked."
        )
        Issue.record("Expected archiving a requirement support document to be rejected.")
    } catch let error as DomainError {
        #expect(error == .invalidDocumentArchive)
    }

    let taxYear = try #require(try harness.storage.taxYearRepository.fetchTaxYears(entityId: harness.entity.id).first)
    let taxFactDocument = try harness.documentService.importDocument(
        from: try textFixtureURL(
            filename: "archive-taxfact-certificate.txt",
            contents: "Salary certificate\nGross salary: CHF 1000.00"
        ),
        entityId: harness.entity.id
    )
    let factRef = ObjectRef(kind: .document, id: taxFactDocument.id.rawValue)
    let fact = TaxFact(
        fingerprint: "archive-document-tax-fact",
        entityId: harness.entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "archive.test.fact",
        valueType: .text,
        textValue: "supported",
        status: .observed,
        rulesetVersion: "test",
        provenanceRefs: [factRef]
    )
    try harness.storage.taxFactRepository.saveTaxFact(fact)

    do {
        _ = try harness.documentService.archiveDocument(
            taxFactDocument.id,
            actorId: "reviewer",
            reason: "Should be blocked."
        )
        Issue.record("Expected archiving a tax-fact source document to be rejected.")
    } catch let error as DomainError {
        #expect(error == .invalidDocumentArchive)
    }
}

private struct DocumentServiceHarness {
    let storage: WorkspaceStorage
    let documentService: DocumentService
    let legalEntityService: LegalEntityService
    let entity: LegalEntity
    let account: FinancialAccount

    init(name: String) throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storageManager = WorkspaceStorageManager(
            secretStore: InMemorySecretStore(),
            workspacesRootURL: rootURL
        )
        let workspaceService = WorkspaceService(
            storageManager: storageManager,
            recentStore: RecentWorkspacesStore(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
        )
        storage = try workspaceService.createWorkspace(named: name)
        let auditLogger = AuditLogger(storage: storage)
        documentService = DocumentService(storage: storage, auditLogger: auditLogger)
        legalEntityService = LegalEntityService(
            storage: storage,
            auditLogger: auditLogger,
            nowProvider: { Date(timeIntervalSince1970: 1_767_184_000) }
        )
        entity = try #require(try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first)
        account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
    }

    func createBusinessEntity(name: String) throws -> (entity: LegalEntity, account: FinancialAccount) {
        let entity = try legalEntityService.createSoleProprietor(name: name)
        let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)
        return (entity, account)
    }
}

private func textFixtureURL(filename: String, contents: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(filename)
    try Data(contents.utf8).write(to: url)
    return url
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

private final class DocumentSecurityScopeRecorder: @unchecked Sendable {
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
