import SwiftUI

public struct InspectorPane<Content: View>: View {
    public enum Style: Sendable {
        case grouped
        case card
    }

    private let title: String
    private let subtitle: String?
    private let style: Style
    private let showsDivider: Bool
    private let content: Content

    public init(
        _ title: String,
        subtitle: String? = nil,
        style: Style = .grouped,
        showsDivider: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.showsDivider = showsDivider
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

            if showsDivider {
                Divider()
            }

            VStack(alignment: .leading, spacing: AppTheme.inspectorRowSpacing) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(style == .card ? AppTheme.panelPadding : AppTheme.groupedPanelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var backgroundColor: Color {
        switch style {
        case .grouped:
            return AppTheme.subtleSurfaceColor
        case .card:
            return AppTheme.emphasizedSurfaceColor
        }
    }

    private var borderColor: Color {
        switch style {
        case .grouped:
            return AppTheme.strokeColor.opacity(0.6)
        case .card:
            return AppTheme.strongStrokeColor
        }
    }
}
