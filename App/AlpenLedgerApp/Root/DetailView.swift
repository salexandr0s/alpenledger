import SwiftUI
import ALDesignSystem
import ALDomain
import ALFeatures

struct DetailView: View {
    @Bindable var model: WorkspaceAppModel

    var body: some View {
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
        case .copilot:
            CopilotFeatureView(
                snapshot: model.copilotSnapshot,
                performAction: model.performCopilotAction
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
                scope: $model.documentFilterScope,
                items: model.documentBrowserItems,
                allDocumentsCount: model.documentVaultCount,
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
                onLinkTransaction: model.presentTransactionLinkSheet,
                onArchiveDocument: model.archiveSelectedDocumentFromPanel,
                onRestoreDocument: model.restoreSelectedDocumentFromPanel,
                onReviewMetadata: model.reviewDocumentMetadata
            )
        case .taxStudio:
            TaxStudioFeatureView(
                selectedEntityId: $model.selectedTaxEntityId,
                selectedTaxYearId: $model.selectedTaxYearId,
                selection: $model.selectedTaxStudioSelection,
                entities: model.entities,
                taxYears: model.taxYears,
                snapshot: model.taxStudioSnapshot,
                onLockTaxYear: model.lockSelectedTaxYear,
                onUnlockTaxYear: model.unlockSelectedTaxYear
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
                onSetWorkspaceLockEnabled: model.setWorkspaceLockEnabled,
                onLockWorkspace: model.lockCurrentWorkspace,
                onCreateBackup: model.createBackupFromPanel,
                onValidateBackup: model.validateBackupFromPanel,
                onRestoreBackup: model.restoreBackupFromPanel,
                onSetDefaultImportAccount: model.setDefaultStatementImportAccount,
                onShowHelp: model.presentHelpCenter,
                onExportDiagnostics: model.exportDiagnosticsFromPanel,
                onExportSupportBundle: model.exportSupportBundleFromPanel,
                onDeleteWorkspace: model.deleteCurrentWorkspaceFromPanel,
                onRenameEntity: model.updateEntityName,
                onRemoveEntity: model.removeEntity,
                onCreateSoleProp: model.createSoleProp
            )
        }
    }
}
