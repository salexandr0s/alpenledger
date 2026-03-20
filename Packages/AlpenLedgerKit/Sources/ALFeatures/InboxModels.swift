import Foundation
import ALDesignSystem
import ALDomain

public enum InboxTab: String, CaseIterable, Identifiable, Sendable {
    case issues
    case proposals
    case imports

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .issues:
            return "Issues"
        case .proposals:
            return "Proposals"
        case .imports:
            return "Imports"
        }
    }
}

public enum InboxAction: Hashable, Sendable {
    case resolveIssue(IssueID)
    case dismissIssue(IssueID)
    case importStatement(FinancialAccountID?)
    case linkDocument(TransactionID)
    case linkTransaction(DocumentID)
    case openProposalTarget(ObjectRef)
    case rejectProposal(AgentProposalID)
}

public enum InboxInspectorActionRole: Sendable {
    case primary
    case secondary
    case destructive
}

public struct InboxRowModel: Identifiable, Sendable {
    public let id: String
    public let selection: InboxSelection
    public let tab: InboxTab
    public let groupTitle: String
    public let title: String
    public let subtitle: String
    public let meta: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let systemImage: String
    public let searchText: String

    public init(
        id: String,
        selection: InboxSelection,
        tab: InboxTab,
        groupTitle: String,
        title: String,
        subtitle: String,
        meta: String,
        statusText: String,
        tone: StatusBadge.Tone,
        systemImage: String,
        searchText: String
    ) {
        self.id = id
        self.selection = selection
        self.tab = tab
        self.groupTitle = groupTitle
        self.title = title
        self.subtitle = subtitle
        self.meta = meta
        self.statusText = statusText
        self.tone = tone
        self.systemImage = systemImage
        self.searchText = searchText
    }
}

public struct InboxInspectorDetail: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let value: String

    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct InboxInspectorAction: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let role: InboxInspectorActionRole
    public let action: InboxAction

    public init(id: String, title: String, role: InboxInspectorActionRole, action: InboxAction) {
        self.id = id
        self.title = title
        self.role = role
        self.action = action
    }
}

public struct InboxInspectorModel: Sendable {
    public let title: String
    public let subtitle: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let description: String
    public let details: [InboxInspectorDetail]
    public let actions: [InboxInspectorAction]

    public init(
        title: String,
        subtitle: String,
        statusText: String,
        tone: StatusBadge.Tone,
        description: String,
        details: [InboxInspectorDetail],
        actions: [InboxInspectorAction]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusText = statusText
        self.tone = tone
        self.description = description
        self.details = details
        self.actions = actions
    }
}

public struct InboxTabSummary: Identifiable, Sendable {
    public let tab: InboxTab
    public let count: Int

    public init(tab: InboxTab, count: Int) {
        self.tab = tab
        self.count = count
    }

    public var id: String {
        tab.id
    }
}

public struct InboxSnapshot: Sendable {
    public let tabs: [InboxTabSummary]
    public let rows: [InboxRowModel]
    public let inspector: InboxInspectorModel?

    public init(tabs: [InboxTabSummary], rows: [InboxRowModel], inspector: InboxInspectorModel?) {
        self.tabs = tabs
        self.rows = rows
        self.inspector = inspector
    }
}
