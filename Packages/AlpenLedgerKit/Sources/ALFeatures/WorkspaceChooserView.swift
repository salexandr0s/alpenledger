import SwiftUI
import ALDesignSystem

public struct WorkspaceChooserView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let snapshot: WorkspaceChooserSnapshot
    private let onCreateWorkspace: () -> Void
    private let onOpenWorkspace: (WorkspaceChooserSnapshot.RecentWorkspace) -> Void
    private let onOpenExistingWorkspace: () -> Void

    public init(
        snapshot: WorkspaceChooserSnapshot,
        onCreateWorkspace: @escaping () -> Void,
        onOpenWorkspace: @escaping (WorkspaceChooserSnapshot.RecentWorkspace) -> Void,
        onOpenExistingWorkspace: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.onCreateWorkspace = onCreateWorkspace
        self.onOpenWorkspace = onOpenWorkspace
        self.onOpenExistingWorkspace = onOpenExistingWorkspace
    }

    public var body: some View {
        VStack(spacing: AppTheme.spacingXL) {
            Spacer(minLength: AppTheme.spacingXL)

            header

            recentWorkspacesCard

            actionRow

            Spacer(minLength: AppTheme.spacingXL)
        }
        .padding(AppTheme.contentPadding)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(AppTheme.chromeTransition(reduceMotion: reduceMotion))
        .navigationTitle("AlpenLedger")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.chooser")
    }

    private var header: some View {
        VStack(spacing: AppTheme.spacingM) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(AppTheme.symbolRenderingMode)

            VStack(spacing: AppTheme.spacingXS) {
                Text(snapshot.title)
                    .font(.system(size: 30, weight: .semibold))

                Text(snapshot.tagline)
                    .font(AppTheme.pageSubtitleFont)
                    .foregroundStyle(AppTheme.subduedForegroundColor)
                    .multilineTextAlignment(.center)

                Text(snapshot.trustLine)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recentWorkspacesCard: some View {
        GroupBox("Recent Workspaces") {
            if snapshot.recentWorkspaces.isEmpty {
                ContentUnavailableView(
                    "No recent workspaces",
                    systemImage: "folder",
                    description: Text("Create a workspace or open one from disk.")
                )
            } else {
                VStack(spacing: AppTheme.spacingXS) {
                    ForEach(snapshot.recentWorkspaces) { workspace in
                        Button {
                            onOpenWorkspace(workspace)
                        } label: {
                            HStack(spacing: AppTheme.spacingM) {
                                VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                                    Text(workspace.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Text(workspace.lastOpenedText)
                                        .font(AppTheme.metaFont)
                                        .foregroundStyle(AppTheme.subduedForegroundColor)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, AppTheme.spacingM)
                            .padding(.vertical, AppTheme.spacingS)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(workspace.title)
                        .accessibilityValue(workspace.lastOpenedText)
                        .accessibilityIdentifier("workspace.recent.\(accessibilitySlug(workspace.title))")
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: AppTheme.spacingM) {
            Button(action: onCreateWorkspace) {
                Text("Create New Workspace")
            }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Create New Workspace")
                .accessibilityIdentifier("workspace.createNewButton")

            Button(action: onOpenExistingWorkspace) {
                Text("Open Existing…")
            }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Open Existing")
                .accessibilityIdentifier("workspace.openExistingButton")
        }
    }
}
