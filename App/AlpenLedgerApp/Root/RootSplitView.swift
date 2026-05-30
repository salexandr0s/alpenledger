import SwiftUI
import ALDesignSystem
import ALDomain
import ALFeatures

struct RootSplitView: View {
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        Group {
            if model.hasWorkspace {
                WorkspaceShellView(model: model)
            } else {
                WorkspaceChooserView(
                    snapshot: model.workspaceChooserSnapshot,
                    onCreateWorkspace: model.presentNewWorkspaceSheet,
                    onCreateDemoWorkspace: model.createDemoWorkspace,
                    onOpenWorkspace: { workspace in
                        model.openWorkspace(workspace.reference)
                    },
                    onOpenExistingWorkspace: model.openExistingWorkspace,
                    onShowHelp: model.presentHelpCenter
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
}
