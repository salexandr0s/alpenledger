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
                            VStack(alignment: .leading, spacing: 4) {
                                Text(job.source)
                                Text("\(job.kind.rawValue) • \(job.status.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(InboxSelection.importJob(job.id))
                            .accessibilityIdentifier("inbox.importJob.\(accessibilitySlug("\(job.kind.rawValue)-\(job.source)"))")
                        }
                    }

                    Section("Proposals") {
                        ForEach(proposals, id: \.id) { proposal in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(proposal.summary)
                                Text("\(proposal.status.rawValue) • \(Int(proposal.confidence * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(InboxSelection.proposal(proposal.id))
                            .accessibilityIdentifier("inbox.proposal.\(accessibilitySlug(proposal.summary))")
                        }
                    }

                    Section("Issues") {
                        ForEach(issues, id: \.id) { issue in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(issue.summary)
                                Text("\(issue.severity.rawValue) • \(issue.status.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
                Text(importJob.source)
                Text("Kind: \(importJob.kind.rawValue)")
                Text("Status: \(importJob.status.rawValue)")
                Text("Parser: \(importJob.parserKey) \(importJob.parserVersion)")
                Text("Warnings: \(importJob.warningCount)")
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
                StatusBadge(proposal.status.rawValue.capitalized, tint: .orange)
                Text(proposal.summary)
                Text(proposal.rationale)
                    .foregroundStyle(.secondary)
                Text("Confidence: \(Int(proposal.confidence * 100))%")
                Text("Target: \(proposal.targetRef.stringValue)")
                    .font(.caption)
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
                StatusBadge(issue.severity.rawValue.capitalized, tint: issue.severity == .blocking ? .red : .orange)
                Text(issue.summary)
                Text("Status: \(issue.status.rawValue)")
                Text("Object: \(issue.objectRef.stringValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let relatedRef = issue.relatedRef {
                    Text("Related: \(relatedRef.stringValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("inbox.inspector.issue")
        } else {
            ContentUnavailableView("Issue Not Found", systemImage: "exclamationmark.triangle")
        }
    }

}
