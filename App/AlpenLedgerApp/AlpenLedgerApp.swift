import SwiftUI

@main
struct AlpenLedgerApp: App {
    @State private var model = WorkspaceAppModel(container: DependencyContainer())

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
