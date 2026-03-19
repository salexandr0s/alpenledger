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
        GroupBox {
            VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppTheme.spacingXS)
        } label: {
            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(title)
                    .font(.headline)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                }
            }
        }
        .groupBoxStyle(.automatic)
    }
}
