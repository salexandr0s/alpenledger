import SwiftUI
import UniformTypeIdentifiers
import ALDomain
import ALDesignSystem

extension ALDomain.Document: Identifiable {}

@MainActor
public struct DocumentsFeatureView: View {
    private enum FocusTarget: Hashable {
        case browser
        case preview
        case inspectorAction
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var query: String
    @Binding private var scope: DocumentFilterScope
    @FocusState private var focusedPane: FocusTarget?

    private let documents: [Document]
    private let allDocumentsCount: Int
    private let selectedDocumentId: DocumentID?
    private let previewURL: URL?
    private let linkedTransactions: [ALDomain.Transaction]
    private let isInspectorVisible: Bool
    private let isActive: Bool
    private let onSelectDocument: (DocumentID?) -> Void
    private let onImportDocument: () -> Void
    private let onRefreshSearchResults: () -> Void
    private let onClearSearch: () -> Void
    private let onResetScope: () -> Void
    private let onLinkTransaction: () -> Void

    public init(
        query: Binding<String>,
        scope: Binding<DocumentFilterScope>,
        documents: [Document],
        allDocumentsCount: Int,
        selectedDocumentId: DocumentID?,
        previewURL: URL?,
        linkedTransactions: [ALDomain.Transaction],
        isInspectorVisible: Bool,
        isActive: Bool,
        onSelectDocument: @escaping (DocumentID?) -> Void,
        onImportDocument: @escaping () -> Void,
        onRefreshSearchResults: @escaping () -> Void,
        onClearSearch: @escaping () -> Void,
        onResetScope: @escaping () -> Void,
        onLinkTransaction: @escaping () -> Void
    ) {
        _query = query
        _scope = scope
        self.documents = documents
        self.allDocumentsCount = allDocumentsCount
        self.selectedDocumentId = selectedDocumentId
        self.previewURL = previewURL
        self.linkedTransactions = linkedTransactions
        self.isInspectorVisible = isInspectorVisible
        self.isActive = isActive
        self.onSelectDocument = onSelectDocument
        self.onImportDocument = onImportDocument
        self.onRefreshSearchResults = onRefreshSearchResults
        self.onClearSearch = onClearSearch
        self.onResetScope = onResetScope
        self.onLinkTransaction = onLinkTransaction
    }

    public var body: some View {
        HSplitView {
            browserPane
                .frame(minWidth: 360)

            previewPane
                .frame(minWidth: 460)

            if isInspectorVisible {
                inspectorPane
                    .frame(minWidth: AppTheme.inspectorIdealWidth)
                    .transition(AppTheme.inspectorTransition(reduceMotion: reduceMotion))
            }
        }
        .animation(AppTheme.panelAnimation(reduceMotion: reduceMotion), value: isInspectorVisible)
        .searchable(text: $query, placement: .toolbar, prompt: "Search documents")
        .searchScopes($scope) {
            ForEach(DocumentFilterScope.allCases) { option in
                Text(option.title)
                    .accessibilityIdentifier("documents.scope.\(option.rawValue)")
                    .tag(option)
            }
        }
        .onChange(of: query) { _, _ in
            onRefreshSearchResults()
        }
        .onSubmit(of: .search, onRefreshSearchResults)
        .onAppear(perform: focusPrimaryPane)
        .onChange(of: isActive) { _, active in
            if active {
                focusPrimaryPane()
            }
        }
    }

