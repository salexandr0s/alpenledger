import Foundation
import ALDesignSystem
import ALDomain

public enum TaxStudioSelection: Hashable, Sendable {
    case issue(IssueID)
    case requirement(RequirementID)
    case fact(TaxFactID)
    case missingConcept(String)
}

public struct TaxChecklistItem: Identifiable, Sendable {
    public let id: String
    public let selection: TaxStudioSelection
    public let title: String
    public let subtitle: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let systemImage: String

    public init(
        id: String,
        selection: TaxStudioSelection,
        title: String,
        subtitle: String,
        statusText: String,
        tone: StatusBadge.Tone,
        systemImage: String
    ) {
        self.id = id
        self.selection = selection
        self.title = title
        self.subtitle = subtitle
        self.statusText = statusText
        self.tone = tone
        self.systemImage = systemImage
    }
}

public struct TaxFactRowModel: Identifiable, Sendable {
    public let id: TaxFactID
    public let selection: TaxStudioSelection
    public let title: String
    public let value: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let systemImage: String

    public init(
        id: TaxFactID,
        selection: TaxStudioSelection,
        title: String,
        value: String,
        statusText: String,
        tone: StatusBadge.Tone,
        systemImage: String
    ) {
        self.id = id
        self.selection = selection
        self.title = title
        self.value = value
        self.statusText = statusText
        self.tone = tone
        self.systemImage = systemImage
    }
}

public struct TaxFactCategoryModel: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let completionText: String
    public let items: [TaxFactRowModel]

    public init(id: String, title: String, completionText: String, items: [TaxFactRowModel]) {
        self.id = id
        self.title = title
        self.completionText = completionText
        self.items = items
    }
}

public struct TaxInspectorDetail: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let value: String

    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct TaxInspectorModel: Sendable {
    public let title: String
    public let subtitle: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let details: [TaxInspectorDetail]
    public let evidence: [DocumentReferenceRowModel]

    public init(
        title: String,
        subtitle: String,
        statusText: String,
        tone: StatusBadge.Tone,
        details: [TaxInspectorDetail],
        evidence: [DocumentReferenceRowModel]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.statusText = statusText
        self.tone = tone
        self.details = details
        self.evidence = evidence
    }
}

public struct TaxStudioSnapshot: Sendable {
    public let readinessTitle: String
    public let readinessSummary: String
    public let readinessTone: StatusBadge.Tone
    public let checklistItems: [TaxChecklistItem]
    public let factCategories: [TaxFactCategoryModel]
    public let inspector: TaxInspectorModel?

    public init(
        readinessTitle: String,
        readinessSummary: String,
        readinessTone: StatusBadge.Tone,
        checklistItems: [TaxChecklistItem],
        factCategories: [TaxFactCategoryModel],
        inspector: TaxInspectorModel?
    ) {
        self.readinessTitle = readinessTitle
        self.readinessSummary = readinessSummary
        self.readinessTone = readinessTone
        self.checklistItems = checklistItems
        self.factCategories = factCategories
        self.inspector = inspector
    }
}
