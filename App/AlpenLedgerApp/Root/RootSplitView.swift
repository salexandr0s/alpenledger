import AppKit
import SwiftUI
import ALDesignSystem
import ALDomain
import ALFeatures

struct RootSplitView: View {
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
    }

    private var sidebarView: some View {
        List(selection: $model.selectedSection) {
            ForEach(AppSection.Group.allCases) { group in
                Section(group.title) {
                    ForEach(group.sections) { section in
                        NavigationLink(value: section) {
                            HStack(spacing: AppTheme.spacingS) {
                                Label(section.title, systemImage: section.systemImage)

                                Spacer(minLength: AppTheme.spacingS)

                                if let badge = model.sidebarBadgeText(for: section) {
                                    Text(badge)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("nav.\(section.rawValue)")
                    }
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
        }

        ToolbarItem(placement: .principal) {
            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(model.workspaceName)
                    .font(.headline)

                Text(model.currentSectionSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

                Button("Import Sample CSV", action: model.importSampleCSV)
                    .disabled(model.canImportSampleData == false)

                Button("Import Sample PDF", action: model.importSampleDocument)
                    .disabled(model.canImportSampleData == false)

                Button("Import Sample Data", action: model.importSampleData)
                    .disabled(model.canImportSampleData == false)
            }
        }

        ToolbarItem {
            if let action = model.contextualToolbarAction {
                Button(action.title, systemImage: action.systemImage) {
                    model.performToolbarAction(action)
                }
                .disabled(model.canPerform(action) == false)
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
                transactions: model.transactions,
                selectedTransactionId: model.selectedTransactionId,
                linkedDocuments: model.linkedDocuments,
                onSelectAccount: model.selectAccount,
                onSelectTransaction: model.selectTransaction,
                onImportCSV: model.importCSVFromPanel,
                onLinkDocument: model.presentDocumentLinkSheet
            )
        case .documents:
            DocumentsFeatureView(
                query: $model.documentSearchQuery,
                documents: model.documents,
                selectedDocumentId: model.selectedDocumentId,
                previewURL: model.selectedDocumentPreviewURL,
                linkedTransactions: model.linkedTransactions,
                onSelectDocument: model.selectDocument,
                onImportDocument: model.importDocumentFromPanel,
                onLinkTransaction: model.presentTransactionLinkSheet
            )
            .onChange(of: model.documentSearchQuery) { _, _ in
                model.filterDocuments()
            }
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
                Button(document.originalFilename) {
                    model.linkSelectedDocumentToCurrentTransaction(documentId: document.id)
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
                Button(transaction.counterpartyName) {
                    model.linkCurrentDocumentToTransaction(transactionId: transaction.id)
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
