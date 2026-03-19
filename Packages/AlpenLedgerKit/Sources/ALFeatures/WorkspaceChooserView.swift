import SwiftUI
import ALDomain
import ALWorkspace
import ALDesignSystem

public struct WorkspaceChooserView: View {
    @Binding private var newWorkspaceName: String
    private let recentWorkspaces: [RecentWorkspaceReference]
    private let onCreateWorkspace: () -> Void
    private let onOpenWorkspace: (RecentWorkspaceReference) -> Void
    private let onOpenExistingWorkspace: () -> Void

    public init(
        newWorkspaceName: Binding<String>,
        recentWorkspaces: [RecentWorkspaceReference],
        onCreateWorkspace: @escaping () -> Void,
        onOpenWorkspace: @escaping (RecentWorkspaceReference) -> Void,
        onOpenExistingWorkspace: @escaping () -> Void
    ) {
        _newWorkspaceName = newWorkspaceName
        self.recentWorkspaces = recentWorkspaces
        self.onCreateWorkspace = onCreateWorkspace
        self.onOpenWorkspace = onOpenWorkspace
        self.onOpenExistingWorkspace = onOpenExistingWorkspace
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingL) {
            Text("AlpenLedger")
                .font(.largeTitle.weight(.bold))
            Text("Create or open an encrypted local workspace.")
                .foregroundStyle(.secondary)

            InspectorPane("Create Workspace") {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    TextField("Workspace name", text: $newWorkspaceName)
                    Button("Create Workspace", action: onCreateWorkspace)
                        .buttonStyle(.borderedProminent)
                        .disabled(newWorkspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            InspectorPane("Recent Workspaces") {
                if recentWorkspaces.isEmpty {
                    Text("No recent workspaces yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentWorkspaces, id: \.workspaceId) { recent in
                        Button {
                            onOpenWorkspace(recent)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recent.name)
                                Text(recent.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button("Open Existing Workspace…", action: onOpenExistingWorkspace)
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding(32)
        .frame(minWidth: 720, minHeight: 480, alignment: .topLeading)
    }
}
