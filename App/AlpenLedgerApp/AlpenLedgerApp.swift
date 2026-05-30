import SwiftUI
import ALFeatures

@main
struct AlpenLedgerApp: App {
    @State private var model: WorkspaceAppModel

    init() {
        _model = State(initialValue: WorkspaceAppModel(container: .live()))
    }

    var body: some Scene {
        WindowGroup {
            RootSplitView(model: model)
                .frame(minWidth: 1200, minHeight: 720)
                .alert(model.errorTitle, isPresented: $model.isShowingErrorAlert) {
                    Button("OK", role: .cancel) {
                        model.dismissErrorAlert()
                    }
                } message: {
                    Text(model.errorAlertBody)
                }
                .sheet(isPresented: $model.isShowingDocumentLinkSheet) {
                    DocumentLinkSheet(model: model)
                }
                .sheet(isPresented: $model.isShowingTransactionLinkSheet) {
                    TransactionLinkSheet(model: model)
                }
                .sheet(isPresented: $model.isShowingHelpCenter) {
                    HelpCenterView(
                        snapshot: model.helpCenterSnapshot,
                        onDismiss: model.dismissHelpCenter
                    )
                }
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            WorkspaceCommandMenu(model: model)
            SelectionCommandMenu(model: model)
            ViewCommandMenu(model: model)
            HelpCommandMenu(model: model)
            SidebarCommands()
        }
    }

}

private struct WorkspaceCommandMenu: Commands {
    let model: WorkspaceAppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Workspace…", action: model.presentNewWorkspaceSheet)
                .keyboardShortcut("n", modifiers: [.command])

            Button("New Demo Workspace", action: model.createDemoWorkspace)
        }

        CommandGroup(after: .newItem) {
            Button("Open Workspace…", action: model.openExistingWorkspace)
                .keyboardShortcut("o", modifiers: [.command])

            Button("Close Workspace", action: model.closeCurrentWorkspace)
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(model.canCloseCurrentWorkspace == false)

            Button("Lock Workspace", action: model.lockCurrentWorkspace)
                .keyboardShortcut("l", modifiers: [.command, .control])
                .disabled(model.canLockCurrentWorkspace == false)

            Divider()

            Button("Import Bank Statement CSV…", action: model.importCSVFromPanel)
                .disabled(model.canImportCSV == false)

            Button("Import Document…", action: model.importDocumentFromPanel)
                .disabled(model.canImportDocument == false)

            Divider()

            Button("Create Backup…", action: model.createBackupFromPanel)
                .disabled(model.canCreateBackup == false)

            Button("Check Backup Integrity…", action: model.validateBackupFromPanel)
                .disabled(model.canValidateBackup == false)

            Button("Restore Backup…", action: model.restoreBackupFromPanel)
                .disabled(model.canRestoreBackup == false)

            Button("Export Diagnostics…", action: model.exportDiagnosticsFromPanel)
                .disabled(model.canExportDiagnostics == false)

            Button("Export Support Bundle…", action: model.exportSupportBundleFromPanel)
                .disabled(model.canExportSupportBundle == false)

            Divider()

            Button("Delete Current Workspace…", action: model.deleteCurrentWorkspaceFromPanel)
                .disabled(model.canDeleteCurrentWorkspace == false)

            Divider()

            Button("Import Sample CSV", action: model.importSampleCSV)
                .disabled(model.canImportSampleData == false)

            Button("Import Sample PDF", action: model.importSampleDocument)
                .disabled(model.canImportSampleData == false)

            Button("Import Sample Data", action: model.importSampleData)
                .disabled(model.canImportSampleData == false)

#if DEBUG
            if model.shouldShowQAValidationFixturesCommand {
                Divider()

                Button("Import QA Validation Fixtures", action: model.importQAValidationFixtures)
                    .disabled(model.canImportQAValidationFixtures == false)
            }
#endif
        }

        CommandMenu("Go") {
            ForEach(AppSection.allCases) { section in
                Button(section.commandTitle) {
                    model.navigate(to: section)
                }
                .keyboardShortcut(section.keyboardShortcut, modifiers: [.command])
                .disabled(model.hasWorkspace == false)
            }
        }
    }
}

private struct SelectionCommandMenu: Commands {
    let model: WorkspaceAppModel

    var body: some Commands {
        CommandMenu("Selection") {
            Button("Link Document…", action: model.presentDocumentLinkSheet)
                .disabled(model.canLinkSelectedDocument == false)

            Button("Link Transaction…", action: model.presentTransactionLinkSheet)
                .disabled(model.canLinkSelectedTransaction == false)
        }
    }
}

private struct ViewCommandMenu: Commands {
    let model: WorkspaceAppModel

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Find in Workspace", action: model.presentGlobalSearch)
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(model.canUseGlobalSearch == false)

            Button(model.activeInspectorToggleTitle, action: model.toggleInspectorForActiveSection)
                .keyboardShortcut("0", modifiers: [.command, .option])
                .disabled(model.canToggleActiveInspector == false)
        }
    }
}

private struct HelpCommandMenu: Commands {
    let model: WorkspaceAppModel

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("AlpenLedger Help", action: model.presentHelpCenter)
                .keyboardShortcut("?", modifiers: [.command])
        }
    }
}
