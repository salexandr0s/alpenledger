import Foundation
import ALDomain

public struct DocumentBinaryRef: Hashable, Sendable {
    public let documentId: DocumentID
    public let originalFilename: String
    public let fileURL: URL

    public init(documentId: DocumentID, originalFilename: String, fileURL: URL) {
        self.documentId = documentId
        self.originalFilename = originalFilename
        self.fileURL = fileURL
    }
}
