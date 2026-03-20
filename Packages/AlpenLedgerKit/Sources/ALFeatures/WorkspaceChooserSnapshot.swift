import Foundation
import ALDomain
import ALWorkspace

public struct WorkspaceChooserSnapshot: Sendable {
    public struct RecentWorkspace: Identifiable, Sendable {
        public let reference: RecentWorkspaceReference
        public let title: String
        public let lastOpenedText: String

        public init(reference: RecentWorkspaceReference, title: String, lastOpenedText: String) {
            self.reference = reference
            self.title = title
            self.lastOpenedText = lastOpenedText
        }

        public var id: WorkspaceID {
            reference.workspaceId
        }
    }

    public let title: String
    public let tagline: String
    public let trustLine: String
    public let recentWorkspaces: [RecentWorkspace]

    public init(
        title: String,
        tagline: String,
        trustLine: String,
        recentWorkspaces: [RecentWorkspace]
    ) {
        self.title = title
        self.tagline = tagline
        self.trustLine = trustLine
        self.recentWorkspaces = recentWorkspaces
    }
}
