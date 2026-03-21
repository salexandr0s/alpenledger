import Foundation
import UniformTypeIdentifiers
import ALDomain
import ALStorage
import ALAudit

public final class DocumentService: Sendable {
    private let storage: WorkspaceStorage
    private let auditLogger: AuditLogger
    private let extractionPipeline: DocumentExtractionPipeline
    private let parserKey = "document.intake"
    private let parserVersion = "1.0.0"

    public init(
        storage: WorkspaceStorage,
        auditLogger: AuditLogger,
        extractionPipeline: DocumentExtractionPipeline = DocumentExtractionPipeline()
    ) {
        self.storage = storage
        self.auditLogger = auditLogger
        self.extractionPipeline = extractionPipeline
    }

    @discardableResult
    public func importDocument(from url: URL, entityId: LegalEntityID? = nil) throws -> Document {
        let importJob = ImportJob(
            workspaceId: storage.manifest.workspace.id,
            kind: .documentIntake,
            source: url.lastPathComponent,
            parserKey: parserKey,
            parserVersion: parserVersion
        )
        try storage.importJobRepository.saveImportJob(importJob)
        try auditLogger.log(
            eventType: .importJobCreated,
            objectRef: ObjectRef(kind: .importJob, id: importJob.id.rawValue),
            payload: url.lastPathComponent
        )

        let mediaType = detectedMediaType(for: url)
        let blobHash = try storage.blobStore.store(contentsOf: url)

        if let existing = try storage.documentRepository.fetchDocument(workspaceId: storage.manifest.workspace.id, blobHash: blobHash) {
            try completeImportJob(importJob, source: url.lastPathComponent)
            return existing
        }

        let fileExt = url.pathExtension.isEmpty ? nil : url.pathExtension
        let materializedURL = try storage.blobStore.materialize(hash: blobHash, fileExtension: fileExt)
        let extractedText = extractionPipeline.extractText(from: materializedURL, mediaType: mediaType)
        let documentType = extractionPipeline.detectDocumentType(filename: url.lastPathComponent, extractedText: extractedText)
        let issueDate = extractionPipeline.inferredIssueDate(from: extractedText)
        try? storage.blobStore.cleanupMaterialized(hash: blobHash, fileExtension: fileExt)

        let document = Document(
            workspaceId: storage.manifest.workspace.id,
            importJobId: importJob.id,
            blobHash: blobHash,
            originalFilename: url.lastPathComponent,
            mediaType: mediaType,
            documentType: documentType,
            issueDate: issueDate,
            entityId: entityId,
            extractedText: extractedText,
            metadataStatus: .confirmed,
            parseVersion: parserVersion
        )
        try storage.documentRepository.saveDocument(document)
        try storage.searchIndex.indexDocument(document)
        try completeImportJob(importJob, source: url.lastPathComponent)
        try auditLogger.log(
            actorType: .user,
            actorId: "user",
            eventType: .documentImported,
            objectRef: ObjectRef(kind: .document, id: document.id.rawValue),
            payload: document.originalFilename
        )
        return document
    }

    public func binaryRef(for document: Document) throws -> DocumentBinaryRef {
        let fileExtension = URL(fileURLWithPath: document.originalFilename).pathExtension
        let materializedURL = try storage.blobStore.materialize(hash: document.blobHash, fileExtension: fileExtension.isEmpty ? nil : fileExtension)
        return DocumentBinaryRef(documentId: document.id, originalFilename: document.originalFilename, fileURL: materializedURL)
    }

    public func linkDocument(_ documentId: DocumentID, to transactionId: TransactionID) throws {
        let documentRef = ObjectRef(kind: .document, id: documentId.rawValue)
        let transactionRef = ObjectRef(kind: .transaction, id: transactionId.rawValue)
        let existingLinks = try storage.evidenceLinkRepository.fetchEvidenceLinks(for: transactionRef)
        if existingLinks.contains(where: {
            $0.status == .confirmed &&
                (($0.sourceRef == documentRef && $0.targetRef == transactionRef) ||
                    ($0.sourceRef == transactionRef && $0.targetRef == documentRef))
        }) {
            return
        }

        let link = EvidenceLink(
            sourceRef: documentRef,
            targetRef: transactionRef,
            linkType: .documentToTransaction,
            status: .confirmed,
            confidence: 1.0,
            createdByKind: .user,
            approvalRequired: false,
            reason: "Manual link"
        )
        try storage.evidenceLinkRepository.saveEvidenceLink(link)
        try auditLogger.log(
            actorType: .user,
            actorId: "user",
            eventType: .evidenceLinked,
            objectRef: ObjectRef(kind: .evidenceLink, id: link.id.rawValue)
        )
    }

    public func linkedTransactionIDs(for documentId: DocumentID) throws -> [TransactionID] {
        let links = try storage.evidenceLinkRepository.fetchEvidenceLinks(for: ObjectRef(kind: .document, id: documentId.rawValue))
        return links.compactMap { link in
            if link.sourceRef.kind == .transaction, let uuid = UUID(uuidString: link.sourceRef.id) {
                return TransactionID(rawValue: uuid)
            }
            if link.targetRef.kind == .transaction, let uuid = UUID(uuidString: link.targetRef.id) {
                return TransactionID(rawValue: uuid)
            }
            return nil
        }
    }

    private func detectedMediaType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension), let mimeType = type.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }

    private func completeImportJob(_ importJob: ImportJob, source: String) throws {
        var completed = importJob
        completed.status = .completed
        completed.completedAt = .now
        completed.warningCount = 0
        try storage.importJobRepository.saveImportJob(completed)
        try auditLogger.log(
            eventType: .importJobCompleted,
            objectRef: ObjectRef(kind: .importJob, id: completed.id.rawValue),
            payload: source
        )
    }
}
