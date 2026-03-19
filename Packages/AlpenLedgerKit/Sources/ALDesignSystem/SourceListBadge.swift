import SwiftUI

public struct SourceListBadge: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(AppTheme.toolbarChipFont)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(.horizontal, AppTheme.spacingS)
            .padding(.vertical, AppTheme.spacingXXS)
            .background(AppTheme.sidebarBadgeFill, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.strokeColor, lineWidth: 1)
            )
            .contentTransition(.numericText())
            .animation(AppTheme.countAnimation, value: text)
    }
}
