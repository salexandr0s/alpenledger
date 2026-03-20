import SwiftUI

public struct PaneHeader<Trailing: View>: View {
    public enum Style: Sendable {
        case page
        case section
    }

    private let title: String
    private let subtitle: String?
    private let style: Style
    private let titleAccessibilityIdentifier: String?
    private let trailing: Trailing

    public init(
        _ title: String,
        subtitle: String? = nil,
        style: Style = .section,
        titleAccessibilityIdentifier: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingM) {
            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(title)
                    .font(titleFont)
                    .bold()
                    .accessibilityIdentifier(titleAccessibilityIdentifier ?? "")

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(subtitleFont)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                        .transition(.opacity)
                }
            }

            Spacer(minLength: AppTheme.spacingM)

            trailing
        }
    }

    private var titleFont: Font {
        switch style {
        case .page:
            return AppTheme.pageTitleFont
        case .section:
            return AppTheme.paneTitleFont
        }
    }

    private var subtitleFont: Font {
        switch style {
        case .page:
            return AppTheme.pageSubtitleFont
        case .section:
            return AppTheme.paneSubtitleFont
        }
    }
}

public extension PaneHeader where Trailing == EmptyView {
    init(
        _ title: String,
        subtitle: String? = nil,
        style: Style = .section,
        titleAccessibilityIdentifier: String? = nil
    ) {
        self.init(title, subtitle: subtitle, style: style, titleAccessibilityIdentifier: titleAccessibilityIdentifier) {
            EmptyView()
        }
    }
}
