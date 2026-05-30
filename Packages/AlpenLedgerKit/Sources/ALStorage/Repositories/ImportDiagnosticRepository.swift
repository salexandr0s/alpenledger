import Foundation
import GRDB
import ALDomain

public protocol ImportDiagnosticRepository: Sendable {
    func fetchImportDiagnostics(workspaceId: WorkspaceID) throws -> [ImportDiagnostic]
    func fetchImportDiagnostics(importJobId: ImportJobID) throws -> [ImportDiagnostic]
    func saveImportDiagnostics(_ diagnostics: [ImportDiagnostic]) throws
}

public final class GRDBImportDiagnosticRepository: ImportDiagnosticRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchImportDiagnostics(workspaceId: WorkspaceID) throws -> [ImportDiagnostic] {
        try dbPool.read { db in
            try ImportDiagnostic.fetchAll(
                db,
                sql: """
                SELECT importDiagnostics.*
                FROM importDiagnostics
                JOIN importJobs ON importJobs.id = importDiagnostics.importJobId
                WHERE importJobs.workspaceId = ?
                ORDER BY importDiagnostics.createdAt, importDiagnostics.id
                """,
                arguments: [workspaceId]
            )
        }
    }

    public func fetchImportDiagnostics(importJobId: ImportJobID) throws -> [ImportDiagnostic] {
        try dbPool.read { db in
            try ImportDiagnostic
                .filter(Column("importJobId") == importJobId)
                .order(Column("createdAt"), Column("id"))
                .fetchAll(db)
        }
    }

    public func saveImportDiagnostics(_ diagnostics: [ImportDiagnostic]) throws {
        guard diagnostics.isEmpty == false else { return }
        try dbPool.write { db in
            for diagnostic in diagnostics {
                try diagnostic.save(db)
            }
        }
    }
}
