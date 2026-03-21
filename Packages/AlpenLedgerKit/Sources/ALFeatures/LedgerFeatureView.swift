import SwiftUI
import ALDomain
import ALDesignSystem

extension ALDomain.Transaction: Identifiable {}

@MainActor
public struct LedgerFeatureView: View {
    private enum FocusTarget: Hashable {
        case accounts
        case transactions
    }

    private enum DateRangeFilter: String, CaseIterable, Identifiable {
        case all
        case last30Days
        case yearToDate

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "All dates"
            case .last30Days:
                return "Last 30 days"
            case .yearToDate:
                return "Year to date"
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focusedPane: FocusTarget?
    @State private var searchQuery = ""
    @State private var dateRange: DateRangeFilter = .all
    @State private var transactionSelection: TransactionID?
    @State private var sortOrder: [KeyPathComparator<ALDomain.Transaction>] = [
        .init(\.bookingDate, order: .reverse),
    ]

    private let accounts: [LedgerAccountSummary]
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
    private let onSetScope: (LedgerTransactionScope) -> Void
    private let onLinkDocument: () -> Void

    public init(
        accounts: [LedgerAccountSummary],
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
        onSetScope: @escaping (LedgerTransactionScope) -> Void,
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
        self.onSetScope = onSetScope
        self.onLinkDocument = onLinkDocument
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if accounts.isEmpty {
                emptyWorkspaceState
            } else if selectedAccount == nil {
                HSplitView {
                    accountPane
                        .frame(minWidth: AppTheme.sidebarIdealWidth)

                    selectionPromptPane
                        .frame(minWidth: 520)
                }
            } else {
                HSplitView {
                    accountPane
                        .frame(minWidth: AppTheme.sidebarIdealWidth)

                    transactionPane
                        .frame(minWidth: 640)
                }
                .inspector(isPresented: inspectorBinding) {
                    inspectorContent
                        .inspectorColumnWidth(min: 240, ideal: 280, max: 340)
                }
            }
        }
        .navigationTitle("Ledger")
        .navigationSubtitle("Transactions and linked evidence")
        .animation(AppTheme.panelAnimation(reduceMotion: reduceMotion), value: isInspectorVisible)
        .onAppear(perform: focusPrimaryPane)
        .onChange(of: isActive) { _, active in
            if active {
                focusPrimaryPane()
            }
        }
        .onChange(of: selectedAccountId) { _, _ in
            focusPrimaryPane()
        }
        .onChange(of: transactionSelection) { _, newValue in
            onSelectTransaction(newValue)
        }
        .onChange(of: selectedTransactionId) { _, newValue in
            if transactionSelection != newValue {
                transactionSelection = newValue
            }
        }
    }

    // MARK: - Empty / Prompt States

