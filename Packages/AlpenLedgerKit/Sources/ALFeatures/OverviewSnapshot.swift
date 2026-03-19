import Foundation
import ALDesignSystem

public struct OverviewSnapshot: Sendable {
    public struct HealthItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let value: String
        public let subtitle: String?
        public let tone: StatusBadge.Tone
        public let systemImage: String

        public init(
            id: String,
            title: String,
            value: String,
            subtitle: String? = nil,
            tone: StatusBadge.Tone,
            systemImage: String
        ) {
            self.id = id
            self.title = title
            self.value = value
            self.subtitle = subtitle
            self.tone = tone
            self.systemImage = systemImage
        }
    }

    public struct NextStep: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let systemImage: String
        public let action: OverviewAction

        public init(
            id: String,
            title: String,
            subtitle: String,
            systemImage: String,
            action: OverviewAction
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.systemImage = systemImage
            self.action = action
        }
    }

    public struct RecentImportItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let detail: String
        public let tone: StatusBadge.Tone

        public init(
            id: String,
            title: String,
            subtitle: String,
            detail: String,
            tone: StatusBadge.Tone
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.detail = detail
            self.tone = tone
        }
    }

    public struct ReviewQueueItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let tone: StatusBadge.Tone

        public init(
            id: String,
            title: String,
            subtitle: String,
            tone: StatusBadge.Tone
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.tone = tone
        }
    }

    public struct TaxReadinessCard: Sendable {
        public let title: String
        public let summary: String
        public let detail: String
        public let tone: StatusBadge.Tone
        public let missingFacts: [String]

        public init(
            title: String,
            summary: String,
            detail: String,
            tone: StatusBadge.Tone,
            missingFacts: [String]
        ) {
            self.title = title
            self.summary = summary
            self.detail = detail
            self.tone = tone
            self.missingFacts = missingFacts
        }
    }

    public struct WorkspaceFact: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let value: String
        public let subtitle: String?
        public let systemImage: String

        public init(
            id: String,
            title: String,
            value: String,
            subtitle: String? = nil,
            systemImage: String
        ) {
            self.id = id
            self.title = title
            self.value = value
            self.subtitle = subtitle
            self.systemImage = systemImage
        }
    }

    public let workspaceName: String
    public let workspaceSubtitle: String
    public let healthItems: [HealthItem]
    public let nextSteps: [NextStep]
    public let recentImports: [RecentImportItem]
    public let reviewQueue: [ReviewQueueItem]
    public let taxReadiness: TaxReadinessCard
    public let workspaceFacts: [WorkspaceFact]

    public init(
        workspaceName: String,
        workspaceSubtitle: String,
        healthItems: [HealthItem],
        nextSteps: [NextStep],
        recentImports: [RecentImportItem],
        reviewQueue: [ReviewQueueItem],
        taxReadiness: TaxReadinessCard,
        workspaceFacts: [WorkspaceFact]
    ) {
        self.workspaceName = workspaceName
        self.workspaceSubtitle = workspaceSubtitle
        self.healthItems = healthItems
        self.nextSteps = nextSteps
        self.recentImports = recentImports
        self.reviewQueue = reviewQueue
        self.taxReadiness = taxReadiness
        self.workspaceFacts = workspaceFacts
    }
}
