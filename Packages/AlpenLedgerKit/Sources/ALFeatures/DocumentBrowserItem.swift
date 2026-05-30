import Foundation
import ALDesignSystem
import ALDomain

public struct DocumentBrowserItem: Identifiable, Sendable {
    public let id: DocumentID
    public let title: String
    public let subtitle: String
    public let documentType: DocumentType
    public let typeLabel: String
    public let dateLabel: String
    public let statusText: String
    public let metadataStatus: MetadataStatus
    public let tone: StatusBadge.Tone
    public let systemImage: String
    public let issueDate: Date?
    public let mediaType: String
    public let isArchived: Bool
    public let archivedAtText: String?
    public let archivedBy: String?
    public let archiveReason: String?

    public init(
        id: DocumentID,
        title: String,
        subtitle: String,
        documentType: DocumentType,
        typeLabel: String,
        dateLabel: String,
        statusText: String,
        metadataStatus: MetadataStatus,
        tone: StatusBadge.Tone,
        systemImage: String,
        issueDate: Date?,
        mediaType: String,
        isArchived: Bool = false,
        archivedAtText: String? = nil,
        archivedBy: String? = nil,
        archiveReason: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.documentType = documentType
        self.typeLabel = typeLabel
        self.dateLabel = dateLabel
        self.statusText = statusText
        self.metadataStatus = metadataStatus
        self.tone = tone
        self.systemImage = systemImage
        self.issueDate = issueDate
        self.mediaType = mediaType
        self.isArchived = isArchived
        self.archivedAtText = archivedAtText
        self.archivedBy = archivedBy
        self.archiveReason = archiveReason
    }
}
