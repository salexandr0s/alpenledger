import SwiftUI
import ALDomain
import ALDesignSystem

extension ALDomain.Transaction: Identifiable {}

@MainActor
public struct LedgerFeatureView: View {
    private enum FocusTarget: Hashable {
        case accounts
        case transactions
        case inspectorAction
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedPane: FocusTarget?

    private let accounts: [FinancialAccount]
    private let selectedAccountId: FinancialAccountID?
    private let transactions: [ALDomain.Transaction]
    private let allTransactionsCount: Int
    private let transactionScope: LedgerTransactionScope
    private let selectedTransactionId: TransactionID?
    private let linkedDocuments: [Document]
    private let isInspectorVisible: Bool
    private let isActive: Bool
    private let onSelectAccount: (FinancialAccountID?) -> Void
    private let onSelectTransaction: (TransactionID?) -> Void
    private let onImportCSV: () -> Void
    private let onResetScope: () -> Void
    private let onLinkDocument: () -> Void

    public init(
        accounts: [FinancialAccount],
        selectedAccountId: FinancialAccountID?,
        transactions: [ALDomain.Transaction],
        allTransactionsCount: Int,
        transactionScope: LedgerTransactionScope,
        selectedTransactionId: TransactionID?,
        linkedDocuments: [Document],
        isInspectorVisible: Bool,
        isActive: Bool,
        onSelectAccount: @escaping (FinancialAccountID?) -> Void,
        onSelectTransaction: @escaping (TransactionID?) -> Void,
        onImportCSV: @escaping () -> Void,
        onResetScope: @escaping () -> Void,
        onLinkDocument: @escaping () -> Void
    ) {
        self.accounts = accounts
        self.selectedAccountId = selectedAccountId
        self.transactions = transactions
        self.allTransactionsCount = allTransactionsCount
        self.transactionScope = transactionScope
        self.selectedTransactionId = selectedTransactionId
        self.linkedDocuments = linkedDocuments
        self.isInspectorVisible = isInspectorVisible
        self.isActive = isActive
        self.onSelectAccount = onSelectAccount
        self.onSelectTransaction = onSelectTransaction
        self.onImportCSV = onImportCSV
        self.onResetScope = onResetScope
        self.onLinkDocument = onLinkDocument
    }

    public var body: some View {
        HSplitView {
            accountPane
                .frame(minWidth: AppTheme.sidebarIdealWidth)

            transactionPane
                .frame(minWidth: 520)

            if isInspectorVisible {
                inspectorPane
                    .frame(minWidth: AppTheme.inspectorIdealWidth)
                    .transition(AppTheme.inspectorTransition(reduceMotion: reduceMotion))
            }
        }
        .animation(AppTheme.panelAnimation(reduceMotion: reduceMotion), value: isInspectorVisible)
        .onAppear(perform: focusPrimaryPane)
        .onChange(of: isActive) { _, active in
            if active {
                focusPrimaryPane()
            }
        }
    }

    private var accountPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader("Accounts", subtitle: "Bank and card activity in this workspace.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

            if accounts.isEmpty {
                centeredEmptyState(
                    PaneEmptyState(
                        "No Accounts Yet",
                        subtitle: "Create or import a workspace with financial accounts before reviewing transactions.",
                        systemImage: "building.columns"
                    )
                )
            } else {
                List(selection: accountSelection) {
                    ForEach(accounts, id: \.id) { account in
                        SourceListRow(
                            title: account.displayName,
                            subtitle: account.institutionName,
                            systemImage: symbol(for: account.accountType),
                            badgeText: account.currency
                        )
                        .tag(account.id)
                        .accessibilityIdentifier("ledger.account.\(accessibilitySlug(account.displayName))")
                    }
                }
                .listStyle(.sidebar)
                .focusable()
                .focused($focusedPane, equals: .accounts)
            }
        }
    }

    private var transactionPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader(
                selectedAccount?.displayName ?? "Transactions",
                subtitle: selectedAccount?.institutionName ?? "Review statement rows and their review state."
            ) {
                if allTransactionsCount > 0 {
                    ToolbarAccessoryChip("Rows", value: transactions.count.formatted(), systemImage: "list.number")
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.top, AppTheme.spacingM)

            if accounts.isEmpty {
                centeredEmptyState(
                    PaneEmptyState(
                        "No Account Selected",
                        subtitle: "Select or create an account before reviewing ledger activity.",
                        systemImage: "list.bullet.rectangle"
                    )
                )
            } else if allTransactionsCount == 0 {
                centeredEmptyState(
                    PaneEmptyState(
                        "No Transactions Yet",
                        subtitle: "Import a statement to populate this account with reviewable transaction rows.",
                        systemImage: "tablecells"
                    ) {
                        Button("Import CSV", systemImage: "tablecells", action: onImportCSV)
                            .buttonStyle(.borderedProminent)
                    }
                )
            } else if transactions.isEmpty {
                centeredEmptyState(
                    PaneEmptyState(
                        "No Transactions in This Scope",
                        subtitle: "The current filter hides all rows for this account.",
                        systemImage: "line.3.horizontal.decrease.circle"
                    ) {
                        Button("Show All", action: onResetScope)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("ledger.showAllButton")

                        Button("Import CSV", systemImage: "tablecells", action: onImportCSV)
                            .buttonStyle(.borderedProminent)
                    }
                )
            } else {
                Table(transactions, selection: transactionSelection) {
                    TableColumn("Date") { transaction in
                        Text(formattedDate(transaction.bookingDate))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.vertical, AppTheme.tableRowVerticalPadding)
                    }
                    .width(AppTheme.ledgerDateColumnWidth)

                    TableColumn("Counterparty") { transaction in
                        VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                            Text(transaction.counterpartyName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .accessibilityIdentifier("ledger.transaction.\(accessibilitySlug(transaction.counterpartyName))")

                            if transaction.memo.isEmpty == false {
                                Text(transaction.memo)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                        .padding(.vertical, AppTheme.tableRowVerticalPadding)
                    }
                    .width(min: AppTheme.ledgerCounterpartyMinWidth, ideal: AppTheme.ledgerCounterpartyIdealWidth)

                    TableColumn("Amount") { transaction in
                        Text(amountString(transaction))
                            .monospacedDigit()
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .width(AppTheme.ledgerAmountColumnWidth)

                    TableColumn("Review") { transaction in
                        StatusBadge(
                            reviewLabel(transaction.reviewState),
                            tone: reviewTone(transaction.reviewState)
                        )
                    }
                    .width(AppTheme.ledgerReviewColumnWidth)
                }
                .accessibilityIdentifier("ledger.transactions")
                .focusable()
                .focused($focusedPane, equals: .transactions)
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.bottom, AppTheme.contentPadding)
            }
        }
    }

