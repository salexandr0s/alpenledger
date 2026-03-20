import SwiftUI

public struct WorkItemRow: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String
    private let statusTitle: String?
    private let tone: StatusBadge.Tone

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        statusTitle: String? = nil,
        tone: StatusBadge.Tone = .neutral
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.statusTitle = statusTitle
        self.tone = tone
    }

    public var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingS) {
            Image(systemName: systemImage)
                .symbolRenderingMode(AppTheme.symbolRenderingMode)
                .foregroundStyle(tone == .critical ? Color.red : Color.secondary)
                .frame(width: AppTheme.sidebarRowIconWidth)

            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                Text(title)
                    .font(.body)
                    .lineLimit(2)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTheme.metaFont)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: AppTheme.spacingS)

            if let statusTitle, statusTitle.isEmpty == false {
                StatusBadge(statusTitle, tone: tone)
            }
        }
        .contentShape(Rectangle())
    }
}
