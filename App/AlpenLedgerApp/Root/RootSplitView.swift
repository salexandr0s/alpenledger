import AppKit
import SwiftUI
import ALDesignSystem
import ALDomain
import ALFeatures

struct RootSplitView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        Group {
            if model.hasWorkspace {
                workspaceShell
            } else {
                WorkspaceChooserView(
                    newWorkspaceName: $model.newWorkspaceName,
                    recentWorkspaces: model.recentWorkspaces,
                    onCreateWorkspace: model.createWorkspace,
                    onOpenWorkspace: model.openWorkspace,
                    onOpenExistingWorkspace: model.openExistingWorkspace
                )
            }
        }
        .sheet(isPresented: $model.isShowingNewWorkspaceSheet) {
            WorkspaceCreationSheetView(
                workspaceName: $model.newWorkspaceName,
                onCreateWorkspace: model.createWorkspace,
                onCancel: model.dismissNewWorkspaceSheet
            )
        }
    }

    private var workspaceShell: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .toolbar(content: shellToolbar)
        .animation(AppTheme.panelAnimation(reduceMotion: reduceMotion), value: model.selectedSection)
    }

    private var sidebarView: some View {
        List(selection: $model.selectedSection) {
            ForEach(AppSection.Group.allCases) { group in
                Section {
                    ForEach(group.sections) { section in
                        NavigationLink(value: section) {
                            SourceListRow(
                                title: section.title,
                                systemImage: section.systemImage,
                                badgeText: model.sidebarBadgeText(for: section)
                            )
                        }
                        .accessibilityIdentifier("nav.\(section.rawValue)")
                    }
                } header: {
                    Text(group.title)
                        .font(AppTheme.sidebarSectionHeaderFont)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(model.workspaceName)
        .navigationSplitViewColumnWidth(min: 210, ideal: AppTheme.sidebarIdealWidth, max: 280)
    }

    @ToolbarContentBuilder
    private func shellToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button("Toggle Sidebar", systemImage: "sidebar.leading", action: toggleSidebar)
                .accessibilityIdentifier("toolbar.toggleSidebar")
        }

        ToolbarItem(placement: .principal) {
            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(model.workspaceName)
                    .font(AppTheme.windowTitleFont)
                    .bold()
                    .contentTransition(.opacity)

                Text(model.currentSectionSubtitle)
                    .font(AppTheme.windowSubtitleFont)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        ToolbarItem {
            if model.selectedSection == .overview, let action = model.contextualToolbarAction {
                Button(action.title, systemImage: action.systemImage) {
                    model.performToolbarAction(action)
                }
                .disabled(model.canPerform(action) == false)
                .accessibilityIdentifier("toolbar.contextAction")
            }
        }

        ToolbarItem {
            Menu("Import", systemImage: "tray.and.arrow.down") {
                Button("Bank Statement CSV…", action: model.importCSVFromPanel)
                    .disabled(model.canImportCSV == false)

                Button("Document…", action: model.importDocumentFromPanel)
                    .disabled(model.canImportDocument == false)

                Divider()

                Button("Import Sample CSV", action: model.importSampleCSV)
                    .disabled(model.canImportSampleData == false)

                Button("Import Sample PDF", action: model.importSampleDocument)
                    .disabled(model.canImportSampleData == false)

                Button("Import Sample Data", action: model.importSampleData)
                    .disabled(model.canImportSampleData == false)
            }
            .accessibilityIdentifier("toolbar.importMenu")
        }

        if model.selectedSection == .ledger {
            ToolbarItemGroup {
                ToolbarAccessoryChip(
                    "Shown",
                    value: model.ledgerToolbarCountValue,
                    systemImage: "list.number",
                    accessibilityIdentifier: "toolbar.ledger.visibleCount"
                )

                Menu {
                    ForEach(LedgerTransactionScope.allCases) { scope in
                        Button(scope.title) {
                            model.setLedgerTransactionScope(scope)
                        }
                    }
                } label: {
                    Label(model.ledgerTransactionScope.title, systemImage: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(model.ledgerTransactionScope.title)
                .accessibilityIdentifier("toolbar.ledger.scope")

                Button("Import CSV", systemImage: "tablecells", action: model.importCSVFromPanel)
                    .disabled(model.canImportCSV == false)
                    .accessibilityIdentifier("toolbar.ledger.importCSV")

                Button(model.ledgerInspectorButtonTitle, systemImage: "sidebar.right") {
                    model.toggleLedgerInspector()
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel(model.ledgerInspectorButtonTitle)
                .accessibilityIdentifier("toolbar.ledger.toggleInspector")
            }
        }

        if model.selectedSection == .documents {
            ToolbarItemGroup {
                ToolbarAccessoryChip(
                    "Shown",
                    value: model.documentsToolbarCountValue,
                    systemImage: "doc.on.doc",
                    accessibilityIdentifier: "toolbar.documents.visibleCount"
                )

                Button("Import Document", systemImage: "plus", action: model.importDocumentFromPanel)
                    .disabled(model.canImportDocument == false)
                    .accessibilityIdentifier("toolbar.documents.import")

                Button(model.documentsInspectorButtonTitle, systemImage: "sidebar.right") {
                    model.toggleDocumentsInspector()
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel(model.documentsInspectorButtonTitle)
                .accessibilityIdentifier("toolbar.documents.toggleInspector")
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch model.selectedSection {
        case .overview:
            OverviewFeatureView(
                snapshot: model.overviewSnapshot,
                performAction: model.performOverviewAction
            )
        case .inbox:
            InboxFeatureView(
                selection: $model.selectedInboxSelection,
                importJobs: model.importJobs,
                proposals: model.agentProposals,
                issues: model.issues
            )
        case .ledger:
            LedgerFeatureView(
                accounts: model.financialAccounts,
                selectedAccountId: model.selectedAccountId,
                transactions: model.visibleTransactions,
                allTransactionsCount: model.transactionCount,
                transactionScope: model.ledgerTransactionScope,
                selectedTransactionId: model.selectedTransactionId,
                linkedDocuments: model.linkedDocuments,
                isInspectorVisible: model.isLedgerInspectorVisible,
                isActive: model.selectedSection == .ledger,
                onSelectAccount: model.selectAccount,
                onSelectTransaction: model.selectTransaction,
                onImportCSV: model.importCSVFromPanel,
                onResetScope: model.resetLedgerScope,
                onLinkDocument: model.presentDocumentLinkSheet
            )
        case .documents:
            DocumentsFeatureView(
                query: $model.documentSearchQuery,
                scope: Binding(
                    get: { model.documentFilterScope },
                    set: { model.setDocumentFilterScope($0) }
                ),
                documents: model.visibleDocuments,
                allDocumentsCount: model.documentCount,
                selectedDocumentId: model.selectedDocumentId,
                previewURL: model.selectedDocumentPreviewURL,
                linkedTransactions: model.linkedTransactions,
                isInspectorVisible: model.isDocumentsInspectorVisible,
                isActive: model.selectedSection == .documents,
                onSelectDocument: model.selectDocument,
                onImportDocument: model.importDocumentFromPanel,
                onRefreshSearchResults: model.filterDocuments,
                onClearSearch: model.clearDocumentSearch,
                onResetScope: model.resetDocumentScope,
                onLinkTransaction: model.presentTransactionLinkSheet
            )
        case .taxStudio:
            TaxStudioFeatureView(
                selectedEntityId: $model.selectedTaxEntityId,
                selectedTaxYearId: $model.selectedTaxYearId,
                selectedTaxFactId: $model.selectedTaxFactId,
                entities: model.entities,
                taxYears: model.taxYears,
                taxFacts: model.taxFacts,
                issues: model.taxIssues,
                requirements: model.taxRequirements,
                readinessSummary: model.taxReadinessSummary
            )
            .onChange(of: model.selectedTaxEntityId) { _, _ in
                model.selectTaxEntity(model.selectedTaxEntityId)
            }
            .onChange(of: model.selectedTaxYearId) { _, _ in
                model.selectTaxYear(model.selectedTaxYearId)
            }
        case .settings:
            SettingsFeatureView(
                newSolePropName: $model.newSolePropName,
                workspaceName: model.workspaceName,
                entities: model.entities,
                onCreateSoleProp: model.createSoleProp
            )
        }
    }

    private func toggleSidebar() {
        NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
    }
}

struct DocumentLinkSheet: View {
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        NavigationStack {
            List(model.documents, id: \.id) { document in
                Button {
                    model.linkSelectedDocumentToCurrentTransaction(documentId: document.id)
                } label: {
                    SourceListRow(
                        title: document.originalFilename,
                        subtitle: document.documentType.rawValue.capitalized,
                        systemImage: "doc.text"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sheet.document.\(accessibilitySlug(document.originalFilename))")
            }
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

struct TransactionLinkSheet: View {
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        NavigationStack {
            List(model.transactions, id: \.id) { transaction in
                Button {
                    model.linkCurrentDocumentToTransaction(transactionId: transaction.id)
                } label: {
                    SourceListRow(
                        title: transaction.counterpartyName,
                        subtitle: transaction.memo,
                        systemImage: "list.bullet.rectangle"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sheet.transaction.\(accessibilitySlug(transaction.counterpartyName))")
            }
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
