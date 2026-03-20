import Foundation
import ALDesignSystem

public struct OverviewSnapshot: Sendable {
    public struct MetricItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let value: String
        public let subtitle: String
        public let tone: StatusBadge.Tone
        public let systemImage: String

        public init(
            id: String,
            title: String,
            value: String,
            subtitle: String,
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

    public struct ActionItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let buttonTitle: String
        public let systemImage: String
        public let action: OverviewAction

        public init(
            id: String,
            title: String,
            subtitle: String,
            buttonTitle: String,
            systemImage: String,
            action: OverviewAction
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.buttonTitle = buttonTitle
            self.systemImage = systemImage
            self.action = action
        }
    }

    public struct AttentionItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let statusText: String
        public let tone: StatusBadge.Tone
        public let systemImage: String
        public let action: OverviewAction

        public init(
            id: String,
            title: String,
            subtitle: String,
            statusText: String,
            tone: StatusBadge.Tone,
            systemImage: String,
            action: OverviewAction
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.statusText = statusText
            self.tone = tone
            self.systemImage = systemImage
            self.action = action
        }
    }

    public struct RecentActivityItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let statusText: String
        public let tone: StatusBadge.Tone

        public init(
            id: String,
            title: String,
            subtitle: String,
            statusText: String,
            tone: StatusBadge.Tone
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.statusText = statusText
            self.tone = tone
        }
    }

    public let workspaceName: String
    public let workspaceSubtitle: String
    public let metrics: [MetricItem]
    public let priorityAction: ActionItem?
    public let secondaryActions: [ActionItem]
    public let attentionItems: [AttentionItem]
    public let recentActivityItems: [RecentActivityItem]
    public let recentActivityEmptyTitle: String
    public let recentActivityActionTitle: String
    public let recentActivityAction: OverviewAction?

    public init(
        workspaceName: String,
        workspaceSubtitle: String,
        metrics: [MetricItem],
        priorityAction: ActionItem?,
        secondaryActions: [ActionItem],
        attentionItems: [AttentionItem],
        recentActivityItems: [RecentActivityItem],
        recentActivityEmptyTitle: String,
        recentActivityActionTitle: String,
        recentActivityAction: OverviewAction?
    ) {
        self.workspaceName = workspaceName
        self.workspaceSubtitle = workspaceSubtitle
        self.metrics = metrics
        self.priorityAction = priorityAction
        self.secondaryActions = secondaryActions
        self.attentionItems = attentionItems
        self.recentActivityItems = recentActivityItems
        self.recentActivityEmptyTitle = recentActivityEmptyTitle
        self.recentActivityActionTitle = recentActivityActionTitle
        self.recentActivityAction = recentActivityAction
    }
}
