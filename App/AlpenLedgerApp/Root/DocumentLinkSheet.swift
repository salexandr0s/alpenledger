import SwiftUI
import ALDesignSystem
import ALDomain
import ALFeatures

struct DocumentLinkSheet: View {
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        NavigationStack {
            List(model.documents, id: \.id) { document in
                Button {
                    model.linkSelectedDocumentToCurrentTransaction(documentId: document.id)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.originalFilename)
                            Text(document.documentType.rawValue.capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "doc.text")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(document.originalFilename)
                .accessibilityValue(document.documentType.rawValue.capitalized)
                .accessibilityIdentifier("sheet.document.\(accessibilitySlug(document.originalFilename))")
            }
            .listStyle(.inset)
            .navigationTitle("Link Document")
            .accessibilityIdentifier("sheet.documentList")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.isShowingDocumentLinkSheet = false
                    }
                    .accessibilityIdentifier("sheet.document.cancel")
                }
            }
            .frame(minWidth: 420, minHeight: 320)
        }
    }
}
