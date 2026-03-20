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
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.windowChromeColor,
                    AppTheme.secondarySurfaceColor.opacity(0.75),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.chooser")
    }

    private var header: some View {
        VStack(spacing: AppTheme.spacingM) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSurfaceColor)
                    .frame(width: 72, height: 72)

                Image(systemName: "checkmark.shield")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .symbolRenderingMode(AppTheme.symbolRenderingMode)
            }

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
        InspectorPane(
            "Recent Workspaces",
            subtitle: snapshot.recentWorkspaces.isEmpty ? "Create your first workspace to get started." : "Pick up where you left off.",
            style: .card,
            showsDivider: snapshot.recentWorkspaces.isEmpty == false
        ) {
            if snapshot.recentWorkspaces.isEmpty {
                PaneEmptyState(
                    "No recent workspaces",
                    subtitle: "Create a workspace or open one from disk.",
                    systemImage: "folder"
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
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .fill(AppTheme.subtleSurfaceColor)
                            )
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
