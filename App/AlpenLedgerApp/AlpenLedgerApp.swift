import SwiftUI

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
                .alert("Error", isPresented: $model.isShowingErrorAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(model.errorMessage ?? "Unknown error")
                }
                .sheet(isPresented: $model.isShowingDocumentLinkSheet) {
                    DocumentLinkSheet(model: model)
                }
                .sheet(isPresented: $model.isShowingTransactionLinkSheet) {
                    TransactionLinkSheet(model: model)
                }
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            WorkspaceCommandMenu(model: model)
            SelectionCommandMenu(model: model)
            ViewCommandMenu(model: model)
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
        }

        CommandGroup(after: .newItem) {
            Button("Open Workspace…", action: model.openExistingWorkspace)
                .keyboardShortcut("o", modifiers: [.command])
            Divider()

            Button("Import Bank Statement CSV…", action: model.importCSVFromPanel)
                .disabled(model.canImportCSV == false)

            Button("Import Document…", action: model.importDocumentFromPanel)
                .disabled(model.canImportDocument == false)

            Divider()

            Button("Import Sample CSV", action: model.importSampleCSV)
                .disabled(model.canImportSampleData == false)

            Button("Import Sample PDF", action: model.importSampleDocument)
                .disabled(model.canImportSampleData == false)

            Button("Import Sample Data", action: model.importSampleData)
                .disabled(model.canImportSampleData == false)

#if DEBUG
            Divider()

            Button("Import QA Validation Fixtures", action: model.importQAValidationFixtures)
                .disabled(model.hasWorkspace == false)
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
            Button(model.activeInspectorToggleTitle, action: model.toggleInspectorForActiveSection)
                .keyboardShortcut("0", modifiers: [.command, .option])
                .disabled(model.canToggleActiveInspector == false)
        }
    }
}
