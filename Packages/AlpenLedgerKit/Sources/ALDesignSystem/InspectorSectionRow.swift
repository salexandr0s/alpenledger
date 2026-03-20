import SwiftUI

public struct InspectorSectionRow: View {
    private let title: String
    private let value: String
    private let systemImage: String?
    private let valueAccessibilityIdentifier: String?

    public init(
        _ title: String,
        value: String,
        systemImage: String? = nil,
        valueAccessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.valueAccessibilityIdentifier = valueAccessibilityIdentifier
    }

    public var body: some View {
        let content = HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacingM) {
            if let systemImage {
                Label(title, systemImage: systemImage)
                    .font(AppTheme.inspectorLabelFont)
                    .foregroundStyle(AppTheme.subduedForegroundColor)
                    .labelStyle(.titleAndIcon)
            } else {
                Text(title)
                    .font(AppTheme.inspectorLabelFont)
                    .foregroundStyle(AppTheme.subduedForegroundColor)
            }

            Spacer(minLength: AppTheme.spacingM)

            Text(value)
                .font(AppTheme.inspectorValueFont)
                .multilineTextAlignment(.trailing)
        }

        if let valueAccessibilityIdentifier {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(valueAccessibilityIdentifier)
                .accessibilityLabel(value)
                .accessibilityValue(value)
        } else {
            content
        }
    }
}
