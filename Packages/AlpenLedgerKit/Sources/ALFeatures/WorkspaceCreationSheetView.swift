import SwiftUI
import ALDesignSystem

public struct WorkspaceCreationSheetView: View {
    @Binding private var workspaceName: String
    private let onCreateWorkspace: () -> Void
    private let onCancel: () -> Void

    public init(
        workspaceName: Binding<String>,
        onCreateWorkspace: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _workspaceName = workspaceName
        self.onCreateWorkspace = onCreateWorkspace
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingL) {
            PaneHeader("New Workspace", subtitle: "Create a new encrypted local workspace without leaving the current one.")

            WorkspaceCreationFormView(
                workspaceName: $workspaceName,
                title: "Create Workspace",
                detail: "The new workspace becomes active immediately after creation.",
                onCreateWorkspace: onCreateWorkspace
            )

            HStack {
                Spacer()

                Button("Cancel", role: .cancel, action: onCancel)
                    .accessibilityIdentifier("workspace.sheet.cancelButton")
            }
        }
        .padding(AppTheme.contentPadding)
        .frame(minWidth: 460, idealWidth: 480)
    }
}
