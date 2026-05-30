import Foundation
import GRDB
import ALDomain

public protocol SearchIndex: Sendable {
    func indexDocument(_ document: Document) throws
    func searchDocumentIDs(workspaceId: WorkspaceID, query: String) throws -> [DocumentID]
    func search(workspaceId: WorkspaceID, query: String, limit: Int) throws -> [GlobalSearchHit]
}

public struct GlobalSearchHit: Hashable, Codable, Identifiable, Sendable {
    public var id: String { objectRef.stringValue }

    public let objectRef: ObjectRef
    public let workspaceId: WorkspaceID
    public let entityId: LegalEntityID?
    public let objectKind: ObjectKind
    public let title: String
    public let subtitle: String?
    public let snippet: String
    public let rank: Double

    public init(
        objectRef: ObjectRef,
        workspaceId: WorkspaceID,
        entityId: LegalEntityID?,
        objectKind: ObjectKind,
        title: String,
        subtitle: String?,
        snippet: String,
        rank: Double
    ) {
        self.objectRef = objectRef
        self.workspaceId = workspaceId
        self.entityId = entityId
        self.objectKind = objectKind
        self.title = title
        self.subtitle = subtitle
        self.snippet = snippet
        self.rank = rank
    }
}

public final class SQLiteSearchIndex: SearchIndex, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func indexDocument(_ document: Document) throws {
        try dbPool.write { db in
            let existingRows = try Int64.fetchAll(
                db,
                sql: "SELECT rowid FROM document_search WHERE documentId = ?",
                arguments: [document.id]
            )
            for rowid in existingRows {
                try db.execute(
                    sql: "DELETE FROM document_search WHERE rowid = ?",
                    arguments: [rowid]
                )
            }
            guard document.status == .active else {
                return
            }
            let content = documentSearchContent(for: document)
            guard content.isEmpty == false else {
                return
            }
            try db.execute(
                sql: """
                INSERT INTO document_search(documentId, workspaceId, content)
                VALUES (?, ?, ?)
                """,
                arguments: [document.id, document.workspaceId, content]
            )
        }
    }

    public func searchDocumentIDs(workspaceId: WorkspaceID, query: String) throws -> [DocumentID] {
        let sanitized = sanitizeFTS5Query(query)
        guard sanitized.isEmpty == false else {
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
                arguments: [workspaceId, sanitized]
            )
            return rows.compactMap { (row: Row) in
                guard let value: String = row["documentId"], let uuid = UUID(uuidString: value) else {
                    return nil
                }
                return DocumentID(rawValue: uuid)
            }
        }
    }

    public func search(workspaceId: WorkspaceID, query: String, limit: Int = 25) throws -> [GlobalSearchHit] {
        let sanitized = sanitizeFTS5Query(query)
        guard sanitized.isEmpty == false else {
            return []
        }
        let boundedLimit = max(1, min(limit, 100))

        return try dbPool.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    globalSearchRecords.objectRef,
                    globalSearchRecords.workspaceId,
                    globalSearchRecords.entityId,
                    globalSearchRecords.objectKind,
                    globalSearchRecords.title,
                    globalSearchRecords.subtitle,
                    COALESCE(NULLIF(TRIM(snippet(global_search, -1, '', '', '...', 16)), ''), globalSearchRecords.title) AS snippet,
                    rank
                FROM global_search
                JOIN globalSearchRecords ON globalSearchRecords.rowid = global_search.rowid
                WHERE globalSearchRecords.workspaceId = ? AND global_search MATCH ?
                ORDER BY rank, globalSearchRecords.objectKind, globalSearchRecords.title
                LIMIT ?
                """,
                arguments: [workspaceId, sanitized, boundedLimit]
            )
            return rows.compactMap { row in
                guard
                    let objectRefValue: String = row["objectRef"],
                    let objectRef = ObjectRef.parse(objectRefValue),
                    let objectKindValue: String = row["objectKind"],
                    let objectKind = ObjectKind(rawValue: objectKindValue)
                else {
                    return nil
                }

                let title: String = row["title"] ?? objectRef.stringValue
                let snippet: String = row["snippet"] ?? title
                return GlobalSearchHit(
                    objectRef: objectRef,
                    workspaceId: row["workspaceId"],
                    entityId: row["entityId"],
                    objectKind: objectKind,
                    title: title,
                    subtitle: row["subtitle"],
                    snippet: snippet,
                    rank: row["rank"] ?? 0
                )
            }
        }
    }

    private func sanitizeFTS5Query(_ input: String) -> String {
        let stripped = input
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard stripped.isEmpty == false else { return "" }
        return "\"\(stripped)\""
    }
}

private func documentSearchContent(for document: Document) -> String {
    guard let extractedText = document.extractedText?.trimmingCharacters(in: .whitespacesAndNewlines),
          extractedText.isEmpty == false
    else {
        return ""
    }
    let normalized = extractedText
        .map { character in
            character.isLetter || character.isNumber ? character : " "
        }
    return String(normalized)
        .split(separator: " ")
        .joined(separator: " ")
}