    private var emptyWorkspaceState: some View {
        PaneEmptyState(
            "Import your first account",
            subtitle: "Bring in a bank statement to populate the ledger and start linking evidence.",
            systemImage: "building.columns"
        ) {
            Button("Import Transactions", action: onImportCSV)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectionPromptPane: some View {
        PaneEmptyState(
            "Select an account",
            subtitle: "Choose an account from the left to review transaction activity.",
            systemImage: "list.bullet.rectangle"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Account Sidebar

    private var accountPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Text("Accounts")
                    .font(AppTheme.sectionTitleFont)
                Spacer()
                Button("Import Transactions", action: onImportCSV)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.top, AppTheme.spacingM)

            List(selection: accountSelection) {
                ForEach(accounts) { account in
                    HStack(spacing: AppTheme.spacingS) {
                        Label {
                            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                                Text(account.title)
                                    .font(.body.weight(.medium))

                                Text("\(account.accountTypeLabel) \u{2022} \(account.subtitle)")
                                    .font(AppTheme.metaFont)
                                    .foregroundStyle(AppTheme.subduedForegroundColor)

                                StatusBadge(account.statusText, tone: account.tone)
                            }
                        } icon: {
                            Image(systemName: account.systemImage)
                                .symbolRenderingMode(AppTheme.symbolRenderingMode)
                                .foregroundStyle(Color.accentColor)
                        }

                        Spacer(minLength: AppTheme.spacingS)

                        LabeledContent {} label: {
                            Text(account.balanceText)
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    .padding(.vertical, AppTheme.spacingXS)
                    .tag(account.id)
                    .accessibilityIdentifier("ledger.account.\(accessibilitySlug(account.title))")
                }
            }
            .listStyle(.sidebar)
            .focusable()
            .focused($focusedPane, equals: .accounts)
        }
    }

    // MARK: - Transaction Pane (Table)

    private var transactionPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack(spacing: AppTheme.spacingS) {
                TextField("Search transactions", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)

                Menu(dateRange.title) {
                    ForEach(DateRangeFilter.allCases) { filter in
                        Button(filter.title) {
                            dateRange = filter
                        }
                    }
                }

                Menu(transactionScope.title) {
                    ForEach(LedgerTransactionScope.allCases) { scope in
                        Button(scope.title) {
                            onSetScope(scope)
                        }
                    }
                }
                .accessibilityIdentifier("ledger.scopeMenu")
            }
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.top, AppTheme.spacingM)

            if allTransactionsCount == 0 {
                centeredEmptyState(
                    PaneEmptyState(
                        "No transactions yet",
                        subtitle: "Import a statement to populate this account with reviewable rows.",
                        systemImage: "tablecells"
                    ) {
                        Button("Import Transactions", action: onImportCSV)
                            .buttonStyle(.borderedProminent)
                    }
                )
            } else if transactions.isEmpty {
                centeredEmptyState(
                    PaneEmptyState(
                        "No transactions in this scope",
                        subtitle: "The current review scope hides every row for this account.",
                        systemImage: "line.3.horizontal.decrease.circle"
                    ) {
                        Button("Show All", action: onResetScope)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("ledger.showAllButton")
                    }
                )
            } else if sortedTransactions.isEmpty {
                centeredEmptyState(
                    PaneEmptyState(
                        "No matching transactions",
                        subtitle: "Adjust the search text or date filter to restore rows.",
                        systemImage: "magnifyingglass"
                    )
                )
            } else {
                Table(of: ALDomain.Transaction.self, selection: $transactionSelection, sortOrder: $sortOrder) {
                    TableColumn("Date", value: \.bookingDate) { transaction in
                        Text(formattedDate(transaction.bookingDate))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .width(AppTheme.ledgerDateColumnWidth)

                    TableColumn("Description", value: \.counterpartyName) { transaction in
                        VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                            Text(transaction.counterpartyName)
                                .lineLimit(1)

                            if transaction.memo.isEmpty == false {
                                Text(transaction.memo)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .accessibilityLabel(transaction.counterpartyName)
                        .accessibilityValue("\(formattedDate(transaction.bookingDate)), \(amountString(transaction)), \(reviewLabel(transaction.reviewState))")
                        .accessibilityIdentifier("ledger.transaction.\(accessibilitySlug(transaction.counterpartyName))")
                    }
                    .width(min: AppTheme.ledgerCounterpartyMinWidth, ideal: AppTheme.ledgerCounterpartyIdealWidth)

                    TableColumn("Amount", value: \.amountMinor) { transaction in
                        Text(amountString(transaction))
                            .monospacedDigit()
                            .foregroundStyle(transaction.amountMinor >= 0 ? Color.green : .primary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .width(AppTheme.ledgerAmountColumnWidth)

                    TableColumn("Review", value: \.reviewState.rawValue) { transaction in
                        Text(reviewLabel(transaction.reviewState))
                            .font(AppTheme.metaFont)
                            .foregroundStyle(transaction.reviewState == .pending ? Color.orange : .secondary)
                    }
                    .width(AppTheme.ledgerReviewColumnWidth)
                } rows: {
                    ForEach(sortedTransactions) { transaction in
                        TableRow(transaction)
                    }
                }
                .focusable()
                .focused($focusedPane, equals: .transactions)
                .accessibilityIdentifier("ledger.transactions")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Inspector

    private var inspectorContent: some View {
        Group {
            if let selectedTransaction {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                        GroupBox("Transaction") {
                            VStack(alignment: .leading, spacing: AppTheme.inspectorRowSpacing) {
                                StatusBadge(reviewLabel(selectedTransaction.reviewState), tone: reviewTone(selectedTransaction.reviewState))
                                InspectorSectionRow(
                                    "Counterparty",
                                    value: selectedTransaction.counterpartyName,
                                    valueAccessibilityIdentifier: "ledger.inspector.counterparty"
                                )
                                InspectorSectionRow("Booked", value: formattedDate(selectedTransaction.bookingDate))
                                InspectorSectionRow("Amount", value: amountString(selectedTransaction))
                                if let reference = selectedTransaction.reference, reference.isEmpty == false {
                                    InspectorSectionRow("Reference", value: reference)
                                }
                                if selectedTransaction.memo.isEmpty == false {
                                    InspectorSectionRow("Memo", value: selectedTransaction.memo)
                                }
                            }
                        }

                        GroupBox("Linked Documents") {
                            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                if linkedDocuments.isEmpty {
                                    Text("Select Link Document to attach supporting evidence.")
                                        .font(AppTheme.metaFont)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(linkedDocuments, id: \.id) { document in
                                        DocumentReferenceRow(
                                            title: document.originalFilename,
                                            subtitle: documentTypeLabel(document.documentType),
                                            systemImage: "doc.text"
                                        )
                                    }
                                }

                                Button("Link Document\u{2026}", action: onLinkDocument)
                                    .buttonStyle(.borderedProminent)
                                    .accessibilityIdentifier("ledger.linkDocument")
                            }
                        }
                    }
                    .padding(AppTheme.contentPadding)
                }
            } else {
                Text("Select a transaction to inspect it.")
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, AppTheme.contentPadding)
                    .padding(.top, AppTheme.spacingS)
            }
        }
    }

    // MARK: - Computed Properties

    private var selectedAccount: LedgerAccountSummary? {
        accounts.first(where: { $0.id == selectedAccountId })
    }

    private var selectedTransaction: ALDomain.Transaction? {
        sortedTransactions.first(where: { $0.id == selectedTransactionId })
            ?? transactions.first(where: { $0.id == selectedTransactionId })
    }

    private var filteredTransactions: [ALDomain.Transaction] {
        transactions.filter { transaction in
            matchesSearch(transaction) && matchesDateRange(transaction.bookingDate)
        }
    }

    private var sortedTransactions: [ALDomain.Transaction] {
        filteredTransactions.sorted(using: sortOrder)
    }

    private var transactionSubtitle: String {
        guard let selectedAccount else {
            return "Select an account to review transactions."
        }
        return "\(filteredTransactions.count) shown of \(allTransactionsCount) \u{2022} \(selectedAccount.subtitle)"
    }

    private var accountSelection: Binding<FinancialAccountID?> {
        Binding(
            get: { selectedAccountId },
            set: { onSelectAccount($0) }
        )
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { isInspectorVisible },
            set: { _ in }
        )
    }

    // MARK: - Helpers

    private func centeredEmptyState<Content: View>(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private func focusPrimaryPane() {
        guard isActive, accounts.isEmpty == false else { return }
        Task { @MainActor in
            focusedPane = selectedAccountId == nil ? .accounts : .transactions
        }
    }

    private func matchesSearch(_ transaction: ALDomain.Transaction) -> Bool {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return true }
        return [
            transaction.counterpartyName,
            transaction.memo,
            transaction.reference ?? "",
        ]
        .joined(separator: "\n")
        .localizedCaseInsensitiveContains(trimmed)
    }

    private func matchesDateRange(_ date: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        switch dateRange {
        case .all:
            return true
        case .last30Days:
            guard let start = calendar.date(byAdding: .day, value: -30, to: .now) else { return true }
            return date >= start
        case .yearToDate:
            let start = calendar.date(from: calendar.dateComponents([.year], from: .now)) ?? .distantPast
            return date >= start
        }
    }

    private func amountString(_ transaction: ALDomain.Transaction) -> String {
        MoneyFormatter().format(minorUnits: transaction.amountMinor, currency: transaction.currency)
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

    private func documentTypeLabel(_ documentType: DocumentType) -> String {
        switch documentType {
        case .unknown:
            return "Unsorted"
        case .receipt:
            return "Receipt"
        case .invoice:
            return "Invoice"
        case .bankStatement:
            return "Statement"
        case .salaryCertificate:
            return "Salary Certificate"
        case .healthInsuranceCertificate:
            return "Health Insurance"
        case .pillar3aCertificate:
            return "Pillar 3a"
        }
    }
}
