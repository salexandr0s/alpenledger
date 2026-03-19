import Foundation
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
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AppTheme.spacingXL) {
                    reassuranceColumn
                        .frame(maxWidth: 420, alignment: .leading)

                    workspaceColumn
                        .frame(maxWidth: 460, alignment: .leading)
                }
                .frame(maxWidth: AppTheme.chooserMaxWidth, alignment: .leading)

                VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                    reassuranceColumn
                    workspaceColumn
                }
                .frame(maxWidth: AppTheme.chooserMaxWidth, alignment: .leading)
            }
            .padding(AppTheme.spacingXL)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .accessibilityIdentifier("workspace.chooser")
    }

    private var reassuranceColumn: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingL) {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.blue)

                Text("AlpenLedger")
                    .font(.largeTitle.weight(.bold))

                Text("A calm, local-first Swiss finance workspace for records, evidence, and filing readiness.")
                    .font(.title3)
                    .foregroundStyle(AppTheme.subduedForegroundColor)
            }

            InspectorPane("Why Start Here", subtitle: "The app behaves like a native document workspace rather than a cloud dashboard.") {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    reassuranceRow(
                        "Everything stays on this Mac by default.",
                        systemImage: "internaldrive"
                    )
                    reassuranceRow(
                        "Workspace data is encrypted and opened intentionally.",
                        systemImage: "key.horizontal"
                    )
                    reassuranceRow(
                        "Ledger, documents, and tax readiness stay grounded in the same local workspace.",
                        systemImage: "checklist"
                    )
                }
            }

            InspectorPane("Recent Workspaces", subtitle: "Open a workspace you used recently.") {
                if recentWorkspaces.isEmpty {
                    ContentUnavailableView("No Recent Workspaces", systemImage: "folder")
                } else {
                    VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                        ForEach(recentWorkspaces, id: \.workspaceId) { recent in
                            Button {
                                onOpenWorkspace(recent)
                            } label: {
                                VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                                    Text(recent.name)
                                        .foregroundStyle(.primary)

                                    Text(recent.path)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.subduedForegroundColor)

                                    Text(relativeDateString(for: recent.lastOpenedAt))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, AppTheme.spacingXXS)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var workspaceColumn: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingL) {
            WorkspaceCreationFormView(
                workspaceName: $newWorkspaceName,
                title: "Create Workspace",
                detail: "Start with a fresh encrypted workspace bundle for this Mac.",
                onCreateWorkspace: onCreateWorkspace
            )

            InspectorPane("Open Existing Workspace", subtitle: "Choose a workspace folder that already exists on disk.") {
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Text("Open an existing workspace when you want to continue working with a previously created bundle.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subduedForegroundColor)

                    Button("Open Existing Workspace…", action: onOpenExistingWorkspace)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("workspace.openExistingButton")
                }
            }
        }
    }

    @ViewBuilder
    private func reassuranceRow(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.body)
            .foregroundStyle(.primary)
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}
