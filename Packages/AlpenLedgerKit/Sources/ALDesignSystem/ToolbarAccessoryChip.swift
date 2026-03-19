import SwiftUI

public struct ToolbarAccessoryChip: View {
    private let title: String
    private let value: String
    private let systemImage: String?
    private let accessibilityIdentifier: String?
    private let accessibilityLabel: String?

    public init(
        _ title: String,
        value: String,
        systemImage: String? = nil,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let content = HStack(spacing: AppTheme.spacingXS) {
            if let systemImage {
                Image(systemName: systemImage)
                    .symbolRenderingMode(AppTheme.symbolRenderingMode)
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .foregroundStyle(.secondary)

            Text(value)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(AppTheme.toolbarChipFont)
        .padding(.horizontal, AppTheme.toolbarChipHorizontalPadding)
        .padding(.vertical, AppTheme.toolbarChipVerticalPadding)
        .background(AppTheme.toolbarChipFill, in: Capsule())
        .overlay(
            Capsule()
                .stroke(AppTheme.strokeColor, lineWidth: 1)
        )
        .animation(AppTheme.countAnimation, value: value)

        if let accessibilityIdentifier {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityLabel(accessibilityLabel ?? "\(title) \(value)")
        } else {
            content
        }
    }
}
