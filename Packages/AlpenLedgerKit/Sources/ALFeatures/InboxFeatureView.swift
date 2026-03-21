import SwiftUI
import ALDesignSystem
import ALDomain

public enum InboxSelection: Hashable, Sendable {
    case importJob(ImportJobID)
    case proposal(AgentProposalID)
    case issue(IssueID)
}

@MainActor
public struct InboxFeatureView: View {
    @Binding private var selection: InboxSelection?
    @State private var selectedTab: InboxTab = .issues
    @State private var searchQuery = ""

    private let snapshot: InboxSnapshot
    private let performAction: (InboxAction) -> Void

    public init(
        snapshot: InboxSnapshot,
        selection: Binding<InboxSelection?>,
        performAction: @escaping (InboxAction) -> Void
    ) {
        self.snapshot = snapshot
        _selection = selection
        self.performAction = performAction
    }

    public var body: some View {
        listPane
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Picker("Inbox Tab", selection: $selectedTab) {
                        ForEach(snapshot.tabs) { tab in
                            Text("\(tab.tab.title) \(tab.count)")
                                .tag(tab.tab)
                                .accessibilityIdentifier("inbox.tab.\(tab.tab.rawValue)")
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .inspector(isPresented: .constant(true)) {
                inspectorContent
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 360)
            }
            .searchable(text: $searchQuery, placement: .toolbar, prompt: "Search inbox")
            .navigationTitle("Inbox")
            .navigationSubtitle("Resolve issues, proposals, and imports")
            .onChange(of: selection) { _, newValue in
                if let newValue {
                    selectedTab = tab(for: newValue)
                }
            }
    }

    private var listPane: some View {
        let rows = filteredRows
        return List(selection: $selection) {
            if rows.isEmpty {
                Text("No \(selectedTab.title.lowercased()) match the current filter.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groupedRows, id: \.key) { groupTitle, groupRows in
                    Section(groupTitle) {
                        ForEach(groupRows) { row in
                            HStack(alignment: .top, spacing: AppTheme.spacingS) {
                                WorkItemRow(
                                    title: row.title,
                                    subtitle: row.subtitle,
                                    systemImage: row.systemImage,
                                    statusTitle: row.statusText,
                                    tone: row.tone
                                )

                                Text(row.meta)
                                    .font(AppTheme.metaFont)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(row.selection)
                            .accessibilityIdentifier("inbox.\(row.tab.rawValue.dropLast()).\(accessibilitySlug(row.title))")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("inbox.list")
    }

    private var inspectorContent: some View {
        Group {
            if let inspector = snapshot.inspector {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                        GroupBox(inspector.title) {
                            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                StatusBadge(inspector.statusText, tone: inspector.tone)

                                Text(inspector.description)
                                    .font(AppTheme.pageSubtitleFont)
                                    .foregroundStyle(AppTheme.subduedForegroundColor)

                                ForEach(inspector.details) { detail in
                                    InspectorSectionRow(detail.label, value: detail.value)
                                }
                            }
                        }

                        if inspector.actions.isEmpty == false {
                            GroupBox("Actions") {
                                HStack(spacing: AppTheme.spacingS) {
                                    ForEach(inspector.actions) { action in
                                        switch action.role {
                                        case .primary:
                                            Button(action.title) {
                                                performAction(action.action)
                                            }
                                            .buttonStyle(.borderedProminent)
                                        case .secondary:
                                            Button(action.title) {
                                                performAction(action.action)
                                            }
                                            .buttonStyle(.bordered)
                                        case .destructive:
                                            Button(action.title, role: .destructive) {
                                                performAction(action.action)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(AppTheme.contentPadding)
                }
                .accessibilityIdentifier(inspectorAccessibilityIdentifier)
            } else {
                Text("Select an issue, proposal, or import to inspect it.")
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var filteredRows: [InboxRowModel] {
        snapshot.rows.filter { row in
            row.tab == selectedTab &&
            (searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
             row.searchText.localizedCaseInsensitiveContains(searchQuery))
        }
    }

    private var groupedRows: [(key: String, value: [InboxRowModel])] {
        Dictionary(grouping: filteredRows, by: \.groupTitle)
            .sorted { $0.key < $1.key }
    }

    private func tab(for selection: InboxSelection) -> InboxTab {
        switch selection {
        case .issue:
            return .issues
        case .proposal:
            return .proposals
        case .importJob:
            return .imports
        }
    }

    private var inspectorAccessibilityIdentifier: String {
        switch selection {
        case .issue:
            return "inbox.inspector.issue"
        case .proposal:
            return "inbox.inspector.proposal"
        case .importJob:
            return "inbox.inspector.importJob"
        case nil:
            return "inbox.inspector.empty"
        }
    }
}
