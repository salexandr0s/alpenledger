import SwiftUI
import ALDesignSystem
import ALDomain
import ALFeatures

struct WorkspaceShellView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            DetailView(model: model)
        }
        .toolbar(content: shellToolbar)
        .animation(AppTheme.panelAnimation(reduceMotion: reduceMotion), value: model.selectedSection)
    }

    @ToolbarContentBuilder
    private func shellToolbar() -> some ToolbarContent {
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
}
