import SwiftUI

public struct StatusBadge: View {
    private let title: String
    private let tint: Color

    public init(_ title: String, tint: Color) {
        self.title = title
        self.tint = tint
    }

    public var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppTheme.spacingS)
            .padding(.vertical, AppTheme.spacingXS)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
    }
}
