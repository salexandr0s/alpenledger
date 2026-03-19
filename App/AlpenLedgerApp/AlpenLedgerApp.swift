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
                .alert("Error", isPresented: errorPresentedBinding) {
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
            SidebarCommands()
        }
    }

    private var errorPresentedBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    model.errorMessage = nil
                }
            }
        )
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
