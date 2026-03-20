import Foundation
import GRDB
import ALDomain

public protocol ImportJobRepository: Sendable {
    func fetchImportJobs(workspaceId: WorkspaceID) throws -> [ImportJob]
    func saveImportJob(_ job: ImportJob) throws
}

public final class GRDBImportJobRepository: ImportJobRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchImportJobs(workspaceId: WorkspaceID) throws -> [ImportJob] {
        try dbPool.read { db in
            try ImportJob
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("startedAt").desc)
                .fetchAll(db)
        }
    }

    public func saveImportJob(_ job: ImportJob) throws {
        try dbPool.write { db in
            try job.save(db)
        }
    }
}
