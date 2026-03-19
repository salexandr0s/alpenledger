import SwiftUI
import ALDomain
import ALDesignSystem

public enum InboxSelection: Hashable, Sendable {
    case importJob(ImportJobID)
    case proposal(AgentProposalID)
    case issue(IssueID)
}

@MainActor
public struct InboxFeatureView: View {
    @Binding private var selection: InboxSelection?
    private let importJobs: [ImportJob]
    private let proposals: [AgentProposal]
    private let issues: [Issue]

    public init(
        selection: Binding<InboxSelection?>,
        importJobs: [ImportJob],
        proposals: [AgentProposal],
        issues: [Issue]
    ) {
        _selection = selection
        self.importJobs = importJobs
        self.proposals = proposals
        self.issues = issues
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            PaneHeader("Inbox", subtitle: "Review imports, proposals, and issues before they become filing surprises.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

            HStack(spacing: AppTheme.spacingM) {
                SummaryTile(
                    "Import Jobs",
                    value: importJobs.count.formatted(),
                    subtitle: "Active",
                    tone: .info,
                    systemImage: "tray.full",
                    accessibilityIdentifier: "inbox.count.importJobs",
                    accessibilityLabel: "\(importJobs.count) import jobs"
                )
                SummaryTile(
                    "Pending Proposals",
                    value: proposals.filter { $0.status == .pending }.count.formatted(),
                    subtitle: "Awaiting review",
                    tone: .warning,
                    systemImage: "wand.and.stars",
                    accessibilityIdentifier: "inbox.count.proposals",
                    accessibilityLabel: "\(proposals.filter { $0.status == .pending }.count) pending proposals"
                )
                SummaryTile(
                    "Open Issues",
                    value: issues.filter { $0.status == .open }.count.formatted(),
                    subtitle: "Need attention",
                    tone: .critical,
                    systemImage: "exclamationmark.bubble",
                    accessibilityIdentifier: "inbox.count.issues",
                    accessibilityLabel: "\(issues.filter { $0.status == .open }.count) open issues"
                )
            }
            .padding(.horizontal, AppTheme.contentPadding)

            HSplitView {
                List(selection: $selection) {
                    Section("Import Jobs") {
                        ForEach(importJobs, id: \.id) { job in
                            SourceListRow(
                                title: job.source,
                                subtitle: "\(job.kind.rawValue) • \(job.status.rawValue)",
                                systemImage: "tray.full"
                            )
                            .tag(InboxSelection.importJob(job.id))
                            .accessibilityIdentifier("inbox.importJob.\(accessibilitySlug("\(job.kind.rawValue)-\(job.source)"))")
                        }
                    }

                    Section("Proposals") {
                        ForEach(proposals, id: \.id) { proposal in
                            SourceListRow(
                                title: proposal.summary,
                                subtitle: "\(proposal.status.rawValue) • \(Int(proposal.confidence * 100))%",
                                systemImage: "wand.and.stars"
                            )
                            .tag(InboxSelection.proposal(proposal.id))
                            .accessibilityIdentifier("inbox.proposal.\(accessibilitySlug(proposal.summary))")
                        }
                    }

                    Section("Issues") {
                        ForEach(issues, id: \.id) { issue in
                            SourceListRow(
                                title: issue.summary,
                                subtitle: "\(issue.severity.rawValue) • \(issue.status.rawValue)",
                                systemImage: issue.severity == .blocking ? "exclamationmark.octagon" : "exclamationmark.triangle"
                            )
                            .tag(InboxSelection.issue(issue.id))
                            .accessibilityIdentifier("inbox.issue.\(accessibilitySlug(issue.summary))")
                        }
                    }
                }
                .accessibilityIdentifier("inbox.list")
                .frame(minWidth: 360, idealWidth: AppTheme.sidebarIdealWidth + 140)

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    PaneHeader("Inspector", subtitle: "Details for the currently selected inbox item.")

                    switch selection {
                    case let .importJob(importJobId):
                        importJobInspector(importJobId)
                    case let .proposal(proposalId):
                        proposalInspector(proposalId)
                    case let .issue(issueId):
                        issueInspector(issueId)
                    case nil:
                        ContentUnavailableView("No Inbox Item Selected", systemImage: "tray")
                    }

                    Spacer()
                }
                .padding(AppTheme.contentPadding)
                .frame(minWidth: AppTheme.inspectorIdealWidth)
            }
        }
    }

    @ViewBuilder
    private func importJobInspector(_ importJobId: ImportJobID) -> some View {
        if let importJob = importJobs.first(where: { $0.id == importJobId }) {
            InspectorPane("Import Job") {
                StatusBadge(importJob.status.rawValue.capitalized, tone: importJob.status == .completed ? .success : .warning)
                InspectorSectionRow("Source", value: importJob.source)
                InspectorSectionRow("Kind", value: importJob.kind.rawValue)
                InspectorSectionRow("Parser", value: "\(importJob.parserKey) \(importJob.parserVersion)")
                InspectorSectionRow("Warnings", value: importJob.warningCount.formatted())
            }
            .accessibilityIdentifier("inbox.inspector.importJob")
        } else {
            ContentUnavailableView("Import Job Not Found", systemImage: "exclamationmark.triangle")
        }
    }

    @ViewBuilder
    private func proposalInspector(_ proposalId: AgentProposalID) -> some View {
        if let proposal = proposals.first(where: { $0.id == proposalId }) {
            InspectorPane("Proposal") {
                StatusBadge(proposal.status.rawValue.capitalized, tone: .warning)
                InspectorSectionRow("Summary", value: proposal.summary)
                InspectorSectionRow("Confidence", value: "\(Int(proposal.confidence * 100))%")
                InspectorSectionRow("Target", value: proposal.targetRef.stringValue)
                Text(proposal.rationale)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("inbox.inspector.proposal")
        } else {
            ContentUnavailableView("Proposal Not Found", systemImage: "exclamationmark.triangle")
        }
    }

    @ViewBuilder
    private func issueInspector(_ issueId: IssueID) -> some View {
        if let issue = issues.first(where: { $0.id == issueId }) {
            InspectorPane("Issue") {
                StatusBadge(
                    issue.severity.rawValue.capitalized,
                    tone: issue.severity == .blocking ? .critical : .warning
                )
                InspectorSectionRow("Summary", value: issue.summary)
                InspectorSectionRow("Status", value: issue.status.rawValue.capitalized)
                InspectorSectionRow("Object", value: issue.objectRef.stringValue)
                if let relatedRef = issue.relatedRef {
                    InspectorSectionRow("Related", value: relatedRef.stringValue)
                }
            }
            .accessibilityIdentifier("inbox.inspector.issue")
        } else {
            ContentUnavailableView("Issue Not Found", systemImage: "exclamationmark.triangle")
        }
    }

}
