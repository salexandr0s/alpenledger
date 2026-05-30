import SwiftUI

public struct DesignSystemDemoCase: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let description: String

    public init(id: String, title: String, description: String) {
        self.id = id
        self.title = title
        self.description = description
    }
}

public enum DesignSystemPreviewCatalog {
    public static let cases: [DesignSystemDemoCase] = [
        DesignSystemDemoCase(
            id: "status-badges",
            title: "Status Badges",
            description: "Neutral, informational, success, warning, and critical states."
        ),
        DesignSystemDemoCase(
            id: "summary-tiles",
            title: "Summary Tiles",
            description: "Prominent and compact metric summaries with badge and secondary subtitles."
        ),
        DesignSystemDemoCase(
            id: "work-item-rows",
            title: "Work Item Rows",
            description: "Issue/task rows with symbols, details, and severity badges."
        ),
        DesignSystemDemoCase(
            id: "document-reference-rows",
            title: "Document Reference Rows",
            description: "Evidence rows for documents, transactions, and source refs."
        ),
        DesignSystemDemoCase(
            id: "inspector-pane",
            title: "Inspector Pane",
            description: "Grouped and card inspector sections with label/value rows."
        ),
        DesignSystemDemoCase(
            id: "empty-states",
            title: "Empty States",
            description: "Centered unavailable states with optional recovery actions."
        ),
        DesignSystemDemoCase(
            id: "document-preview",
            title: "Document Preview",
            description: "Preview fallback for missing or unsupported source documents."
        ),
    ]
}

public struct DesignSystemDemoGallery: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                PaneHeader(
                    "Design System",
                    subtitle: "Compile-checked component states for AlpenLedger review."
                )

                statusBadges
                summaryTiles
                workItemRows
                documentReferenceRows
                inspectorPane
                emptyStates
                documentPreview
            }
            .padding(AppTheme.contentPadding)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .background(AppTheme.windowChromeColor)
        .accessibilityIdentifier("designSystem.demoGallery")
    }

    private var statusBadges: some View {
        InspectorPane("Status Badges", subtitle: "All semantic tones", style: .card) {
            HStack(spacing: AppTheme.spacingS) {
                StatusBadge("Queued", tone: .neutral)
                StatusBadge("Info", tone: .info)
                StatusBadge("Ready", tone: .success)
                StatusBadge("Review", tone: .warning)
                StatusBadge("Blocked", tone: .critical)
            }
        }
        .accessibilityIdentifier("designSystem.demo.statusBadges")
    }

    private var summaryTiles: some View {
        InspectorPane("Summary Tiles", subtitle: "Metric and compact states", style: .card) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180), spacing: AppTheme.spacingM)],
                spacing: AppTheme.spacingM
            ) {
                SummaryTile(
                    "Open Issues",
                    value: "2",
                    subtitle: "Needs review",
                    tone: .warning,
                    subtitlePresentation: .badge,
                    systemImage: "exclamationmark.triangle"
                )
                SummaryTile(
                    "Documents",
                    value: "18",
                    subtitle: "Indexed",
                    tone: .success,
                    style: .compact,
                    systemImage: "doc.text.magnifyingglass"
                )
            }
        }
        .accessibilityIdentifier("designSystem.demo.summaryTiles")
    }

    private var workItemRows: some View {
        InspectorPane("Work Item Rows", subtitle: "Task and issue list states", style: .card) {
            VStack(spacing: AppTheme.spacingS) {
                WorkItemRow(
                    title: "Missing monthly statement",
                    subtitle: "Business Bank, January 2026",
                    systemImage: "calendar.badge.exclamationmark",
                    statusTitle: "Blocking",
                    tone: .critical
                )
                WorkItemRow(
                    title: "Review receipt match",
                    subtitle: "Amount and date line up with imported transaction.",
                    systemImage: "doc.badge.clock",
                    statusTitle: "Suggested",
                    tone: .warning
                )
            }
        }
        .accessibilityIdentifier("designSystem.demo.workItemRows")
    }

    private var documentReferenceRows: some View {
        InspectorPane("Document Reference Rows", subtitle: "Evidence/source rows", style: .card) {
            VStack(spacing: AppTheme.spacingS) {
                DocumentReferenceRow(
                    title: "salary-certificate-2026.pdf",
                    subtitle: "document:7D93...",
                    systemImage: "doc.text",
                    detailText: "PDF"
                )
                DocumentReferenceRow(
                    title: "Coffee Bar Zurich",
                    subtitle: "transaction:4B21...",
                    systemImage: "list.bullet.rectangle",
                    detailText: "12.50 CHF"
                )
            }
        }
        .accessibilityIdentifier("designSystem.demo.documentReferenceRows")
    }

    private var inspectorPane: some View {
        InspectorPane("Inspector Pane", subtitle: "Review details", style: .card) {
            InspectorSectionRow("Status", value: "Pending evidence")
            InspectorSectionRow("Confidence", value: "Medium (72%)")
            InspectorSectionRow("Source", value: "requirement:statement-coverage")
        }
        .accessibilityIdentifier("designSystem.demo.inspectorPane")
    }

    private var emptyStates: some View {
        InspectorPane("Empty States", subtitle: "No-data and filtered-data states", style: .card) {
            PaneEmptyState(
                "No matching documents",
                subtitle: "Clear the filter or import another receipt, certificate, or statement.",
                systemImage: "magnifyingglass"
            ) {
                Button("Clear Filter") {}
                    .buttonStyle(.bordered)
            }
        }
        .accessibilityIdentifier("designSystem.demo.emptyStates")
    }

    private var documentPreview: some View {
        InspectorPane("Document Preview", subtitle: "Fallback state", style: .card) {
            DocumentPreviewHost(fileURL: nil, mediaType: "application/pdf")
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(AppTheme.strokeColor, lineWidth: 1)
                )
        }
        .accessibilityIdentifier("designSystem.demo.documentPreview")
    }
}
