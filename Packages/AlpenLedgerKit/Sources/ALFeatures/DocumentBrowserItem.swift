import Foundation
import ALDesignSystem
import ALDomain

public struct DocumentBrowserItem: Identifiable, Sendable {
    public let id: DocumentID
    public let title: String
    public let subtitle: String
    public let typeLabel: String
    public let dateLabel: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let systemImage: String
    public let issueDate: Date?
    public let mediaType: String

    public init(
        id: DocumentID,
        title: String,
        subtitle: String,
        typeLabel: String,
        dateLabel: String,
        statusText: String,
        tone: StatusBadge.Tone,
        systemImage: String,
        issueDate: Date?,
        mediaType: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.typeLabel = typeLabel
        self.dateLabel = dateLabel
        self.statusText = statusText
        self.tone = tone
        self.systemImage = systemImage
        self.issueDate = issueDate
        self.mediaType = mediaType
    }
}
