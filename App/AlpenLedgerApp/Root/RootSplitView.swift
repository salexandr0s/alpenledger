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
                    snapshot: model.workspaceChooserSnapshot,
                    onCreateWorkspace: model.presentNewWorkspaceSheet,
                    onOpenWorkspace: { workspace in
                        model.openWorkspace(workspace.reference)
                    },
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
                            NavigationListRow(
                                title: section.title,
                                systemImage: section.systemImage,
                                detailText: model.sidebarBadgeText(for: section)
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
        ToolbarItem(placement: .principal) {
            let configuration = model.shellToolbarConfiguration
            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(configuration.title)
                    .font(AppTheme.windowTitleFont)
                    .bold()
                    .contentTransition(.opacity)

                Text(configuration.subtitle)
                    .font(AppTheme.windowSubtitleFont)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        ToolbarItem {
            Menu("Import", systemImage: "tray.and.arrow.down") {
                Button("Bank Statement CSV…", action: model.importCSVFromPanel)
                    .disabled(model.canImportCSV == false)

                Button("Document…", action: model.importDocumentFromPanel)
                    .disabled(model.canImportDocument == false)

                Divider()

                Menu("Samples", systemImage: "sparkles.rectangle.stack") {
                    Button("Import Sample CSV", action: model.importSampleCSV)
                        .disabled(model.canImportSampleData == false)

                    Button("Import Sample PDF", action: model.importSampleDocument)
                        .disabled(model.canImportSampleData == false)

                    Button("Import Sample Data", action: model.importSampleData)
                        .disabled(model.canImportSampleData == false)
                }
            }
            .accessibilityIdentifier("toolbar.importMenu")
        }

        if let inspectorControl = model.shellToolbarConfiguration.inspectorControl {
            ToolbarItem {
                Button(inspectorControl.title, systemImage: "sidebar.right") {
                    model.performShellToolbarInspectorAction()
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel(inspectorControl.title)
                .accessibilityIdentifier(inspectorControl.accessibilityIdentifier)
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
                snapshot: model.inboxSnapshot,
                selection: $model.selectedInboxSelection,
                performAction: model.performInboxAction
            )
        case .ledger:
            LedgerFeatureView(
                accounts: model.ledgerAccountSummaries,
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
                onSetScope: model.setLedgerTransactionScope,
                onLinkDocument: model.presentDocumentLinkSheet
            )
        case .documents:
            DocumentsFeatureView(
                query: $model.documentSearchQuery,
                scope: Binding(
                    get: { model.documentFilterScope },
                    set: { model.setDocumentFilterScope($0) }
                ),
                items: model.documentBrowserItems,
                allDocumentsCount: model.documentCount,
                selectedDocumentId: model.selectedDocumentId,
                previewURL: model.selectedDocumentPreviewURL,
                linkedTransactions: model.linkedTransactions,
                isInspectorVisible: model.isDocumentsInspectorVisible,
                isActive: model.selectedSection == .documents,
                onSelectDocument: model.selectDocument,
                onImportDocument: model.importDocumentFromPanel,
                onImportDocuments: model.importDocumentURLs,
                onRefreshSearchResults: model.filterDocuments,
                onClearSearch: model.clearDocumentSearch,
                onResetScope: model.resetDocumentScope,
                onSetScope: model.setDocumentFilterScope,
                onLinkTransaction: model.presentTransactionLinkSheet
            )
        case .taxStudio:
            TaxStudioFeatureView(
                selectedEntityId: $model.selectedTaxEntityId,
                selectedTaxYearId: $model.selectedTaxYearId,
                selection: $model.selectedTaxStudioSelection,
                entities: model.entities,
                taxYears: model.taxYears,
                snapshot: model.taxStudioSnapshot
            )
            .onChange(of: model.selectedTaxEntityId) { _, _ in
                model.selectTaxEntity(model.selectedTaxEntityId)
            }
            .onChange(of: model.selectedTaxYearId) { _, _ in
                model.selectTaxYear(model.selectedTaxYearId)
            }
            .onChange(of: model.selectedTaxStudioSelection) { _, selection in
                model.selectTaxStudioSelection(selection)
            }
        case .settings:
            SettingsFeatureView(
                snapshot: model.settingsSnapshot,
                newSolePropName: $model.newSolePropName,
                onRenameWorkspace: model.renameWorkspace,
                onRenameEntity: model.updateEntityName,
                onRemoveEntity: model.removeEntity,
                onCreateSoleProp: model.createSoleProp
            )
        }
    }

}

struct DocumentLinkSheet: View {
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: AppTheme.spacingXS) {
                    ForEach(model.documents, id: \.id) { document in
                        Button {
                            model.linkSelectedDocumentToCurrentTransaction(documentId: document.id)
                        } label: {
                            SourceListRow(
                                title: document.originalFilename,
                                subtitle: document.documentType.rawValue.capitalized,
                                systemImage: "doc.text"
                            )
                            .padding(.horizontal, AppTheme.spacingS)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .fill(AppTheme.secondarySurfaceColor.opacity(0.35))
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel(document.originalFilename)
                        .accessibilityValue(document.documentType.rawValue.capitalized)
                        .accessibilityIdentifier("sheet.document.\(accessibilitySlug(document.originalFilename))")
                    }
                }
                .padding(AppTheme.contentPadding)
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
            ScrollView {
                LazyVStack(spacing: AppTheme.spacingXS) {
                    ForEach(model.transactions, id: \.id) { transaction in
                        Button {
                            model.linkCurrentDocumentToTransaction(transactionId: transaction.id)
                        } label: {
                            SourceListRow(
                                title: transaction.counterpartyName,
                                subtitle: transaction.memo,
                                systemImage: "list.bullet.rectangle"
                            )
                            .padding(.horizontal, AppTheme.spacingS)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .fill(AppTheme.secondarySurfaceColor.opacity(0.35))
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel(transaction.counterpartyName)
                        .accessibilityValue(transaction.memo)
                        .accessibilityIdentifier("sheet.transaction.\(accessibilitySlug(transaction.counterpartyName))")
                    }
                }
                .padding(AppTheme.contentPadding)
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
