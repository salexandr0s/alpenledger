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
        switch style {
        case .grouped:
            groupedBody
        case .card:
            cardBody
        }
    }

    private var headerView: some View {
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
    }

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: AppTheme.inspectorRowSpacing) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var groupedBody: some View {
        GroupBox {
            if showsDivider {
                Divider()
            }
            contentBody
        } label: {
            headerView
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: AppTheme.inspectorSectionSpacing) {
            headerView

            if showsDivider {
                Divider()
            }

            contentBody
        }
        .padding(AppTheme.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(AppTheme.emphasizedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.strongStrokeColor, lineWidth: 1)
        )
    }
}
