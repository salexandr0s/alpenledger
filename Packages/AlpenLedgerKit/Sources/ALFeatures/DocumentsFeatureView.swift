import SwiftUI
import ALDomain
import ALDesignSystem

@MainActor
public struct DocumentsFeatureView: View {
    @Binding private var query: String
    private let documents: [Document]
    private let selectedDocumentId: DocumentID?
    private let previewURL: URL?
    private let linkedTransactions: [ALDomain.Transaction]
    private let onSelectDocument: (DocumentID?) -> Void
    private let onImportDocument: () -> Void
    private let onLinkTransaction: () -> Void

    public init(
        query: Binding<String>,
        documents: [Document],
        selectedDocumentId: DocumentID?,
        previewURL: URL?,
        linkedTransactions: [ALDomain.Transaction],
        onSelectDocument: @escaping (DocumentID?) -> Void,
        onImportDocument: @escaping () -> Void,
        onLinkTransaction: @escaping () -> Void
    ) {
        _query = query
        self.documents = documents
        self.selectedDocumentId = selectedDocumentId
        self.previewURL = previewURL
        self.linkedTransactions = linkedTransactions
        self.onSelectDocument = onSelectDocument
        self.onImportDocument = onImportDocument
        self.onLinkTransaction = onLinkTransaction
    }

    public var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack {
                    TextField("Search documents", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("documents.searchField")
                    Button("Import Document", action: onImportDocument)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("documents.importButton")
                }

                List(selection: documentSelection) {
                    ForEach(documents, id: \.id) { document in
                        VStack(alignment: .leading) {
                            Text(document.originalFilename)
                            Text(document.documentType.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(document.id)
                        .accessibilityIdentifier("documents.document.\(accessibilitySlug(document.originalFilename))")
                    }
                }
                .accessibilityIdentifier("documents.list")
            }
            .frame(minWidth: 320)
            .padding(AppTheme.spacingM)

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                Text("Preview")
                    .font(.title3.weight(.semibold))
                if let selectedDocument = documents.first(where: { $0.id == selectedDocumentId }) {
                    DocumentPreviewHost(fileURL: previewURL, mediaType: selectedDocument.mediaType)
                } else {
                    ContentUnavailableView("No Document Selected", systemImage: "doc")
                }
            }
            .frame(minWidth: 420)
            .padding(AppTheme.spacingM)

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                Text("Inspector")
                    .font(.title3.weight(.semibold))
                if selectedDocumentId == nil {
                    ContentUnavailableView("No Document Selected", systemImage: "sidebar.right")
                } else {
                    InspectorPane("Linked Transactions") {
                        if linkedTransactions.isEmpty {
                            Text("No linked transactions yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(linkedTransactions, id: \.id) { transaction in
                                Text(transaction.counterpartyName)
                            }
                        }
                        Button("Link Transaction…", action: onLinkTransaction)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("documents.linkTransaction")
                    }
                }
                Spacer()
            }
            .frame(minWidth: 260)
            .padding(AppTheme.spacingM)
        }
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