    private var browserPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader("Documents", subtitle: "Browse receipts, statements, and filing evidence.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

            if allDocumentsCount == 0 {
                centeredEmptyState(
                    PaneEmptyState(
                        "No Documents Yet",
                        subtitle: "Import receipts, statements, and tax documents to build a reviewable local archive.",
                        systemImage: "doc"
                    ) {
                        Button("Import Document", systemImage: "plus", action: onImportDocument)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("documents.importButton")
                    }
                )
            } else if documents.isEmpty {
                centeredEmptyState(filteredEmptyState)
            } else {
                Table(documents, selection: documentSelection) {
                    TableColumn("Filename") { document in
                        Text(document.originalFilename)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.vertical, AppTheme.tableRowVerticalPadding)
                            .accessibilityIdentifier("documents.document.\(accessibilitySlug(document.originalFilename))")
                    }
                    .width(min: AppTheme.documentsFilenameMinWidth, ideal: AppTheme.documentsFilenameIdealWidth)

                    TableColumn("Type") { document in
                        Text(documentTypeLabel(document.documentType))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .width(AppTheme.documentsTypeColumnWidth)

                    TableColumn("Issue Date") { document in
                        Text(formattedDate(document.issueDate))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .width(AppTheme.documentsIssueDateColumnWidth)

                    TableColumn("Status") { document in
                        StatusBadge(
                            metadataLabel(document.metadataStatus),
                            tone: metadataTone(document.metadataStatus)
                        )
                    }
                    .width(AppTheme.documentsStatusColumnWidth)
                }
                .accessibilityIdentifier("documents.list")
                .focusable()
                .focused($focusedPane, equals: .browser)
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.bottom, AppTheme.contentPadding)
            }
        }
    }

