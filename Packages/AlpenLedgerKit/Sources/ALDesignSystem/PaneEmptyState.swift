import SwiftUI

public struct PaneEmptyState<Actions: View>: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String
    private let actions: Actions

    public init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.actions = actions()
    }

    public var body: some View {
        VStack(spacing: AppTheme.emptyStateSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .symbolRenderingMode(AppTheme.symbolRenderingMode)
                .foregroundStyle(.secondary)

            VStack(spacing: AppTheme.spacingXXS) {
                Text(title)
                    .font(AppTheme.emptyStateTitleFont)
                    .multilineTextAlignment(.center)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTheme.emptyStateSubtitleFont)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: AppTheme.emptyStateActionSpacing) {
                actions
            }
        }
        .frame(maxWidth: AppTheme.emptyStateMaxWidth)
        .padding(AppTheme.contentPadding)
    }
}

public extension PaneEmptyState where Actions == EmptyView {
    init(_ title: String, subtitle: String? = nil, systemImage: String) {
        self.init(title, subtitle: subtitle, systemImage: systemImage) {
            EmptyView()
        }
    }
}
