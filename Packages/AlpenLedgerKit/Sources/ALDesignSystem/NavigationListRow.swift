import SwiftUI

public struct NavigationListRow: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String
    private let detailText: String?

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        detailText: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.detailText = detailText
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingS) {
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
                        .lineLimit(2)
                }
            }

            Spacer(minLength: AppTheme.spacingS)

            if let detailText, detailText.isEmpty == false {
                Text(detailText)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, AppTheme.sidebarRowVerticalPadding)
        .contentShape(Rectangle())
    }
}
