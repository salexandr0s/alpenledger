import SwiftUI
import ALDesignSystem

public struct WorkspaceCreationFormView: View {
    @Binding private var workspaceName: String
    private let title: String
    private let detail: String
    private let createLabel: String
    private let onCreateWorkspace: () -> Void

    public init(
        workspaceName: Binding<String>,
        title: String,
        detail: String,
        createLabel: String = "Create Workspace",
        onCreateWorkspace: @escaping () -> Void
    ) {
        _workspaceName = workspaceName
        self.title = title
        self.detail = detail
        self.createLabel = createLabel
        self.onCreateWorkspace = onCreateWorkspace
    }

    public var body: some View {
        InspectorPane(title, subtitle: detail) {
            VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    Text("Workspace Name")
                        .font(.headline)

                    TextField("Workspace name", text: $workspaceName)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("workspace.nameField")
                        .onSubmit(onCreateWorkspace)
                }

                Text("Creates an encrypted local workspace with a default personal entity.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.subduedForegroundColor)

                Button(createLabel, action: onCreateWorkspace)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedWorkspaceName.isEmpty)
                    .accessibilityIdentifier("workspace.createButton")
            }
        }
    }

    private var trimmedWorkspaceName: String {
        workspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
