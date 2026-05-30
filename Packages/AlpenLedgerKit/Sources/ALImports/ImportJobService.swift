import Foundation
import GRDB
import ALDomain
import ALStorage
import ALAudit

public final class ImportJobService: Sendable {
    private let storage: WorkspaceStorage
    private let repository: any ImportJobRepository
    private let diagnosticRepository: any ImportDiagnosticRepository
    private let pipeline: ImportPipeline
    private let workspaceId: WorkspaceID

    public init(
        storage: WorkspaceStorage,
        auditLogger: AuditLogger,
        fileAccess: SecurityScopedResourceAccess = .live
    ) {
        self.storage = storage
        self.repository = storage.importJobRepository
        self.diagnosticRepository = storage.importDiagnosticRepository
        self.pipeline = ImportPipeline(
            storage: storage,
            auditLogger: auditLogger,
            fileAccess: fileAccess
        )
        self.workspaceId = storage.manifest.workspace.id
    }

    public func listImportJobs() throws -> [ImportJob] {
        try repository.fetchImportJobs(workspaceId: workspaceId)
    }

    public func listImportDiagnostics() throws -> [ImportDiagnostic] {
        try diagnosticRepository.fetchImportDiagnostics(workspaceId: workspaceId)
    }

    public func listImportDiagnostics(importJobId: ImportJobID) throws -> [ImportDiagnostic] {
        try diagnosticRepository.fetchImportDiagnostics(importJobId: importJobId)
    }

    public func importStatement(from url: URL, accountId: FinancialAccountID) throws -> ParseLog {
        try pipeline.importStatement(from: url, accountId: accountId)
    }

    public func importStatement(
        from url: URL,
        accountId: FinancialAccountID,
        isCancellationRequested: @escaping @Sendable () -> Bool
    ) throws -> ParseLog {
        try pipeline.importStatement(
            from: url,
            accountId: accountId,
            isCancellationRequested: isCancellationRequested
        )
    }

    public func retryStatementImport(importJobId: ImportJobID, accountId: FinancialAccountID) throws -> ParseLog {
        try retryStatementImport(
            importJobId: importJobId,
            accountId: accountId,
            isCancellationRequested: { false }
        )
    }

    public func retryStatementImport(
        importJobId: ImportJobID,
        accountId: FinancialAccountID,
        isCancellationRequested: @escaping @Sendable () -> Bool
    ) throws -> ParseLog {
        guard let importJob = try repository.fetchImportJob(workspaceId: workspaceId, id: importJobId) else {
            throw DomainError.importJobNotFound
        }
        guard importJob.status == .failed || importJob.status == .cancelled else {
            throw DomainError.invalidImportRetry(reason: "only failed or cancelled imports can be retried")
        }
        guard importJob.kind == .bankStatementCSV || importJob.kind == .bankStatementCAMT else {
            throw DomainError.invalidImportRetry(reason: "only bank statement imports can be retried")
        }
        guard let sourceBlobHash = importJob.sourceBlobHash, sourceBlobHash.isEmpty == false else {
            throw DomainError.invalidImportRetry(reason: "stored raw source blob is missing")
        }
        guard try storage.blobStore.contains(hash: sourceBlobHash) else {
            throw DomainError.invalidImportRetry(reason: "stored raw source blob is missing")
        }

        let fileExtension = fileExtension(for: importJob.source)
        let materializedURL = try storage.blobStore.materialize(hash: sourceBlobHash, fileExtension: fileExtension)
        defer {
            try? storage.blobStore.cleanupMaterialized(hash: sourceBlobHash, fileExtension: fileExtension)
        }

        return try pipeline.importStatement(
            from: materializedURL,
            accountId: accountId,
            sourceName: importJob.source,
            isCancellationRequested: isCancellationRequested
        )
    }

    @discardableResult
    public func recoverInterruptedImports(recoveredAt: Date = .now) throws -> [ImportJob] {
        try storage.dbPool.write { db in
            let interruptedJobs = try ImportJob
                .filter(Column("workspaceId") == workspaceId)
                .filter(Column("status") == ImportJobStatus.started.rawValue)
                .order(Column("startedAt").asc)
                .fetchAll(db)

            for job in interruptedJobs {
                var failedJob = job
                failedJob.status = .failed
                failedJob.completedAt = recoveredAt
                failedJob.warningCount = max(failedJob.warningCount, 1)
                try failedJob.save(db)

                try ImportDiagnostic(
                    importJobId: job.id,
                    severity: .error,
                    code: "import.interrupted",
                    message: "Import was interrupted before completion and was marked failed during workspace recovery.",
                    createdAt: recoveredAt
                ).save(db)

                try AuditEvent(
                    workspaceId: workspaceId,
                    actorType: .system,
                    actorId: "system",
                    eventType: .importJobRecovered,
                    objectRef: ObjectRef(kind: .importJob, id: job.id.rawValue),
                    payload: job.source,
                    occurredAt: recoveredAt
                ).save(db)
            }

            return interruptedJobs
        }
    }

    private func fileExtension(for source: String) -> String? {
        let pathExtension = URL(fileURLWithPath: source).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension
    }
}
