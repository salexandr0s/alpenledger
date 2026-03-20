import Foundation
import ALDomain
import ALStorage
import ALAudit

public final class ImportJobService: Sendable {
    private let repository: any ImportJobRepository
    private let pipeline: ImportPipeline
    private let workspaceId: WorkspaceID

    public init(storage: WorkspaceStorage, auditLogger: AuditLogger) {
        self.repository = storage.importJobRepository
        self.pipeline = ImportPipeline(storage: storage, auditLogger: auditLogger)
        self.workspaceId = storage.manifest.workspace.id
    }

    public func listImportJobs() throws -> [ImportJob] {
        try repository.fetchImportJobs(workspaceId: workspaceId)
    }

    public func importStatement(from url: URL, accountId: FinancialAccountID) throws -> ParseLog {
        try pipeline.importStatement(from: url, accountId: accountId)
    }
}
