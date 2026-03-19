import Foundation
import ALDomain
import ALStorage
import ALAudit

public final class ImportPipeline: @unchecked Sendable {
    private let storage: WorkspaceStorage
    private let auditLogger: AuditLogger
    private let importers: [any Importer]

    public init(
        storage: WorkspaceStorage,
        auditLogger: AuditLogger,
        importers: [any Importer] = [CSVBankStatementImporter()]
    ) {
        self.storage = storage
        self.auditLogger = auditLogger
        self.importers = importers
    }

    public func importStatement(from url: URL, accountId: FinancialAccountID) throws -> ParseLog {
        guard let importer = try importers.first(where: { try $0.canRecognize(url) }) else {
            throw DomainError.unsupportedImportFormat
        }

        let sourceBlobHash = try storage.blobStore.store(contentsOf: url)
        let importJob = ImportJob(
            workspaceId: storage.manifest.workspace.id,
            kind: .bankStatementCSV,
            source: url.lastPathComponent,
            parserKey: importer.parserKey,
            parserVersion: importer.parserVersion
        )
        try storage.importJobRepository.saveImportJob(importJob)
        try auditLogger.log(
            eventType: .importJobCreated,
            objectRef: ObjectRef(kind: .importJob, id: importJob.id.rawValue),
            payload: url.lastPathComponent
        )

        do {
            let payload = try importer.parse(url, accountId: accountId, importJobId: importJob.id, sourceBlobHash: sourceBlobHash)
            if try storage.statementImportRepository.fetchStatementImport(accountId: accountId, fingerprint: payload.statementImport.sourceFingerprint) != nil {
                throw DomainError.duplicateStatementImport
            }

            var completedImportJob = importJob
            completedImportJob.status = .completed
            completedImportJob.completedAt = .now
            completedImportJob.warningCount = payload.parseLog.warnings.count

            try storage.statementImportRepository.saveStatementImport(payload.statementImport)
            try storage.transactionRepository.saveTransactions(payload.transactions)
            try storage.importJobRepository.saveImportJob(completedImportJob)
            try auditLogger.log(
                eventType: .importJobCompleted,
                objectRef: ObjectRef(kind: .importJob, id: completedImportJob.id.rawValue),
                payload: url.lastPathComponent
            )
            try auditLogger.log(
                actorType: .user,
                actorId: "user",
                eventType: .statementImported,
                objectRef: ObjectRef(kind: .statementImport, id: payload.statementImport.id.rawValue),
                payload: url.lastPathComponent
            )
            return payload.parseLog
        } catch {
            var failedImportJob = importJob
            failedImportJob.status = .failed
            failedImportJob.completedAt = .now
            try? storage.importJobRepository.saveImportJob(failedImportJob)
            throw error
        }
    }
}
