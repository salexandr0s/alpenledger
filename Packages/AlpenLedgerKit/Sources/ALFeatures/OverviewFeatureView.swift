import SwiftUI
import ALDesignSystem

public struct OverviewFeatureView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let snapshot: OverviewSnapshot
    private let performAction: (OverviewAction) -> Void

    public init(
        snapshot: OverviewSnapshot,
        performAction: @escaping (OverviewAction) -> Void
    ) {
        self.snapshot = snapshot
        self.performAction = performAction
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                PaneHeader(
                    snapshot.workspaceName,
                    subtitle: snapshot.workspaceSubtitle,
                    style: .page
                )

                metricsRow

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppTheme.spacingL) {
                        priorityActionCard
                            .frame(maxWidth: 760, alignment: .leading)

                        attentionCard
                            .frame(maxWidth: 420, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                        priorityActionCard
                        attentionCard
                    }
                }

                recentActivityCard
            }
            .padding(AppTheme.contentPadding)
            .transition(AppTheme.chromeTransition(reduceMotion: reduceMotion))
        }
    }

    private var metricsRow: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: AppTheme.spacingM)],
            spacing: AppTheme.spacingM
        ) {
            ForEach(snapshot.metrics) { metric in
                SummaryTile(
                    metric.title,
                    value: metric.value,
                    subtitle: metric.subtitle,
                    tone: metric.tone,
                    style: .compact,
                    subtitlePresentation: .secondary,
                    systemImage: metric.systemImage
                )
            }
        }
    }

    private var priorityActionCard: some View {
        InspectorPane(
            "Next Action",
            subtitle: "The highest-value move for this workspace right now.",
            style: .card
        ) {
            if let action = snapshot.priorityAction {
                VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                    Label(action.title, systemImage: action.systemImage)
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(AppTheme.symbolRenderingMode)

                    Text(action.subtitle)
                        .font(AppTheme.pageSubtitleFont)
                        .foregroundStyle(AppTheme.subduedForegroundColor)

                    Button(action.buttonTitle) {
                        performAction(action.action)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("overview.primaryAction")

                    if snapshot.secondaryActions.isEmpty == false {
                        Divider()

                        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                            Text("Other Useful Next Steps")
                                .font(AppTheme.metaFont)
                                .foregroundStyle(.secondary)

                            ForEach(snapshot.secondaryActions) { secondary in
                                Button {
                                    performAction(secondary.action)
                                } label: {
                                    HStack(alignment: .top, spacing: AppTheme.spacingS) {
                                        NavigationListRow(
                                            title: secondary.title,
                                            subtitle: secondary.subtitle,
                                            systemImage: secondary.systemImage
                                        )

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                            .padding(.top, AppTheme.spacingXXS)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("overview.secondaryAction.\(accessibilitySlug(secondary.id))")
                            }
                        }
                    }
                }
            } else {
                PaneEmptyState(
                    "No immediate action",
                    subtitle: "This workspace is ready for the next import or review pass.",
                    systemImage: "checkmark.circle"
                )
            }
        }
    }

    private var attentionCard: some View {
        InspectorPane(
            "Needs Attention",
            subtitle: "The most important open items across inbox and tax readiness."
        ) {
            if snapshot.attentionItems.isEmpty {
                Text("Nothing needs attention.")
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    ForEach(snapshot.attentionItems) { item in
                        Button {
                            performAction(item.action)
                        } label: {
                            HStack(alignment: .top, spacing: AppTheme.spacingS) {
                                WorkItemRow(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    systemImage: item.systemImage,
                                    statusTitle: item.statusText,
                                    tone: item.tone
                                )

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, AppTheme.spacingXXS)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("overview.review.\(accessibilitySlug(item.id))")
                    }

                    Button("View all →") {
                        performAction(.openInbox(selection: nil))
                    }
                    .buttonStyle(.plain)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var recentActivityCard: some View {
        InspectorPane(
            "Recent Activity",
            subtitle: "Imports and intake work from this workspace."
        ) {
            if snapshot.recentActivityItems.isEmpty {
                HStack(spacing: AppTheme.spacingS) {
                    Text(snapshot.recentActivityEmptyTitle)
                        .font(AppTheme.metaFont)
                        .foregroundStyle(.secondary)

                    if let action = snapshot.recentActivityAction {
                        Button(snapshot.recentActivityActionTitle) {
                            performAction(action)
                        }
                        .buttonStyle(.plain)
                        .font(AppTheme.metaFont)
                        .foregroundStyle(Color.accentColor)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    ForEach(snapshot.recentActivityItems) { item in
                        WorkItemRow(
                            title: item.title,
                            subtitle: item.subtitle,
                            systemImage: "tray.and.arrow.down",
                            statusTitle: item.statusText,
                            tone: item.tone
                        )
                    }
                }
            }
        }
    }
}
