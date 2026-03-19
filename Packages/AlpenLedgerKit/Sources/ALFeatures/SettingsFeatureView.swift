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
                Text("Settings")
                    .font(.largeTitle.weight(.bold))
                InspectorPane("Workspace") {
                    Text(workspaceName)
                }
                InspectorPane("Entities") {
                    ForEach(entities, id: \.id) { entity in
                        HStack {
                            Text(entity.displayName)
                            Spacer()
                            StatusBadge(entity.kind.rawValue, tint: .blue)
                        }
                    }
                }
                InspectorPane("Add Sole Proprietor") {
                    HStack {
                        TextField("Business name", text: $newSolePropName)
                        Button("Add", action: onCreateSoleProp)
                            .buttonStyle(.borderedProminent)
                            .disabled(newSolePropName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(24)
        }
    }
}
