import SwiftUI

public struct StatusBadge: View {
    private let title: String
    private let tint: Color
    private let accessibilityIdentifier: String?

    public init(_ title: String, tint: Color, accessibilityIdentifier: String? = nil) {
        self.title = title
        self.tint = tint
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public var body: some View {
        if let accessibilityIdentifier {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, AppTheme.spacingS)
                .padding(.vertical, AppTheme.spacingXS)
                .foregroundStyle(tint)
                .background(tint.opacity(0.15), in: Capsule())
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityLabel(title)
        } else {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, AppTheme.spacingS)
                .padding(.vertical, AppTheme.spacingXS)
                .foregroundStyle(tint)
                .background(tint.opacity(0.15), in: Capsule())
        }
    }
}
