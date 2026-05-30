import Foundation
import ALDesignSystem
import ALDomain

public enum TaxStudioSelection: Hashable, Sendable {
    case issue(IssueID)
    case requirement(RequirementID)
    case fact(TaxFactID)
    case missingConcept(String)
    case vatPeriod(VATPeriodID)
    case vatIssue(String)
    case filingPackage(FilingPackageID)
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

public struct TaxStudioVATIssueRowModel: Identifiable, Sendable {
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

public struct TaxStudioVATPeriodModel: Identifiable, Sendable {
    public let id: VATPeriodID
    public let selection: TaxStudioSelection
    public let title: String
    public let subtitle: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let outputTaxText: String
    public let inputTaxText: String
    public let payableTaxText: String
    public let issueSummary: String
    public let issues: [TaxStudioVATIssueRowModel]

    public init(
        id: VATPeriodID,
        selection: TaxStudioSelection,
        title: String,
        subtitle: String,
        statusText: String,
        tone: StatusBadge.Tone,
        outputTaxText: String,
        inputTaxText: String,
        payableTaxText: String,
        issueSummary: String,
        issues: [TaxStudioVATIssueRowModel]
    ) {
        self.id = id
        self.selection = selection
        self.title = title
        self.subtitle = subtitle
        self.statusText = statusText
        self.tone = tone
        self.outputTaxText = outputTaxText
        self.inputTaxText = inputTaxText
        self.payableTaxText = payableTaxText
        self.issueSummary = issueSummary
        self.issues = issues
    }
}

public struct TaxStudioFilingPackageModel: Identifiable, Sendable {
    public let id: FilingPackageID
    public let selection: TaxStudioSelection
    public let title: String
    public let subtitle: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let exportFormatText: String
    public let generatedAtText: String
    public let finalizationText: String
    public let filingBoundaryText: String
    public let systemImage: String

    public init(
        id: FilingPackageID,
        selection: TaxStudioSelection,
        title: String,
        subtitle: String,
        statusText: String,
        tone: StatusBadge.Tone,
        exportFormatText: String,
        generatedAtText: String,
        finalizationText: String,
        filingBoundaryText: String,
        systemImage: String
    ) {
        self.id = id
        self.selection = selection
        self.title = title
        self.subtitle = subtitle
        self.statusText = statusText
        self.tone = tone
        self.exportFormatText = exportFormatText
        self.generatedAtText = generatedAtText
        self.finalizationText = finalizationText
        self.filingBoundaryText = filingBoundaryText
        self.systemImage = systemImage
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

public struct TaxPeriodStatusModel: Sendable {
    public let title: String
    public let detail: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let canLock: Bool
    public let canUnlock: Bool

    public init(
        title: String,
        detail: String,
        statusText: String,
        tone: StatusBadge.Tone,
        canLock: Bool,
        canUnlock: Bool
    ) {
        self.title = title
        self.detail = detail
        self.statusText = statusText
        self.tone = tone
        self.canLock = canLock
        self.canUnlock = canUnlock
    }
}

public struct TaxStudioSnapshot: Sendable {
    public let readinessTitle: String
    public let readinessSummary: String
    public let readinessTone: StatusBadge.Tone
    public let periodStatus: TaxPeriodStatusModel?
    public let vatPeriods: [TaxStudioVATPeriodModel]
    public let filingPackages: [TaxStudioFilingPackageModel]
    public let checklistItems: [TaxChecklistItem]
    public let factCategories: [TaxFactCategoryModel]
    public let inspector: TaxInspectorModel?

    public init(
        readinessTitle: String,
        readinessSummary: String,
        readinessTone: StatusBadge.Tone,
        periodStatus: TaxPeriodStatusModel?,
        vatPeriods: [TaxStudioVATPeriodModel],
        filingPackages: [TaxStudioFilingPackageModel],
        checklistItems: [TaxChecklistItem],
        factCategories: [TaxFactCategoryModel],
        inspector: TaxInspectorModel?
    ) {
        self.readinessTitle = readinessTitle
        self.readinessSummary = readinessSummary
        self.readinessTone = readinessTone
        self.periodStatus = periodStatus
        self.vatPeriods = vatPeriods
        self.filingPackages = filingPackages
        self.checklistItems = checklistItems
        self.factCategories = factCategories
        self.inspector = inspector
    }
}
