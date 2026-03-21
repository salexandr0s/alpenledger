import SwiftUI
import ALDesignSystem
import ALDomain
import ALFeatures

struct TransactionLinkSheet: View {
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        NavigationStack {
            List(model.transactions, id: \.id) { transaction in
                Button {
                    model.linkCurrentDocumentToTransaction(transactionId: transaction.id)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.counterpartyName)
                            if transaction.memo.isEmpty == false {
                                Text(transaction.memo)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(transaction.counterpartyName)
                .accessibilityValue(transaction.memo)
                .accessibilityIdentifier("sheet.transaction.\(accessibilitySlug(transaction.counterpartyName))")
            }
            .listStyle(.inset)
            .navigationTitle("Link Transaction")
            .accessibilityIdentifier("sheet.transactionList")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.isShowingTransactionLinkSheet = false
                    }
                    .accessibilityIdentifier("sheet.transaction.cancel")
                }
            }
            .frame(minWidth: 420, minHeight: 320)
        }
    }
}
