import SwiftUI
import ALDomain
import ALDesignSystem

public struct SettingsFeatureView: View {
    @Binding private var newSolePropName: String
    private let workspaceName: String
    private let entities: [LegalEntity]
    private let onCreateSoleProp: () -> Void

    public init(
        newSolePropName: Binding<String>,
        workspaceName: String,
        entities: [LegalEntity],
        onCreateSoleProp: @escaping () -> Void
    ) {
        _newSolePropName = newSolePropName
        self.workspaceName = workspaceName
        self.entities = entities
        self.onCreateSoleProp = onCreateSoleProp
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                PaneHeader("Settings", subtitle: "Workspace-level controls and entity setup.")

                InspectorPane("Workspace", subtitle: "The active local workspace.") {
                    Text(workspaceName)
                }

                InspectorPane("Entities", subtitle: "Legal entities currently configured in this workspace.") {
                    ForEach(entities, id: \.id) { entity in
                        HStack {
                            Text(entity.displayName)
                            Spacer()
                            StatusBadge(entity.kind.rawValue, tone: .info)
                        }
                    }
                }

                InspectorPane("Add Sole Proprietor", subtitle: "Create a business entity without leaving the app shell.") {
                    HStack {
                        TextField("Business name", text: $newSolePropName)
                            .accessibilityIdentifier("settings.solePropNameField")
                        Button("Add", action: onCreateSoleProp)
                            .buttonStyle(.borderedProminent)
                            .disabled(newSolePropName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("settings.addSolePropButton")
                    }
                }
            }
            .padding(AppTheme.contentPadding)
        }
    }
}
