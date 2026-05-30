import Foundation
import UniformTypeIdentifiers
import ALDomain
import ALStorage
import ALAudit

public final class DocumentService: Sendable {
    private let storage: WorkspaceStorage
    private let auditLogger: AuditLogger
    private let extractionPipeline: DocumentExtractionPipeline
    private let fileAccess: SecurityScopedResourceAccess
    private let parserKey = "document.intake"
    private let parserVersion = "1.0.0"

    public init(
        storage: WorkspaceStorage,
        auditLogger: AuditLogger,
        extractionPipeline: DocumentExtractionPipeline = DocumentExtractionPipeline(),
        fileAccess: SecurityScopedResourceAccess = .live
    ) {
        self.storage = storage
        self.auditLogger = auditLogger
        self.extractionPipeline = extractionPipeline
        self.fileAccess = fileAccess
    }

    @discardableResult
    public func importDocument(from url: URL, entityId: LegalEntityID? = nil) throws -> Document {
        try fileAccess.withAccess(to: url) {
            if let entityId {
                _ = try storage.requireEntity(entityId: entityId)
            }
            let mediaType = detectedMediaType(for: url)
            let sourceData = try Data(contentsOf: url)
            let sourceBlobHash = WorkspaceCrypto.sha256Hex(for: sourceData)
            let blobExistedBeforeImport = try storage.blobStore.contains(hash: sourceBlobHash)
            let blobHash = try storage.blobStore.store(data: sourceData)
            let importJob = ImportJob(
                workspaceId: storage.manifest.workspace.id,
                kind: .documentIntake,
                source: url.lastPathComponent,
                sourceBlobHash: blobHash,
                sourceFingerprint: blobHash,
                parserKey: parserKey,
                parserVersion: parserVersion
            )
            let fileExt = url.pathExtension.isEmpty ? nil : url.pathExtension
            var materializedSource = false
            var blobReferencedByDocument = false

            do {
                try storage.importJobRepository.saveImportJob(importJob)
                try auditLogger.log(
                    eventType: .importJobCreated,
                    objectRef: ObjectRef(kind: .importJob, id: importJob.id.rawValue),
                    payload: url.lastPathComponent
                )

                if let existing = try storage.documentRepository.fetchDocument(workspaceId: storage.manifest.workspace.id, blobHash: blobHash) {
                    blobReferencedByDocument = true
                    let scopedExisting = restoredDocument(try scopedDocument(existing, entityId: entityId))
                    if scopedExisting != existing {
                        try storage.documentRepository.saveDocument(scopedExisting)
                        try storage.searchIndex.indexDocument(scopedExisting)
                        if existing.status == .archived {
                            try auditLogger.log(
                                actorType: .user,
                                actorId: "user",
                                eventType: .documentRestored,
                                objectRef: ObjectRef(kind: .document, id: scopedExisting.id.rawValue),
                                payload: "Re-imported archived source: \(url.lastPathComponent)"
                            )
                        }
                    }
                    try completeImportJob(importJob, source: url.lastPathComponent)
                    return scopedExisting
                }

                let materializedURL = try storage.blobStore.materialize(hash: blobHash, fileExtension: fileExt)
                materializedSource = true
                defer {
                    if materializedSource {
                        try? storage.blobStore.cleanupMaterialized(hash: blobHash, fileExtension: fileExt)
                    }
                }

                let extractedText = extractionPipeline.extractText(from: materializedURL, mediaType: mediaType)
                let detectedMetadata = extractionPipeline.detectMetadata(
                    filename: url.lastPathComponent,
                    extractedText: extractedText
                )
                let issueDate = extractionPipeline.inferredIssueDate(from: extractedText)
                let diagnostics = documentImportDiagnostics(
                    importJobId: importJob.id,
                    detectedMetadata: detectedMetadata
                )

                let document = Document(
                    workspaceId: storage.manifest.workspace.id,
                    importJobId: importJob.id,
                    blobHash: blobHash,
                    originalFilename: url.lastPathComponent,
                    mediaType: mediaType,
                    documentType: detectedMetadata.documentType,
                    issueDate: issueDate,
                    entityId: entityId,
                    extractedText: extractedText,
                    metadataStatus: detectedMetadata.metadataStatus,
                    parseVersion: parserVersion
                )
                try storage.documentRepository.saveDocument(document)
                blobReferencedByDocument = true
                try storage.searchIndex.indexDocument(document)
                try completeImportJob(importJob, source: url.lastPathComponent, diagnostics: diagnostics)
                try auditLogger.log(
                    actorType: .user,
                    actorId: "user",
                    eventType: .documentImported,
                    objectRef: ObjectRef(kind: .document, id: document.id.rawValue),
                    payload: document.originalFilename
                )
                return document
            } catch {
                try? failImportJob(importJob, error: error)
                if blobExistedBeforeImport == false, blobReferencedByDocument == false {
                    try? storage.blobStore.delete(hash: blobHash)
                }
                throw error
            }
        }
    }

