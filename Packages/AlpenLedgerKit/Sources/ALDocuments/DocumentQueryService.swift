import Foundation
import ALDomain
import ALStorage

public final class DocumentQueryService: Sendable {
    private let storage: WorkspaceStorage

    public init(storage: WorkspaceStorage) {
        self.storage = storage
    }

    public func listDocuments(entityId: LegalEntityID) throws -> [Document] {
        try storage.documentRepository.fetchDocuments(entityId: entityId)
    }

    public func listArchivedDocuments(entityId: LegalEntityID) throws -> [Document] {
        try storage.documentRepository.fetchDocuments(entityId: entityId, status: .archived)
    }

    public func listArchivedDocuments() throws -> [Document] {
        try storage.documentRepository.fetchDocuments(workspaceId: storage.manifest.workspace.id, status: .archived)
    }

    public func listDocuments(query: String = "") throws -> [Document] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            return try storage.documentRepository.fetchDocuments(workspaceId: storage.manifest.workspace.id)
        }

        let ids = try storage.searchIndex.searchDocumentIDs(workspaceId: storage.manifest.workspace.id, query: trimmedQuery)
        if ids.isEmpty {
            return []
        }
        let documents = try storage.documentRepository.fetchDocuments(ids: ids)
        let lookup = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
        return ids.compactMap { lookup[$0] }
    }
}
