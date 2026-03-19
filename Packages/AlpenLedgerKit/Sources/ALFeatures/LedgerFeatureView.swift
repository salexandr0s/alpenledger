import SwiftUI
import ALDomain
import ALDesignSystem

@MainActor
public struct LedgerFeatureView: View {
    private let accounts: [FinancialAccount]
    private let selectedAccountId: FinancialAccountID?
    private let transactions: [ALDomain.Transaction]
    private let selectedTransactionId: TransactionID?
    private let linkedDocuments: [Document]
    private let onSelectAccount: (FinancialAccountID?) -> Void
    private let onSelectTransaction: (TransactionID?) -> Void
    private let onImportCSV: () -> Void
    private let onLinkDocument: () -> Void

    public init(
        accounts: [FinancialAccount],
        selectedAccountId: FinancialAccountID?,
        transactions: [ALDomain.Transaction],
        selectedTransactionId: TransactionID?,
        linkedDocuments: [Document],
        onSelectAccount: @escaping (FinancialAccountID?) -> Void,
        onSelectTransaction: @escaping (TransactionID?) -> Void,
        onImportCSV: @escaping () -> Void,
        onLinkDocument: @escaping () -> Void
    ) {
        self.accounts = accounts
        self.selectedAccountId = selectedAccountId
        self.transactions = transactions
        self.selectedTransactionId = selectedTransactionId
        self.linkedDocuments = linkedDocuments
        self.onSelectAccount = onSelectAccount
        self.onSelectTransaction = onSelectTransaction
        self.onImportCSV = onImportCSV
        self.onLinkDocument = onLinkDocument
    }

    public var body: some View {
        HSplitView {
            List(selection: accountSelection) {
                ForEach(accounts, id: \.id) { account in
                    VStack(alignment: .leading) {
                        Text(account.displayName)
                        Text(account.institutionName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(account.id)
                    .accessibilityIdentifier("ledger.account.\(accessibilitySlug(account.displayName))")
                }
            }
            .frame(minWidth: AppTheme.sidebarIdealWidth)

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                PaneHeader("Transactions", subtitle: "Review statement rows and keep evidence linked to the ledger.") {
                    Button("Import CSV", systemImage: "tablecells", action: onImportCSV)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("ledger.importCSV")
                }

                List(selection: transactionSelection) {
                    ForEach(transactions, id: \.id) { transaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(transaction.counterpartyName)
                                Text(transaction.memo)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(amountString(transaction))
                                .monospacedDigit()
                        }
                        .tag(transaction.id)
                        .accessibilityIdentifier("ledger.transaction.\(accessibilitySlug(transaction.counterpartyName))")
                    }
                }
                .accessibilityIdentifier("ledger.transactions")
            }
            .frame(minWidth: 420)
            .padding(AppTheme.contentPadding)

            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                PaneHeader("Inspector", subtitle: "Linked evidence for the selected transaction.")
                if selectedTransactionId == nil {
                    ContentUnavailableView("No Transaction Selected", systemImage: "list.bullet.rectangle")
                } else {
                    InspectorPane("Linked Documents") {
                        if linkedDocuments.isEmpty {
                            Text("No linked documents yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(linkedDocuments, id: \.id) { document in
                                Text(document.originalFilename)
                            }
                        }
                        Button("Link Document…", action: onLinkDocument)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("ledger.linkDocument")
                    }
                }
                Spacer()
            }
            .frame(minWidth: AppTheme.inspectorIdealWidth)
            .padding(AppTheme.contentPadding)
        }
    }

    private func amountString(_ transaction: ALDomain.Transaction) -> String {
        let value = Decimal(transaction.amountMinor) / 100
        return "\(NSDecimalNumber(decimal: value).stringValue) \(transaction.currency)"
    }

    private var accountSelection: Binding<FinancialAccountID?> {
        Binding(
            get: { selectedAccountId },
            set: { selection in
                onSelectAccount(selection)
            }
        )
    }

    private var transactionSelection: Binding<TransactionID?> {
        Binding(
            get: { selectedTransactionId },
            set: { selection in
                onSelectTransaction(selection)
            }
        )
    }
}
