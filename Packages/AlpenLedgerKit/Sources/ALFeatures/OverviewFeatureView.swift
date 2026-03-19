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
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppTheme.spacingXL) {
                    primaryColumn
                        .frame(maxWidth: 680, alignment: .leading)

                    secondaryColumn
                        .frame(maxWidth: 420, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                    primaryColumn
                    secondaryColumn
                }
            }
            .padding(AppTheme.contentPadding)
            .transition(AppTheme.chromeTransition(reduceMotion: reduceMotion))
        }
    }

    private var primaryColumn: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingL) {
            PaneHeader(snapshot.workspaceName, subtitle: snapshot.workspaceSubtitle)

            InspectorPane("Workspace Health", subtitle: "A compact view of the current workspace state.") {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 180), spacing: AppTheme.spacingM),
                        GridItem(.flexible(minimum: 180), spacing: AppTheme.spacingM),
                    ],
                    spacing: AppTheme.spacingM
                ) {
                    ForEach(snapshot.healthItems) { item in
                        SummaryTile(
                            item.title,
                            value: item.value,
                            subtitle: item.subtitle,
                            tone: item.tone,
                            systemImage: item.systemImage
                        )
                    }
                }
            }

            InspectorPane("Next Actions", subtitle: "Follow the highest-signal tasks before diving into detail.") {
                if snapshot.nextSteps.isEmpty {
                    ContentUnavailableView("No Immediate Actions", systemImage: "checkmark.circle")
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        ForEach(snapshot.nextSteps) { step in
                            Button(action: {
                                performAction(step.action)
                            }) {
                                HStack(alignment: .top, spacing: AppTheme.spacingS) {
                                    Image(systemName: step.systemImage)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)

                                    VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                                        Text(step.title)
                                            .foregroundStyle(.primary)

                                        Text(step.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.subduedForegroundColor)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            InspectorPane("Recent Imports", subtitle: "The newest statement and document intake work.") {
                if snapshot.recentImports.isEmpty {
                    ContentUnavailableView("No Imports Yet", systemImage: "tray")
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        ForEach(snapshot.recentImports) { item in
                            HStack(alignment: .top, spacing: AppTheme.spacingM) {
                                SourceListRow(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    systemImage: "tray.and.arrow.down"
                                )

                                Spacer()

                                StatusBadge(item.detail, tone: item.tone)
                            }
                        }
                    }
                }
            }
        }
    }

    private var secondaryColumn: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingL) {
            InspectorPane("Review Queue", subtitle: "Open proposals and issues that still need attention.") {
                if snapshot.reviewQueue.isEmpty {
                    ContentUnavailableView("Review Queue Clear", systemImage: "checkmark.seal")
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        ForEach(snapshot.reviewQueue) { item in
                            HStack(alignment: .top, spacing: AppTheme.spacingS) {
                                SourceListRow(
                                    title: item.title,
                                    subtitle: item.subtitle,
                                    systemImage: item.tone == .critical ? "exclamationmark.octagon" : "list.bullet.rectangle"
                                )

                                Spacer()

                                StatusBadge(item.toneLabel, tone: item.tone)
                            }
                        }
                    }
                }
            }

            InspectorPane("Tax Readiness", subtitle: snapshot.taxReadiness.detail) {
                VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                    HStack {
                        StatusBadge(snapshot.taxReadiness.summary, tone: snapshot.taxReadiness.tone)
                        Spacer()
                        Button("Open Tax Studio", action: {
                            performAction(.openTaxStudio)
                        })
                        .buttonStyle(.bordered)
                    }

                    Text(snapshot.taxReadiness.title)
                        .font(.body.weight(.medium))

                    if snapshot.taxReadiness.missingFacts.isEmpty == false {
                        VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                            Text("Missing Facts")
                                .font(.headline)

                            ForEach(snapshot.taxReadiness.missingFacts, id: \.self) { fact in
                                Label(fact, systemImage: "circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.subduedForegroundColor)
                            }
                        }
                    }
                }
            }

            InspectorPane("Workspace Snapshot", subtitle: "A concise inventory of entities, accounts, documents, and facts.") {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 150), spacing: AppTheme.spacingM),
                        GridItem(.flexible(minimum: 150), spacing: AppTheme.spacingM),
                    ],
                    spacing: AppTheme.spacingM
                ) {
                    ForEach(snapshot.workspaceFacts) { fact in
                        SummaryTile(
                            fact.title,
                            value: fact.value,
                            subtitle: fact.subtitle,
                            systemImage: fact.systemImage
                        )
                    }
                }
            }

            InspectorPane("Sample Data", subtitle: "Keep the accepted sample import path available without making it the focus of the dashboard.") {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Button("Import Sample CSV", systemImage: "tablecells", action: {
                        performAction(.importSampleCSV)
                    })
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("overview.importSampleCSV")

                    Button("Import Sample PDF", systemImage: "doc.richtext", action: {
                        performAction(.importSampleDocument)
                    })
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("overview.importSamplePDF")

                    Button("Open Inbox", systemImage: "tray.full", action: {
                        performAction(.openInbox)
                    })
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("overview.openInbox")
                }
            }
        }
    }
}

private extension OverviewSnapshot.ReviewQueueItem {
    var toneLabel: String {
        switch tone {
        case .critical:
            return "Blocking"
        case .warning:
            return "Open"
        case .info:
            return "Pending"
        case .success:
            return "Ready"
        default:
            return "Review"
        }
    }
}
