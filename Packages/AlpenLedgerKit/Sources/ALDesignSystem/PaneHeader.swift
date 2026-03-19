import SwiftUI

public struct PaneHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    public init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingM) {
            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(title)
                    .font(.title3.weight(.semibold))

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                }
            }

            Spacer(minLength: AppTheme.spacingM)

            trailing
        }
    }
}

public extension PaneHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) {
            EmptyView()
        }
    }
}
