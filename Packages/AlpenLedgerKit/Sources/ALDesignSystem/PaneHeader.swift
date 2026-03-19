import SwiftUI

public struct PaneHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let titleAccessibilityIdentifier: String?
    private let trailing: Trailing

    public init(
        _ title: String,
        subtitle: String? = nil,
        titleAccessibilityIdentifier: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingM) {
            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(title)
                    .font(AppTheme.paneTitleFont)
                    .bold()
                    .accessibilityIdentifier(titleAccessibilityIdentifier ?? "")

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTheme.paneSubtitleFont)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                        .transition(.opacity)
                }
            }

            Spacer(minLength: AppTheme.spacingM)

            trailing
        }
    }
}

public extension PaneHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, titleAccessibilityIdentifier: String? = nil) {
        self.init(title, subtitle: subtitle, titleAccessibilityIdentifier: titleAccessibilityIdentifier) {
            EmptyView()
        }
    }
}
