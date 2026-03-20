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

                    if isInspectorVisible {
                        inspectorPane
                            .frame(minWidth: AppTheme.inspectorIdealWidth)
                            .transition(AppTheme.inspectorTransition(reduceMotion: reduceMotion))
                    }
                }
            }
        }
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
    }

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

    private var accountPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader("Accounts", subtitle: "Banks, cards, and other money sources.") {
                Button("Import Transactions", action: onImportCSV)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.top, AppTheme.spacingM)

            List(selection: accountSelection) {
                ForEach(accounts) { account in
                    HStack(alignment: .top, spacing: AppTheme.spacingS) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.accentSurfaceColor)
                                .frame(width: 36, height: 36)

                            Image(systemName: account.systemImage)
                                .symbolRenderingMode(AppTheme.symbolRenderingMode)
                                .foregroundStyle(Color.accentColor)
                        }

                        VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                            Text(account.title)
                                .font(.body.weight(.medium))

                            Text("\(account.accountTypeLabel) • \(account.subtitle)")
                                .font(AppTheme.metaFont)
                                .foregroundStyle(AppTheme.subduedForegroundColor)

                            StatusBadge(account.statusText, tone: account.tone)
                        }

                        Spacer(minLength: AppTheme.spacingS)

                        Text(account.balanceText)
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
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

    private var selectionPromptPane: some View {
        PaneEmptyState(
            "Select an account",
            subtitle: "Choose an account from the left to review transaction activity.",
            systemImage: "list.bullet.rectangle"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transactionPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader(selectedAccount?.title ?? "Transactions", subtitle: transactionSubtitle)
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

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
            } else if filteredTransactions.isEmpty {
                centeredEmptyState(
                    PaneEmptyState(
                        "No matching transactions",
                        subtitle: "Adjust the search text or date filter to restore rows.",
                        systemImage: "magnifyingglass"
                    )
                )
            } else {
                VStack(spacing: 0) {
                    transactionListHeader

                    ScrollView {
                        LazyVStack(spacing: AppTheme.spacingXS) {
                            ForEach(filteredTransactions) { transaction in
                                Button {
                                    onSelectTransaction(transaction.id)
                                } label: {
                                    transactionRow(transaction)
                                        .padding(.horizontal, AppTheme.spacingS)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background {
                                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                                .fill(
                                                    selectedTransactionId == transaction.id
                                                        ? AppTheme.accentSurfaceColor
                                                        : AppTheme.secondarySurfaceColor.opacity(0.35)
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .accessibilityLabel(transaction.counterpartyName)
                                .accessibilityValue("\(formattedDate(transaction.bookingDate)), \(amountString(transaction)), \(reviewLabel(transaction.reviewState))")
                                .accessibilityIdentifier("ledger.transaction.\(accessibilitySlug(transaction.counterpartyName))")
                            }
                        }
                        .padding(.vertical, AppTheme.spacingXXS)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .focusable()
                    .focused($focusedPane, equals: .transactions)
                    .accessibilityIdentifier("ledger.transactions")
                }
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.bottom, AppTheme.contentPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var inspectorPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader("Inspector", subtitle: "Details for the selected transaction.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

            if let selectedTransaction {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                        InspectorPane("Transaction", style: .card) {
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

                        InspectorPane("Linked Documents", style: .grouped) {
                            if linkedDocuments.isEmpty {
                                Text("Select Link Document to attach supporting evidence.")
                                    .font(AppTheme.metaFont)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                    ForEach(linkedDocuments, id: \.id) { document in
                                        DocumentReferenceRow(
                                            title: document.originalFilename,
                                            subtitle: documentTypeLabel(document.documentType),
                                            systemImage: "doc.text"
                                        )
                                    }
                                }
                            }

                            Button("Link Document…", action: onLinkDocument)
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("ledger.linkDocument")
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

    private var selectedAccount: LedgerAccountSummary? {
        accounts.first(where: { $0.id == selectedAccountId })
    }

    private var selectedTransaction: ALDomain.Transaction? {
        filteredTransactions.first(where: { $0.id == selectedTransactionId })
            ?? transactions.first(where: { $0.id == selectedTransactionId })
    }

    private var filteredTransactions: [ALDomain.Transaction] {
        transactions.filter { transaction in
            matchesSearch(transaction) && matchesDateRange(transaction.bookingDate)
        }
    }

    private var transactionSubtitle: String {
        guard let selectedAccount else {
            return "Select an account to review transactions."
        }
        return "\(filteredTransactions.count) shown of \(allTransactionsCount) • \(selectedAccount.subtitle)"
    }

    private var accountSelection: Binding<FinancialAccountID?> {
        Binding(
            get: { selectedAccountId },
            set: { onSelectAccount($0) }
        )
    }
    private func centeredEmptyState<Content: View>(_ content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var transactionListHeader: some View {
        HStack(spacing: AppTheme.spacingS) {
            Text("Date")
                .frame(width: AppTheme.ledgerDateColumnWidth, alignment: .leading)

            Text("Description")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Amount")
                .frame(width: AppTheme.ledgerAmountColumnWidth, alignment: .trailing)

            Text("Review")
                .frame(width: AppTheme.ledgerReviewColumnWidth, alignment: .leading)
        }
        .font(AppTheme.metaFont)
        .foregroundStyle(AppTheme.subduedForegroundColor)
        .padding(.horizontal, AppTheme.spacingS)
        .padding(.top, AppTheme.spacingXS)
        .padding(.bottom, AppTheme.spacingXXS)
    }

    private func transactionRow(_ transaction: ALDomain.Transaction) -> some View {
        HStack(alignment: .top, spacing: AppTheme.spacingS) {
            Text(formattedDate(transaction.bookingDate))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: AppTheme.ledgerDateColumnWidth, alignment: .leading)

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
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(amountString(transaction))
                .monospacedDigit()
                .foregroundStyle(transaction.amountMinor >= 0 ? Color.green : .primary)
                .frame(width: AppTheme.ledgerAmountColumnWidth, alignment: .trailing)

            Text(reviewLabel(transaction.reviewState))
                .font(AppTheme.metaFont)
                .foregroundStyle(transaction.reviewState == .pending ? Color.orange : .secondary)
                .frame(width: AppTheme.ledgerReviewColumnWidth, alignment: .leading)
        }
        .padding(.vertical, AppTheme.tableRowVerticalPadding)
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
        let value = Decimal(transaction.amountMinor) / 100
        return "\(NSDecimalNumber(decimal: value).stringValue) \(transaction.currency)"
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
