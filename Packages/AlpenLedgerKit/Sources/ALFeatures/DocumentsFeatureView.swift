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
    @State private var sortOrder: [KeyPathComparator<DocumentBrowserItem>] = [
        KeyPathComparator(\DocumentBrowserItem.issueDate, order: .reverse)
    ]
    @State private var metadataDraftDocumentId: DocumentID?
    @State private var metadataDraftType: DocumentType = .unknown
    @State private var metadataDraftHasIssueDate = false
    @State private var metadataDraftIssueDate = Date()

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
    private let onArchiveDocument: () -> Void
    private let onRestoreDocument: () -> Void
    private let onReviewMetadata: (DocumentID, DocumentType, Date?) -> Void

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
        onLinkTransaction: @escaping () -> Void,
        onArchiveDocument: @escaping () -> Void,
        onRestoreDocument: @escaping () -> Void,
        onReviewMetadata: @escaping (DocumentID, DocumentType, Date?) -> Void
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
        self.onArchiveDocument = onArchiveDocument
        self.onRestoreDocument = onRestoreDocument
        self.onReviewMetadata = onReviewMetadata
    }

    public var body: some View {
        Group {
            if allDocumentsCount == 0 {
                emptyDropZone
            } else if sortedItems.isEmpty {
                filteredEmptyPane
            } else {
                HSplitView {
                    documentTable
                        .frame(minWidth: 380)

                    previewPane
                        .frame(minWidth: 520)
                }
            }
        }
        .navigationTitle("Documents")
        .navigationSubtitle("Search and preview source files")
        .toolbar {
            ToolbarItemGroup {
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
                            syncSortOrder(option)
                        }
                    }
                }
            }
        }
        .inspector(isPresented: inspectorBinding) {
            inspectorContent
                .inspectorColumnWidth(min: 240, ideal: 280, max: 340)
        }
        .searchable(text: $query, placement: .toolbar, prompt: "Search documents")
        .onChange(of: query) { _, _ in
            onRefreshSearchResults()
        }
        .onSubmit(of: .search, onRefreshSearchResults)
        .onAppear(perform: syncMetadataDraft)
        .onChange(of: selectedDocumentId) { _, _ in
            syncMetadataDraft()
        }
        .onChange(of: selectedItem?.documentType) { _, _ in
            syncMetadataDraft()
        }
        .onChange(of: selectedItem?.issueDate) { _, _ in
            syncMetadataDraft()
        }
        .onChange(of: selectedItem?.metadataStatus) { _, _ in
            syncMetadataDraft()
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard urls.isEmpty == false else { return false }
            onImportDocuments(urls)
            return true
        }
    }

    // MARK: - Empty States

    private var emptyDropZone: some View {
        ContentUnavailableView {
            Label("Import your first document", systemImage: "square.and.arrow.down.on.square")
        } description: {
            Text("Drag and drop receipts, statements, and tax forms here, or click to browse.")
        } actions: {
            Button("Import Document", action: onImportDocument)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("documents.importButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("documents.emptyDropZone")
    }

    private var filteredEmptyPane: some View {
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
    }

    // MARK: - Document Table

    private var documentTable: some View {
        Table(of: DocumentBrowserItem.self, selection: documentSelection, sortOrder: $sortOrder) {
            TableColumn("Name", sortUsing: KeyPathComparator(\DocumentBrowserItem.title)) { item in
                HStack(spacing: AppTheme.spacingS) {
                    Image(systemName: item.systemImage)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.title)
                            .lineLimit(1)

                        Text(item.subtitle)
                            .font(AppTheme.metaFont)
                            .foregroundStyle(AppTheme.subduedForegroundColor)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(item.title)
                .accessibilityValue("\(item.typeLabel), \(item.dateLabel), \(item.statusText)")
                .accessibilityIdentifier("documents.document.\(accessibilitySlug(item.title))")
            }
            .width(min: AppTheme.documentsFilenameMinWidth, ideal: AppTheme.documentsFilenameIdealWidth)

            TableColumn("Type", sortUsing: KeyPathComparator(\DocumentBrowserItem.typeLabel)) { item in
                StatusBadge(item.typeLabel, tone: .neutral)
            }
            .width(AppTheme.documentsTypeColumnWidth)

            TableColumn("Date", sortUsing: KeyPathComparator(\DocumentBrowserItem.issueDate)) { item in
                Text(item.dateLabel)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            }
            .width(AppTheme.documentsIssueDateColumnWidth)

            TableColumn("Status", sortUsing: KeyPathComparator(\DocumentBrowserItem.statusText)) { item in
                Text(item.statusText)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(item.tone == .success ? .secondary : Color.orange)
            }
            .width(AppTheme.documentsStatusColumnWidth)
        } rows: {
            ForEach(sortedItems) { item in
                TableRow(item)
            }
        }
        .onChange(of: sortOrder) { _, newOrder in
            syncSortOptionFromOrder(newOrder)
        }
        .accessibilityIdentifier("documents.list")
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let selectedItem {
                    if let previewURL {
                        ZStack(alignment: .topLeading) {
                            DocumentPreviewHost(fileURL: previewURL, mediaType: selectedItem.mediaType)

                            Color.clear
                                .frame(width: 1, height: 1)
                                .accessibilityElement()
                                .accessibilityLabel("Document preview")
                                .accessibilityIdentifier("documents.previewPane")
                        }
                    } else {
                        PaneEmptyState(
                            "Preview unavailable",
                            subtitle: "This file imported correctly, but preview is not available for this format.",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }
                } else {
                    PaneEmptyState(
                        "Select a document",
                        subtitle: "Choose a receipt, statement, or tax form to preview and inspect it.",
                        systemImage: "doc.text"
                    )
                    .accessibilityIdentifier("documents.selectionPrompt")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Document preview")
        .accessibilityIdentifier("documents.previewPane")
    }

    // MARK: - Inspector

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { isInspectorVisible && selectedItem != nil },
            set: { _ in }
        )
    }

    private var inspectorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                if let selectedItem {
                    GroupBox("Document") {
                        metadataEditor(for: selectedItem)
                    }
                }

                GroupBox("Linked Transactions") {
                    VStack(alignment: .leading, spacing: AppTheme.inspectorRowSpacing) {
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
                            .disabled(selectedItem?.isArchived ?? true)
                            .accessibilityIdentifier("documents.linkTransaction")
                    }
                }

                if let selectedItem {
                    GroupBox("Retention") {
                        VStack(alignment: .leading, spacing: AppTheme.inspectorRowSpacing) {
                            if selectedItem.isArchived {
                                if let archivedAtText = selectedItem.archivedAtText {
                                    InspectorSectionRow("Archived At", value: archivedAtText)
                                }
                                if let archivedBy = selectedItem.archivedBy {
                                    InspectorSectionRow("Archived By", value: archivedBy)
                                }
                                if let archiveReason = selectedItem.archiveReason {
                                    InspectorSectionRow("Reason", value: archiveReason)
                                }

                                Button(action: onRestoreDocument) {
                                    Label("Restore Document", systemImage: "arrow.uturn.backward.circle")
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("documents.restoreDocument")
                            } else {
                                Button(role: .destructive, action: onArchiveDocument) {
                                    Label("Archive Document…", systemImage: "archivebox")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("documents.archiveDocument")
                            }
                        }
                    }
                }
            }
            .padding(AppTheme.contentPadding)
        }
    }

    // MARK: - Helpers

    private var documentSelection: Binding<DocumentID?> {
        Binding(
            get: { selectedDocumentId },
            set: { onSelectDocument($0) }
        )
    }

    private var selectedItem: DocumentBrowserItem? {
        items.first(where: { $0.id == selectedDocumentId })
    }

    private var sortedItems: [DocumentBrowserItem] {
        items.sorted(using: sortOrder)
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
        MoneyFormatter().format(minorUnits: transaction.amountMinor, currency: transaction.currency)
    }

    private func syncSortOrder(_ option: SortOption) {
        switch option {
        case .newest:
            sortOrder = [KeyPathComparator(\DocumentBrowserItem.issueDate, order: .reverse)]
        case .oldest:
            sortOrder = [KeyPathComparator(\DocumentBrowserItem.issueDate, order: .forward)]
        case .name:
            sortOrder = [KeyPathComparator(\DocumentBrowserItem.title, order: .forward)]
        }
    }

    private func syncSortOptionFromOrder(_ order: [KeyPathComparator<DocumentBrowserItem>]) {
        guard let first = order.first else { return }
        if first.keyPath == \DocumentBrowserItem.issueDate {
            sortOption = first.order == .reverse ? .newest : .oldest
        } else if first.keyPath == \DocumentBrowserItem.title {
            sortOption = .name
        }
    }

    private func syncMetadataDraft() {
        guard let selectedItem else {
            metadataDraftDocumentId = nil
            metadataDraftType = .unknown
            metadataDraftHasIssueDate = false
            metadataDraftIssueDate = Date()
            return
        }
        guard metadataDraftDocumentId != selectedItem.id ||
            metadataDraftType != selectedItem.documentType ||
            metadataDraftIssueDate != (selectedItem.issueDate ?? metadataDraftIssueDate) ||
            metadataDraftHasIssueDate != (selectedItem.issueDate != nil)
        else {
            return
        }

        metadataDraftDocumentId = selectedItem.id
        metadataDraftType = selectedItem.documentType
        if let issueDate = selectedItem.issueDate {
            metadataDraftHasIssueDate = true
            metadataDraftIssueDate = issueDate
        } else {
            metadataDraftHasIssueDate = false
            metadataDraftIssueDate = Date()
        }
    }

    @ViewBuilder
    private func metadataEditor(for item: DocumentBrowserItem) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.inspectorRowSpacing) {
            Picker("Type", selection: $metadataDraftType) {
                ForEach(DocumentType.allCases, id: \.rawValue) { type in
                    Text(documentTypeLabel(type)).tag(type)
                }
            }
            .disabled(item.isArchived)
            .accessibilityIdentifier("documents.metadata.type")

            Toggle("Issue Date", isOn: $metadataDraftHasIssueDate)
                .disabled(item.isArchived)
                .accessibilityIdentifier("documents.metadata.hasIssueDate")

            if metadataDraftHasIssueDate {
                DatePicker("Date", selection: $metadataDraftIssueDate, displayedComponents: .date)
                    .disabled(item.isArchived)
                    .accessibilityIdentifier("documents.metadata.issueDate")
            }

            InspectorSectionRow("Status", value: item.statusText)

            Button(action: {
                onReviewMetadata(item.id, metadataDraftType, metadataDraftIssueDateValue)
            }) {
                Label("Confirm Metadata", systemImage: "checkmark.seal")
            }
            .buttonStyle(.borderedProminent)
            .disabled(canSubmitMetadataReview(for: item) == false)
            .accessibilityIdentifier("documents.metadata.confirm")
        }
    }

    private var metadataDraftIssueDateValue: Date? {
        metadataDraftHasIssueDate ? metadataDraftIssueDate : nil
    }

    private func canSubmitMetadataReview(for item: DocumentBrowserItem) -> Bool {
        guard item.isArchived == false else {
            return false
        }
        return item.metadataStatus != .confirmed ||
            item.documentType != metadataDraftType ||
            item.issueDate != metadataDraftIssueDateValue
    }

    private func documentTypeLabel(_ documentType: DocumentType) -> String {
        switch documentType {
        case .unknown:
            return "Unsorted"
        case .receipt:
            return "Receipt"
        case .invoice:
            return "Invoice"
        case .qrBill:
            return "QR-bill"
        case .bankStatement:
            return "Statement"
        case .salaryCertificate:
            return "Salary Certificate"
        case .healthInsuranceCertificate:
            return "Health Insurance"
        case .pillar3aCertificate:
            return "Pillar 3a"
        case .eCH0196TaxStatement:
            return "eCH-0196 Tax Statement"
        case .eCH0248PensionCertificate:
            return "eCH-0248 Pension"
        case .eCH0275HealthInsuranceCertificate:
            return "eCH-0275 Health Insurance"
        }
    }
}