    private var previewPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            if let selectedDocument {
                PaneHeader(
                    selectedDocument.originalFilename,
                    subtitle: previewSubtitle(selectedDocument),
                    titleAccessibilityIdentifier: "documents.preview.title"
                ) {
                    StatusBadge(
                        metadataLabel(selectedDocument.metadataStatus),
                        tone: metadataTone(selectedDocument.metadataStatus)
                    )
                }
            } else {
                PaneHeader("Preview", subtitle: "Inspect the selected document without leaving the workspace.")
            }
            previewSurface
                .focusable()
                .focused($focusedPane, equals: .preview)
        }
        .padding(.horizontal, AppTheme.contentPadding)
        .padding(.top, AppTheme.spacingM)
        .padding(.bottom, AppTheme.contentPadding)
    }

    private var previewSurface: some View {
        Group {
            if let selectedDocument {
                if supportsPreview(for: selectedDocument), let previewURL {
                    DocumentPreviewHost(fileURL: previewURL, mediaType: selectedDocument.mediaType)
                } else {
                    PaneEmptyState(
                        "Preview Unavailable",
                        subtitle: "This file imported correctly, but the preview pane currently supports PDFs and image formats.",
                        systemImage: "doc.text.magnifyingglass"
                    )
                }
            } else {
                PaneEmptyState(
                    "No Document Selected",
                    subtitle: "Choose a document from the browser to inspect it here.",
                    systemImage: "doc.text"
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(AppTheme.elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.strokeColor, lineWidth: 1)
        )
    }

    private var inspectorPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader("Inspector", subtitle: "File metadata, detected context, and linked transactions.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

            if let selectedDocument {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                        InspectorPane("Document Details") {
                            InspectorSectionRow(
                                "Type",
                                value: documentTypeLabel(selectedDocument.documentType),
                                valueAccessibilityIdentifier: "documents.inspector.type"
                            )
                            InspectorSectionRow("Status", value: metadataLabel(selectedDocument.metadataStatus))
                            InspectorSectionRow("Issue Date", value: formattedDate(selectedDocument.issueDate))
                            InspectorSectionRow("Origin", value: originLabel(selectedDocument.origin))
                        }

                        InspectorPane("File Metadata") {
                            InspectorSectionRow("Media Type", value: selectedDocument.mediaType)
                            InspectorSectionRow("Parse Version", value: selectedDocument.parseVersion)
                            InspectorSectionRow(
                                "Extracted Text",
                                value: selectedDocument.extractedText?.isEmpty == false ? "Available" : "Not extracted"
                            )
                        }

                        InspectorPane("Linked Transactions") {
                            if linkedTransactions.isEmpty {
                                PaneEmptyState(
                                    "No Linked Transactions",
                                    subtitle: "Attach this document to a transaction when the evidence trail is ready.",
                                    systemImage: "paperclip"
                                )
                            } else {
                                ForEach(linkedTransactions, id: \.id) { transaction in
                                    SourceListRow(
                                        title: transaction.counterpartyName,
                                        subtitle: amountString(transaction),
                                        systemImage: "list.bullet.rectangle"
                                    )
                                }
                            }

                            Button("Link Transaction…", action: onLinkTransaction)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("documents.linkTransaction")
                                .focused($focusedPane, equals: .inspectorAction)
                        }
                    }
                    .padding(AppTheme.contentPadding)
                }
            } else {
                centeredEmptyState(
                    PaneEmptyState(
                        "No Document Selected",
                        subtitle: "Select a document in the browser to inspect its metadata and links.",
                        systemImage: "doc"
                    )
                )
            }
        }
    }

    private var filteredEmptyState: some View {
        PaneEmptyState(
            "No Matching Documents",
            subtitle: filteredEmptySubtitle,
            systemImage: "line.3.horizontal.decrease.circle"
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

            Button("Import Document", systemImage: "plus", action: onImportDocument)
                .buttonStyle(.borderedProminent)
        }
    }

    private var filteredEmptySubtitle: String {
        if query.isEmpty == false && scope != .all {
            return "Nothing matches the current search text and type scope."
        }
        if query.isEmpty == false {
            return "Nothing matches the current search text."
        }
        return "No imported documents match the current type scope."
    }

    private var selectedDocument: Document? {
        documents.first(where: { $0.id == selectedDocumentId }) ?? documents.first
    }

    private func centeredEmptyState<Content: View>(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func focusPrimaryPane() {
        guard isActive, documents.isEmpty == false else { return }
        Task { @MainActor in
            focusedPane = .browser
        }
    }

    private func supportsPreview(for document: Document) -> Bool {
        if document.mediaType == "application/pdf" || document.originalFilename.lowercased().hasSuffix(".pdf") {
            return true
        }
        guard let type = UTType(mimeType: document.mediaType) else {
            return false
        }
        return type.conforms(to: .image)
    }

    private func previewSubtitle(_ document: Document) -> String {
        [documentTypeLabel(document.documentType), formattedDate(document.issueDate)]
            .filter { $0 != "n/a" }
            .joined(separator: " • ")
    }

    private func metadataTone(_ status: MetadataStatus) -> StatusBadge.Tone {
        switch status {
        case .proposed:
            return .warning
        case .confirmed:
            return .success
        }
    }

    private func documentTypeLabel(_ documentType: DocumentType) -> String {
        switch documentType {
        case .unknown:
            return "Unknown"
        case .receipt:
            return "Receipt"
        case .invoice:
            return "Invoice"
        case .bankStatement:
            return "Bank Statement"
        case .salaryCertificate:
            return "Salary Certificate"
        case .healthInsuranceCertificate:
            return "Health Insurance Certificate"
        case .pillar3aCertificate:
            return "Pillar 3a Certificate"
        }
    }

    private func metadataLabel(_ status: MetadataStatus) -> String {
        switch status {
        case .proposed:
            return "Proposed"
        case .confirmed:
            return "Confirmed"
        }
    }

    private func originLabel(_ origin: DocumentOrigin) -> String {
        switch origin {
        case .userImport:
            return "User Import"
        case .importPipeline:
            return "Import Pipeline"
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "n/a" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func amountString(_ transaction: ALDomain.Transaction) -> String {
        let value = Decimal(transaction.amountMinor) / 100
        return "\(NSDecimalNumber(decimal: value).stringValue) \(transaction.currency)"
    }

    private var documentSelection: Binding<DocumentID?> {
        Binding(
            get: { selectedDocumentId },
            set: { selection in
                onSelectDocument(selection)
            }
        )
    }
}