    private var inspectorPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader("Inspector", subtitle: "Selected transaction details, source context, and evidence links.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

            if let selectedTransaction {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                        InspectorPane("Transaction") {
                            StatusBadge(
                                reviewLabel(selectedTransaction.reviewState),
                                tone: reviewTone(selectedTransaction.reviewState)
                            )
                            InspectorSectionRow(
                                "Counterparty",
                                value: selectedTransaction.counterpartyName,
                                valueAccessibilityIdentifier: "ledger.inspector.counterparty"
                            )
                            InspectorSectionRow("Booked", value: formattedDate(selectedTransaction.bookingDate))
                            InspectorSectionRow("Amount", value: amountString(selectedTransaction))
                            if selectedTransaction.valueDate != nil {
                                InspectorSectionRow(
                                    "Value Date",
                                    value: formattedDate(selectedTransaction.valueDate)
                                )
                            }
                            if let reference = selectedTransaction.reference, reference.isEmpty == false {
                                InspectorSectionRow("Reference", value: reference)
                            }
                        }

                        InspectorPane("Import Context") {
                            InspectorSectionRow("Origin", value: originLabel(selectedTransaction.originKind))
                            InspectorSectionRow("Source Line", value: selectedTransaction.sourceLineRef)
                            if let balanceAfterMinor = selectedTransaction.balanceAfterMinor {
                                InspectorSectionRow(
                                    "Balance After",
                                    value: amountString(balanceAfterMinor, currency: selectedTransaction.currency)
                                )
                            }
                        }

                        InspectorPane("Linked Evidence") {
                            if linkedDocuments.isEmpty {
                                PaneEmptyState(
                                    "No Linked Documents",
                                    subtitle: "Attach a receipt or supporting document to complete the evidence trail.",
                                    systemImage: "paperclip"
                                )
                            } else {
                                ForEach(linkedDocuments, id: \.id) { document in
                                    SourceListRow(
                                        title: document.originalFilename,
                                        subtitle: documentTypeLabel(document.documentType),
                                        systemImage: "doc.text"
                                    )
                                }
                            }

                            Button("Link Document…", action: onLinkDocument)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("ledger.linkDocument")
                                .focused($focusedPane, equals: .inspectorAction)
                        }
                    }
                    .padding(AppTheme.contentPadding)
                }
            } else {
                centeredEmptyState(
                    PaneEmptyState(
                        "No Transaction Selected",
                        subtitle: inspectorEmptySubtitle,
                        systemImage: "list.bullet.rectangle"
                    )
                )
            }
        }
    }

    private var selectedAccount: FinancialAccount? {
        accounts.first(where: { $0.id == selectedAccountId }) ?? accounts.first
    }

    private var selectedTransaction: ALDomain.Transaction? {
        transactions.first(where: { $0.id == selectedTransactionId }) ?? transactions.first
    }

    private var inspectorEmptySubtitle: String {
        if accounts.isEmpty {
            return "Import an account and transaction data before using the inspector."
        }
        if allTransactionsCount == 0 {
            return "Import a statement to inspect individual transactions."
        }
        if transactionScope != .all && transactions.isEmpty {
            return "Show all rows to restore a visible selection."
        }
        return "Select a row in the transaction table to inspect its details."
    }

    private func centeredEmptyState<Content: View>(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func focusPrimaryPane() {
        guard isActive, accounts.isEmpty == false, transactions.isEmpty == false else { return }
        Task { @MainActor in
            focusedPane = .transactions
        }
    }

    private func amountString(_ transaction: ALDomain.Transaction) -> String {
        amountString(transaction.amountMinor, currency: transaction.currency)
    }

    private func amountString(_ amountMinor: Int64, currency: String) -> String {
        let value = Decimal(amountMinor) / 100
        return "\(NSDecimalNumber(decimal: value).stringValue) \(currency)"
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "n/a" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func reviewLabel(_ reviewState: ReviewState) -> String {
        switch reviewState {
        case .pending:
            return "Pending"
        case .reviewed:
            return "Reviewed"
        }
    }

    private func reviewTone(_ reviewState: ReviewState) -> StatusBadge.Tone {
        switch reviewState {
        case .pending:
            return .warning
        case .reviewed:
            return .success
        }
    }

    private func originLabel(_ originKind: TransactionOriginKind) -> String {
        switch originKind {
        case .imported:
            return "Imported"
        case .manual:
            return "Manual"
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

    private func symbol(for accountType: FinancialAccountType) -> String {
        switch accountType {
        case .bank:
            return "building.columns"
        case .card:
            return "creditcard"
        case .cash:
            return "banknote"
        case .receivable:
            return "arrow.down.left.circle"
        case .payable:
            return "arrow.up.right.circle"
        case .loan:
            return "percent"
        }
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
