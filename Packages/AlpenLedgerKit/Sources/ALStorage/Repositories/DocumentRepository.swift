import Foundation
import GRDB
import ALDomain

public protocol DocumentRepository: Sendable {
    func fetchDocuments(workspaceId: WorkspaceID) throws -> [Document]
    func fetchDocument(id: DocumentID) throws -> Document?
    func fetchDocument(workspaceId: WorkspaceID, blobHash: String) throws -> Document?
    func fetchDocuments(ids: [DocumentID]) throws -> [Document]
    func fetchDocuments(entityId: LegalEntityID) throws -> [Document]
    func saveDocument(_ document: Document) throws
}

public final class GRDBDocumentRepository: DocumentRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchDocuments(workspaceId: WorkspaceID) throws -> [Document] {
        try dbPool.read { db in
            try Document
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("rowid").desc)
                .fetchAll(db)
        }
    }

    public func fetchDocument(id: DocumentID) throws -> Document? {
        try dbPool.read { db in
            try Document.fetchOne(db, key: id)
        }
    }

    public func fetchDocument(workspaceId: WorkspaceID, blobHash: String) throws -> Document? {
        try dbPool.read { db in
            try Document
                .filter(Column("workspaceId") == workspaceId && Column("blobHash") == blobHash)
                .fetchOne(db)
        }
    }

    public func fetchDocuments(entityId: LegalEntityID) throws -> [Document] {
        try dbPool.read { db in
            try Document
                .filter(Column("entityId") == entityId)
                .order(Column("rowid").desc)
                .fetchAll(db)
        }
    }

    public func fetchDocuments(ids: [DocumentID]) throws -> [Document] {
        guard ids.isEmpty == false else {
            return []
        }
        return try dbPool.read { db in
            try Document.filter(ids.contains(Column("id"))).fetchAll(db)
        }
    }

    public func saveDocument(_ document: Document) throws {
        try dbPool.write { db in
            try document.save(db)
        }
    }
}
