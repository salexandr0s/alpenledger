import SwiftUI

public struct SourceListRow: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String
    private let badgeText: String?

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        badgeText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.badgeText = badgeText
    }

    public var body: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingS) {
            Image(systemName: systemImage)
                .symbolRenderingMode(AppTheme.symbolRenderingMode)
                .foregroundStyle(.secondary)
                .frame(width: AppTheme.sidebarRowIconWidth)

            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(title)
                    .font(AppTheme.sidebarTitleFont)
                    .lineLimit(1)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTheme.sidebarSubtitleFont)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: AppTheme.spacingS)

            if let badgeText, badgeText.isEmpty == false {
                SourceListBadge(badgeText)
            }
        }
        .padding(.vertical, AppTheme.sidebarRowVerticalPadding)
        .contentShape(Rectangle())
    }
}
