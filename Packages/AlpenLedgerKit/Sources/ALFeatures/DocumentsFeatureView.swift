import SwiftUI
import UniformTypeIdentifiers
import ALDomain
import ALDesignSystem

extension ALDomain.Document: Identifiable {}

@MainActor
public struct DocumentsFeatureView: View {
    private enum SortOption: String, CaseIterable, Identifiable {
        case newest
        case oldest
        case name

        var id: String { rawValue }

        var title: String {
            switch self {
            case .newest:
                return "Newest first"
            case .oldest:
                return "Oldest first"
            case .name:
                return "Name"
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var query: String
    @Binding private var scope: DocumentFilterScope
    @State private var sortOption: SortOption = .newest
    @State private var isDropTargeted = false

    private let items: [DocumentBrowserItem]
    private let allDocumentsCount: Int
    private let selectedDocumentId: DocumentID?
    private let previewURL: URL?
    private let linkedTransactions: [ALDomain.Transaction]
    private let isInspectorVisible: Bool
    private let isActive: Bool
    private let onSelectDocument: (DocumentID?) -> Void
    private let onImportDocument: () -> Void
    private let onImportDocuments: ([URL]) -> Void
    private let onRefreshSearchResults: () -> Void
    private let onClearSearch: () -> Void
    private let onResetScope: () -> Void
    private let onSetScope: (DocumentFilterScope) -> Void
    private let onLinkTransaction: () -> Void

    public init(
        query: Binding<String>,
        scope: Binding<DocumentFilterScope>,
        items: [DocumentBrowserItem],
        allDocumentsCount: Int,
        selectedDocumentId: DocumentID?,
        previewURL: URL?,
        linkedTransactions: [ALDomain.Transaction],
        isInspectorVisible: Bool,
        isActive: Bool,
        onSelectDocument: @escaping (DocumentID?) -> Void,
        onImportDocument: @escaping () -> Void,
        onImportDocuments: @escaping ([URL]) -> Void,
        onRefreshSearchResults: @escaping () -> Void,
        onClearSearch: @escaping () -> Void,
        onResetScope: @escaping () -> Void,
        onSetScope: @escaping (DocumentFilterScope) -> Void,
        onLinkTransaction: @escaping () -> Void
    ) {
        _query = query
        _scope = scope
        self.items = items
        self.allDocumentsCount = allDocumentsCount
        self.selectedDocumentId = selectedDocumentId
        self.previewURL = previewURL
        self.linkedTransactions = linkedTransactions
        self.isInspectorVisible = isInspectorVisible
        self.isActive = isActive
        self.onSelectDocument = onSelectDocument
        self.onImportDocument = onImportDocument
        self.onImportDocuments = onImportDocuments
        self.onRefreshSearchResults = onRefreshSearchResults
        self.onClearSearch = onClearSearch
        self.onResetScope = onResetScope
        self.onSetScope = onSetScope
        self.onLinkTransaction = onLinkTransaction
    }

    public var body: some View {
        Group {
            if allDocumentsCount == 0 {
                emptyDropZone
            } else if selectedItem == nil {
                HSplitView {
                    browserPane
                        .frame(minWidth: 380)

                    selectionPromptPane
                        .frame(minWidth: 520)
                }
            } else {
                HSplitView {
                    browserPane
                        .frame(minWidth: 380)

                    previewPane
                        .frame(minWidth: 520)

                    if isInspectorVisible {
                        inspectorPane
                            .frame(minWidth: AppTheme.inspectorIdealWidth)
                            .transition(AppTheme.inspectorTransition(reduceMotion: reduceMotion))
                    }
                }
            }
        }
        .animation(AppTheme.panelAnimation(reduceMotion: reduceMotion), value: isInspectorVisible)
        .searchable(text: $query, placement: .toolbar, prompt: "Search documents")
        .onChange(of: query) { _, _ in
            onRefreshSearchResults()
        }
        .onSubmit(of: .search, onRefreshSearchResults)
        .dropDestination(for: URL.self) { urls, _ in
            guard urls.isEmpty == false else { return false }
            onImportDocuments(urls)
            return true
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
    }

    private var emptyDropZone: some View {
        VStack(spacing: AppTheme.spacingL) {
            VStack(spacing: AppTheme.spacingS) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Import your first document")
                    .font(.title3.weight(.semibold))

                Text("Drag and drop receipts, statements, and tax forms here, or click to browse.")
                    .font(AppTheme.pageSubtitleFont)
                    .foregroundStyle(AppTheme.subduedForegroundColor)
                    .multilineTextAlignment(.center)
            }

            Button("Import Document", action: onImportDocument)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("documents.importButton")
        }
        .padding(AppTheme.spacingXXL)
        .frame(maxWidth: 520)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.largeCornerRadius)
                .fill(AppTheme.emphasizedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.largeCornerRadius)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1, dash: [8, 8])
                )
                .foregroundStyle(isDropTargeted ? Color.accentColor : AppTheme.strokeColor)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var browserPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader("Documents", subtitle: "\(sortedItems.count) shown of \(allDocumentsCount)") {
                HStack(spacing: AppTheme.spacingS) {
                    Menu(scope.title) {
                        ForEach(DocumentFilterScope.allCases) { option in
                            Button(option.title) {
                                onSetScope(option)
                            }
                        }
                    }
                    .accessibilityIdentifier("documents.scopeMenu")

                    Menu(sortOption.title) {
                        ForEach(SortOption.allCases) { option in
                            Button(option.title) {
                                sortOption = option
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.top, AppTheme.spacingM)

            if sortedItems.isEmpty {
                centeredEmptyState(
                    PaneEmptyState(
                        "No matching documents",
                        subtitle: filteredEmptySubtitle,
                        systemImage: "magnifyingglass"
                    ) {
                        if query.isEmpty == false {
                            Button("Clear Search", action: onClearSearch)
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("documents.clearSearchButton")
                        }

                        if scope != .all {
                            Button("Show All Types", action: onResetScope)
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("documents.showAllTypesButton")
                        }
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.spacingXS) {
                        ForEach(sortedItems) { item in
                            Button {
                                onSelectDocument(item.id)
                            } label: {
                                documentRow(item)
                                    .padding(.horizontal, AppTheme.spacingS)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background {
                                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                            .fill(
                                                selectedDocumentId == item.id
                                                    ? AppTheme.accentSurfaceColor
                                                    : AppTheme.secondarySurfaceColor.opacity(0.35)
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .accessibilityLabel(item.title)
                            .accessibilityValue("\(item.typeLabel), \(item.dateLabel), \(item.statusText)")
                            .accessibilityIdentifier("documents.document.\(accessibilitySlug(item.title))")
                        }
                    }
                    .padding(.vertical, AppTheme.spacingXXS)
                }
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.bottom, AppTheme.contentPadding)
                .accessibilityIdentifier("documents.list")
            }
        }
    }

    private var selectionPromptPane: some View {
        PaneEmptyState(
            "Select a document",
            subtitle: "Choose a receipt, statement, or tax form to preview and inspect it.",
            systemImage: "doc.text"
        )
        .accessibilityIdentifier("documents.selectionPrompt")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader(selectedItem?.title ?? "Preview", subtitle: selectedItem?.typeLabel ?? "Selected document preview.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)
                .accessibilityIdentifier("documents.preview.title")

            Group {
                if let previewURL {
                    DocumentPreviewHost(fileURL: previewURL, mediaType: selectedItem?.mediaType ?? "application/pdf")
                } else {
                    PaneEmptyState(
                        "Preview unavailable",
                        subtitle: "This file imported correctly, but preview is not available for this format.",
                        systemImage: "doc.text.magnifyingglass"
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(AppTheme.emphasizedSurfaceColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.strokeColor, lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.bottom, AppTheme.contentPadding)
        }
        .accessibilityIdentifier("documents.previewPane")
    }

    private var inspectorPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader("Inspector", subtitle: "Metadata and linked transactions for the selected document.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                    if let selectedItem {
                        InspectorPane("Document", style: .card) {
                            InspectorSectionRow("Type", value: selectedItem.typeLabel)
                            InspectorSectionRow("Issue Date", value: selectedItem.dateLabel)
                            InspectorSectionRow("Status", value: selectedItem.statusText)
                        }
                    }

                    InspectorPane("Linked Transactions", style: .grouped) {
                        if linkedTransactions.isEmpty {
                            Text("No linked transactions yet.")
                                .font(AppTheme.metaFont)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                ForEach(linkedTransactions, id: \.id) { transaction in
                                    DocumentReferenceRow(
                                        title: transaction.counterpartyName,
                                        subtitle: amountString(transaction),
                                        systemImage: "list.bullet.rectangle"
                                    )
                                }
                            }
                        }

                        Button("Link Transaction…", action: onLinkTransaction)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("documents.linkTransaction")
                    }
                }
                .padding(AppTheme.contentPadding)
            }
        }
    }

    private var selectedItem: DocumentBrowserItem? {
        items.first(where: { $0.id == selectedDocumentId })
    }

    private var sortedItems: [DocumentBrowserItem] {
        items.sorted { lhs, rhs in
            switch sortOption {
            case .newest:
                return (lhs.issueDate ?? .distantPast) > (rhs.issueDate ?? .distantPast)
            case .oldest:
                return (lhs.issueDate ?? .distantFuture) < (rhs.issueDate ?? .distantFuture)
            case .name:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    private var filteredEmptySubtitle: String {
        if query.isEmpty == false && scope != .all {
            return "Adjust the search text or type filter to restore results."
        }
        if query.isEmpty == false {
            return "Try a different search term."
        }
        return "Change the active type filter to show more documents."
    }

    private func centeredEmptyState<Content: View>(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func amountString(_ transaction: ALDomain.Transaction) -> String {
        let value = Decimal(transaction.amountMinor) / 100
        return "\(NSDecimalNumber(decimal: value).stringValue) \(transaction.currency)"
    }

    @ViewBuilder
    private func documentRow(_ item: DocumentBrowserItem) -> some View {
        HStack(alignment: .top, spacing: AppTheme.spacingS) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(AppTheme.subduedForegroundColor)
                    .lineLimit(1)

                HStack(spacing: AppTheme.spacingXS) {
                    StatusBadge(item.typeLabel, tone: .neutral)
                    Text(item.dateLabel)
                        .font(AppTheme.metaFont)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(item.statusText)
                .font(AppTheme.metaFont)
                .foregroundStyle(item.tone == .success ? .secondary : Color.orange)
        }
        .padding(.vertical, AppTheme.spacingXS)
    }
}
