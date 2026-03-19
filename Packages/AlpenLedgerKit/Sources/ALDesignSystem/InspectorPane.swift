import SwiftUI

public struct InspectorPane<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let content: Content

    public init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.inspectorSectionSpacing) {
            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(title)
                    .font(AppTheme.paneTitleFont)
                    .bold()

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTheme.paneSubtitleFont)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: AppTheme.inspectorRowSpacing) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppTheme.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(AppTheme.elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.strokeColor, lineWidth: 1)
        )
    }
}
