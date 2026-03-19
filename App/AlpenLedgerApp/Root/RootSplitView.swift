import SwiftUI
import ALFeatures

struct RootSplitView: View {
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        Group {
            if model.storage == nil {
                WorkspaceChooserView(
                    newWorkspaceName: $model.newWorkspaceName,
                    recentWorkspaces: model.recentWorkspaces,
                    onCreateWorkspace: model.createWorkspace,
                    onOpenWorkspace: model.openWorkspace,
                    onOpenExistingWorkspace: model.openExistingWorkspace
                )
            } else {
                NavigationSplitView {
                    List(AppSection.allCases, selection: $model.selectedSection) { section in
                        Label(section.title, systemImage: section.systemImage)
                            .tag(section)
                            .accessibilityIdentifier("nav.\(section.rawValue)")
                    }
                    .navigationTitle("AlpenLedger")
                } detail: {
                    switch model.selectedSection {
                    case .overview:
                        OverviewFeatureView(
                            workspaceName: model.workspaceName,
                            entityCount: model.entities.count,
                            accountCount: model.financialAccounts.count,
                            transactionCount: model.transactionCount,
                            documentCount: model.documentCount,
                            importJobCount: model.importJobs.count,
                            proposalCount: model.pendingProposalCount,
                            issueCount: model.openIssueCount,
                            onImportSampleCSV: model.importSampleCSV,
                            onImportSampleDocument: model.importSampleDocument,
                            onOpenInbox: model.openInbox
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
                            onSelectAccount: { accountId in
                                model.selectAccount(accountId)
                            },
                            onSelectTransaction: { transactionId in
                                model.selectTransaction(transactionId)
                            },
                            onImportCSV: {
                                model.importCSVFromPanel()
                            },
                            onLinkDocument: {
                                model.presentDocumentLinkSheet()
                            }
                        )
                    case .documents:
                        DocumentsFeatureView(
                            query: $model.documentSearchQuery,
                            documents: model.documents,
                            selectedDocumentId: model.selectedDocumentId,
                            previewURL: model.selectedDocumentPreviewURL,
                            linkedTransactions: model.linkedTransactions,
                            onSelectDocument: { documentId in
                                model.selectDocument(documentId)
                            },
                            onImportDocument: {
                                model.importDocumentFromPanel()
                            },
                            onLinkTransaction: {
                                model.presentTransactionLinkSheet()
                            }
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
            }
        }
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