    public func binaryRef(for document: Document) throws -> DocumentBinaryRef {
        let fileExtension = URL(fileURLWithPath: document.originalFilename).pathExtension
        let materializedURL = try storage.blobStore.materialize(hash: document.blobHash, fileExtension: fileExtension.isEmpty ? nil : fileExtension)
        return DocumentBinaryRef(documentId: document.id, originalFilename: document.originalFilename, fileURL: materializedURL)
    }

    @discardableResult
    public func reviewDocumentMetadata(
        _ documentId: DocumentID,
        documentType: DocumentType,
        issueDate: Date?,
        actorId: String = "user"
    ) throws -> Document {
        guard var document = try storage.documentRepository.fetchDocument(id: documentId),
              document.workspaceId == storage.manifest.workspace.id,
              document.status == .active
        else {
            throw DomainError.invalidDocumentMetadataReview
        }

        let previousType = document.documentType
        let previousIssueDate = document.issueDate
        let previousStatus = document.metadataStatus
        document.documentType = documentType
        document.issueDate = issueDate
        document.metadataStatus = .confirmed

        try storage.documentRepository.saveDocument(document)
        try storage.searchIndex.indexDocument(document)
        try auditLogger.log(
            actorType: .user,
            actorId: actorId,
            eventType: .documentMetadataReviewed,
            objectRef: ObjectRef(kind: .document, id: document.id.rawValue),
            payload: metadataReviewPayload(
                previousType: previousType,
                reviewedType: documentType,
                previousIssueDate: previousIssueDate,
                reviewedIssueDate: issueDate,
                previousStatus: previousStatus
            )
        )
        return document
    }

