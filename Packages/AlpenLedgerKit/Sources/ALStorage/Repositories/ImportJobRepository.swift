import Foundation
import GRDB
import ALDomain

public protocol ImportJobRepository: Sendable {
    func fetchImportJobs(workspaceId: WorkspaceID) throws -> [ImportJob]
    func fetchImportJob(workspaceId: WorkspaceID, id: ImportJobID) throws -> ImportJob?
    func fetchCompletedImportJob(
        workspaceId: WorkspaceID,
        kind: ImportJobKind,
        parserKey: String,
        parserVersion: String,
        sourceBlobHash: String
    ) throws -> ImportJob?
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

    public func fetchImportJob(workspaceId: WorkspaceID, id: ImportJobID) throws -> ImportJob? {
        try dbPool.read { db in
            try ImportJob
                .filter(Column("workspaceId") == workspaceId)
                .filter(Column("id") == id)
                .fetchOne(db)
        }
    }

    public func fetchCompletedImportJob(
        workspaceId: WorkspaceID,
        kind: ImportJobKind,
        parserKey: String,
        parserVersion: String,
        sourceBlobHash: String
    ) throws -> ImportJob? {
        try dbPool.read { db in
            try ImportJob
                .filter(Column("workspaceId") == workspaceId)
                .filter(Column("kind") == kind.rawValue)
                .filter(Column("parserKey") == parserKey)
                .filter(Column("parserVersion") == parserVersion)
                .filter(Column("sourceBlobHash") == sourceBlobHash)
                .filter(Column("status") == ImportJobStatus.completed.rawValue)
                .fetchOne(db)
        }
    }

    public func saveImportJob(_ job: ImportJob) throws {
        try dbPool.write { db in
            try job.save(db)
        }
    }
}
