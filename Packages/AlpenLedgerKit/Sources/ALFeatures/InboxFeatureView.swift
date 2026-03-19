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
            HStack(spacing: AppTheme.spacingM) {
                summaryCard("\(importJobs.count) import jobs", tint: .blue, identifier: "inbox.count.importJobs")
                summaryCard("\(proposals.filter { $0.status == .pending }.count) pending proposals", tint: .orange, identifier: "inbox.count.proposals")
                summaryCard("\(issues.filter { $0.status == .open }.count) open issues", tint: .red, identifier: "inbox.count.issues")
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingM)

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
                .frame(minWidth: 360)

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Text("Inspector")
                        .font(.title3.weight(.semibold))

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
                .padding(AppTheme.spacingM)
                .frame(minWidth: 320)
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

    @ViewBuilder
    private func summaryCard(_ label: String, tint: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusBadge(label, tint: tint, accessibilityIdentifier: identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacingM)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}