    public func linkDocument(_ documentId: DocumentID, to transactionId: TransactionID) throws {
        let scope = try validateDocumentLink(documentId: documentId, transactionId: transactionId)
        if scope.document != scope.scopedDocument {
            try storage.documentRepository.saveDocument(scope.scopedDocument)
            try storage.searchIndex.indexDocument(scope.scopedDocument)
        }

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
            objectRef: ObjectRef(kind: .evidenceLink, id: link.id.rawValue),
            payload: scope.document.entityId == nil
                ? "Manual link; document assigned to transaction entity."
                : "Manual link"
        )
    }

    @discardableResult
    public func archiveDocument(
        _ documentId: DocumentID,
        actorId: String = "user",
        reason: String,
        now: Date = .now
    ) throws -> Document {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedReason.isEmpty == false, trimmedReason.count <= 1_000 else {
            throw DomainError.invalidDocumentArchive
        }
        guard var document = try storage.documentRepository.fetchDocument(id: documentId),
              document.workspaceId == storage.manifest.workspace.id
        else {
            throw DomainError.invalidDocumentArchive
        }
        guard document.status == .active else {
            return document
        }

        let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)
        guard try confirmedEvidenceLinks(for: documentRef).isEmpty,
              try storage.requirementRepository.fetchRequirements(satisfiedByRef: documentRef).isEmpty,
              try storage.taxFactRepository.fetchCurrentTaxFacts(sourceRef: documentRef).isEmpty
        else {
            throw DomainError.invalidDocumentArchive
        }

        document.status = .archived
        document.archivedAt = now
        document.archivedBy = actorId
        document.archiveReason = trimmedReason
        try storage.documentRepository.saveDocument(document)
        try storage.searchIndex.indexDocument(document)
        try auditLogger.log(
            actorType: .user,
            actorId: actorId,
            eventType: .documentArchived,
            objectRef: documentRef,
            payload: trimmedReason
        )
        return document
    }

    @discardableResult
    public func restoreArchivedDocument(
        _ documentId: DocumentID,
        actorId: String = "user",
        reason: String
    ) throws -> Document {
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedReason.isEmpty == false, trimmedReason.count <= 1_000 else {
            throw DomainError.invalidDocumentRestore
        }
        guard var document = try storage.documentRepository.fetchDocument(id: documentId),
              document.workspaceId == storage.manifest.workspace.id
        else {
            throw DomainError.invalidDocumentRestore
        }
        guard document.status == .archived else {
            return document
        }

        document = restoredDocument(document)
        try storage.documentRepository.saveDocument(document)
        try storage.searchIndex.indexDocument(document)
        try auditLogger.log(
            actorType: .user,
            actorId: actorId,
            eventType: .documentRestored,
            objectRef: ObjectRef(kind: .document, id: document.id.rawValue),
            payload: trimmedReason
        )
        return document
    }

    public func linkedTransactionIDs(for documentId: DocumentID) throws -> [TransactionID] {
        let links = try storage.evidenceLinkRepository.fetchEvidenceLinks(for: ObjectRef(kind: .document, id: documentId.rawValue))
        return links.filter { $0.status == .confirmed }.compactMap { link in
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

    private func metadataReviewPayload(
        previousType: DocumentType,
        reviewedType: DocumentType,
        previousIssueDate: Date?,
        reviewedIssueDate: Date?,
        previousStatus: MetadataStatus
    ) -> String {
        [
            "type=\(previousType.rawValue)->\(reviewedType.rawValue)",
            "issueDate=\(metadataDateString(previousIssueDate))->\(metadataDateString(reviewedIssueDate))",
            "status=\(previousStatus.rawValue)->\(MetadataStatus.confirmed.rawValue)",
        ].joined(separator: "; ")
    }

    private func metadataDateString(_ date: Date?) -> String {
        guard let date else {
            return "nil"
        }
        return ISO8601DateFormatter().string(from: date)
    }

    private func validateDocumentLink(
        documentId: DocumentID,
        transactionId: TransactionID
    ) throws -> (document: Document, scopedDocument: Document, transaction: Transaction, account: FinancialAccount) {
        guard let document = try storage.documentRepository.fetchDocument(id: documentId),
              document.workspaceId == storage.manifest.workspace.id,
              document.status == .active,
              let transaction = try storage.transactionRepository.fetchTransactions(ids: [transactionId]).first,
              let account = try storage.financialAccountRepository.fetchFinancialAccount(id: transaction.accountId)
        else {
            throw DomainError.invalidEvidenceLink
        }

        return (
            document,
            try scopedDocument(document, entityId: account.entityId),
            transaction,
            account
        )
    }

    private func scopedDocument(_ document: Document, entityId: LegalEntityID?) throws -> Document {
        guard document.workspaceId == storage.manifest.workspace.id else {
            throw DomainError.invalidEvidenceLink
        }
        guard let entityId else {
            return document
        }
        _ = try storage.requireEntity(entityId: entityId)
        if let documentEntityId = document.entityId {
            guard documentEntityId == entityId else {
                throw DomainError.invalidEvidenceLink
            }
            return document
        }

        var scopedDocument = document
        scopedDocument.entityId = entityId
        return scopedDocument
    }

    private func restoredDocument(_ document: Document) -> Document {
        guard document.status == .archived else {
            return document
        }
        var restored = document
        restored.status = .active
        restored.archivedAt = nil
        restored.archivedBy = nil
        restored.archiveReason = nil
        return restored
    }

    private func confirmedEvidenceLinks(for documentRef: ObjectRef) throws -> [EvidenceLink] {
        try storage.evidenceLinkRepository
            .fetchEvidenceLinks(for: documentRef)
            .filter { $0.status == .confirmed }
    }

    private func completeImportJob(
        _ importJob: ImportJob,
        source: String,
        diagnostics: [ImportDiagnostic] = []
    ) throws {
        var completed = importJob
        completed.status = .completed
        completed.completedAt = .now
        completed.warningCount = diagnostics.filter { $0.severity == .warning }.count
        try storage.importJobRepository.saveImportJob(completed)
        if diagnostics.isEmpty == false {
            try storage.importDiagnosticRepository.saveImportDiagnostics(diagnostics)
        }
        try auditLogger.log(
            eventType: .importJobCompleted,
            objectRef: ObjectRef(kind: .importJob, id: completed.id.rawValue),
            payload: source
        )
    }

    private func failImportJob(_ importJob: ImportJob, error: Error) throws {
        var failed = importJob
        failed.status = .failed
        failed.completedAt = .now
        let diagnostic = ImportDiagnostic(
            importJobId: importJob.id,
            severity: .error,
            code: "document.import_failed",
            message: error.localizedDescription
        )
        try storage.importJobRepository.saveImportJob(failed)
        try storage.importDiagnosticRepository.saveImportDiagnostics([diagnostic])
    }

    private func documentImportDiagnostics(
        importJobId: ImportJobID,
        detectedMetadata: DocumentMetadataDetection
    ) -> [ImportDiagnostic] {
        guard detectedMetadata.confidence == .low else {
            return []
        }

        return [
            ImportDiagnostic(
                importJobId: importJobId,
                severity: .warning,
                code: "document.low_confidence_metadata",
                message: "Document metadata needs review: \(detectedMetadata.reason)"
            ),
        ]
    }
}
