import Foundation
import ALDomain
import ALWorkspace

public struct WorkspaceChooserSnapshot: Sendable {
    public struct OnboardingItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let detail: String
        public let systemImage: String

        public init(id: String, title: String, detail: String, systemImage: String) {
            self.id = id
            self.title = title
            self.detail = detail
            self.systemImage = systemImage
        }
    }

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
    public let onboardingItems: [OnboardingItem]
    public let recentWorkspaces: [RecentWorkspace]

    public init(
        title: String,
        tagline: String,
        trustLine: String,
        onboardingItems: [OnboardingItem],
        recentWorkspaces: [RecentWorkspace]
    ) {
        self.title = title
        self.tagline = tagline
        self.trustLine = trustLine
        self.onboardingItems = onboardingItems
        self.recentWorkspaces = recentWorkspaces
    }
}
