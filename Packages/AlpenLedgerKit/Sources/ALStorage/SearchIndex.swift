import Foundation
import GRDB
import ALDomain

public protocol SearchIndex: Sendable {
    func indexDocument(_ document: Document) throws
    func searchDocumentIDs(workspaceId: WorkspaceID, query: String) throws -> [DocumentID]
}

public final class SQLiteSearchIndex: SearchIndex, @unchecked Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func indexDocument(_ document: Document) throws {
        try dbPool.write { db in
            try db.execute(
                sql: "DELETE FROM document_search WHERE documentId = ?",
                arguments: [document.id]
            )
            try db.execute(
                sql: """
                INSERT INTO document_search(documentId, workspaceId, content)
                VALUES (?, ?, ?)
                """,
                arguments: [document.id, document.workspaceId, document.extractedText ?? document.originalFilename]
            )
        }
    }

    public func searchDocumentIDs(workspaceId: WorkspaceID, query: String) throws -> [DocumentID] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return []
        }

        return try dbPool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT documentId
                FROM document_search
                WHERE workspaceId = ? AND content MATCH ?
                ORDER BY rank
                """,
                arguments: [workspaceId, query]
            )
            return rows.compactMap { row in
                guard let value: String = row["documentId"], let uuid = UUID(uuidString: value) else {
                    return nil
                }
                return DocumentID(rawValue: uuid)
            }
        }
    }
}
