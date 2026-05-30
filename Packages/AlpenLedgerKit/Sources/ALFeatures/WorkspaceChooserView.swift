import SwiftUI
import ALDesignSystem

public struct WorkspaceChooserView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let snapshot: WorkspaceChooserSnapshot
    private let onCreateWorkspace: () -> Void
    private let onCreateDemoWorkspace: () -> Void
    private let onOpenWorkspace: (WorkspaceChooserSnapshot.RecentWorkspace) -> Void
    private let onOpenExistingWorkspace: () -> Void
    private let onShowHelp: () -> Void

    public init(
        snapshot: WorkspaceChooserSnapshot,
        onCreateWorkspace: @escaping () -> Void,
        onCreateDemoWorkspace: @escaping () -> Void,
        onOpenWorkspace: @escaping (WorkspaceChooserSnapshot.RecentWorkspace) -> Void,
        onOpenExistingWorkspace: @escaping () -> Void,
        onShowHelp: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.onCreateWorkspace = onCreateWorkspace
        self.onCreateDemoWorkspace = onCreateDemoWorkspace
        self.onOpenWorkspace = onOpenWorkspace
        self.onOpenExistingWorkspace = onOpenExistingWorkspace
        self.onShowHelp = onShowHelp
    }

    public var body: some View {
        VStack(spacing: AppTheme.spacingXL) {
            Spacer(minLength: AppTheme.spacingXL)

            header

            if snapshot.recentWorkspaces.isEmpty {
                onboardingCard
            }

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
                            .contentShape(Rectangle())
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

    private var onboardingCard: some View {
        GroupBox("First Run") {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                ForEach(snapshot.onboardingItems) { item in
                    HStack(alignment: .top, spacing: AppTheme.spacingS) {
                        Image(systemName: item.systemImage)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.body.weight(.medium))
                            Text(item.detail)
                                .font(AppTheme.metaFont)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("workspace.onboarding.\(item.id)")
                }
            }
            .padding(.top, AppTheme.spacingXXS)
        }
        .accessibilityIdentifier("workspace.onboarding")
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

            Button(action: onCreateDemoWorkspace) {
                Text("Create Demo")
            }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Create Demo Workspace")
                .accessibilityIdentifier("workspace.createDemoButton")

            Button(action: onShowHelp) {
                Label("Help", systemImage: "questionmark.circle")
            }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Open Help")
                .accessibilityIdentifier("workspace.openHelpButton")
        }
    }
}
