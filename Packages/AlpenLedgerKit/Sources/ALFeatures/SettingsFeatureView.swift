import SwiftUI
import ALDomain
import ALDesignSystem

public struct SettingsFeatureView: View {
    @Binding private var newSolePropName: String
    @State private var workspaceDraftName = ""

    private let snapshot: SettingsSnapshot
    private let onRenameWorkspace: (String) -> Void
    private let onRenameEntity: (LegalEntityID, String) -> Void
    private let onRemoveEntity: (LegalEntityID) -> Void
    private let onCreateSoleProp: () -> Void

    public init(
        snapshot: SettingsSnapshot,
        newSolePropName: Binding<String>,
        onRenameWorkspace: @escaping (String) -> Void,
        onRenameEntity: @escaping (LegalEntityID, String) -> Void,
        onRemoveEntity: @escaping (LegalEntityID) -> Void,
        onCreateSoleProp: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        _newSolePropName = newSolePropName
        self.onRenameWorkspace = onRenameWorkspace
        self.onRenameEntity = onRenameEntity
        self.onRemoveEntity = onRemoveEntity
        self.onCreateSoleProp = onCreateSoleProp
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                PaneHeader("Settings", subtitle: "Workspace metadata, entity setup, and local data controls.", style: .page)

                workspaceCard
                entitiesCard
                addEntityCard
            }
            .padding(AppTheme.contentPadding)
        }
        .onAppear {
            workspaceDraftName = snapshot.workspace.name
        }
        .onChange(of: snapshot.workspace.name) { _, newValue in
            workspaceDraftName = newValue
        }
    }

    private var workspaceCard: some View {
        InspectorPane("Workspace", subtitle: "Core workspace details and trust settings.", style: .card) {
            HStack(spacing: AppTheme.spacingS) {
                TextField("Workspace name", text: $workspaceDraftName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings.workspaceNameField")

                Button("Save") {
                    onRenameWorkspace(workspaceDraftName)
                }
                .buttonStyle(.borderedProminent)
                .disabled(workspaceDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("settings.renameWorkspaceButton")
            }

            InspectorSectionRow("Type", value: snapshot.workspace.type)
            InspectorSectionRow("Location", value: snapshot.workspace.location)
            InspectorSectionRow("Encryption", value: snapshot.workspace.encryptionStatus)
            InspectorSectionRow("Created", value: snapshot.workspace.createdAt)
        }
    }

    private var entitiesCard: some View {
        InspectorPane("Entities", subtitle: "Manage the people and businesses inside this workspace.", style: .card) {
            if snapshot.entities.isEmpty {
                Text("No entities configured.")
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                    ForEach(snapshot.entities) { entity in
                        EntityEditorRow(
                            entity: entity,
                            onRename: onRenameEntity,
                            onRemove: onRemoveEntity
                        )
                    }
                }
            }
        }
    }

    private var addEntityCard: some View {
        InspectorPane("Add Entity", subtitle: "Create a sole proprietorship without leaving the workspace.", style: .card) {
            HStack(spacing: AppTheme.spacingS) {
                TextField("Business name", text: $newSolePropName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings.solePropNameField")

                Button("Add Sole Proprietor", action: onCreateSoleProp)
                    .buttonStyle(.borderedProminent)
                    .disabled(newSolePropName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("settings.addSolePropButton")
            }
        }
    }
}

private struct EntityEditorRow: View {
    @State private var draftName: String

    private let entity: EntityRowModel
    private let onRename: (LegalEntityID, String) -> Void
    private let onRemove: (LegalEntityID) -> Void

    init(
        entity: EntityRowModel,
        onRename: @escaping (LegalEntityID, String) -> Void,
        onRemove: @escaping (LegalEntityID) -> Void
    ) {
        self.entity = entity
        self.onRename = onRename
        self.onRemove = onRemove
        _draftName = State(initialValue: entity.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack(spacing: AppTheme.spacingS) {
                TextField("Entity name", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings.entity.name.\(accessibilitySlug(entity.name))")

                Button("Save") {
                    onRename(entity.id, draftName)
                }
                .buttonStyle(.bordered)
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("settings.entity.save.\(accessibilitySlug(entity.name))")

                Button("Remove") {
                    onRemove(entity.id)
                }
                .buttonStyle(.bordered)
                .disabled(entity.canRemove == false)
                .accessibilityIdentifier("settings.entity.remove.\(accessibilitySlug(entity.name))")
            }

            Text("\(entity.kindLabel) • \(entity.detail)")
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)

            if let removalHint = entity.removalHint {
                Text(removalHint)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppTheme.groupedPanelPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(AppTheme.subtleSurfaceColor)
        )
    }
}
