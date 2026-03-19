import SwiftUI

public struct SummaryTile: View {
    private let title: String
    private let value: String
    private let subtitle: String?
    private let tone: StatusBadge.Tone
    private let systemImage: String
    private let accessibilityIdentifier: String?
    private let accessibilityLabel: String?

    public init(
        _ title: String,
        value: String,
        subtitle: String? = nil,
        tone: StatusBadge.Tone = .neutral,
        systemImage: String,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.tone = tone
        self.systemImage = systemImage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let content = VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            Label(title, systemImage: systemImage)
                .font(AppTheme.summaryTitleFont)
                .foregroundStyle(AppTheme.subduedForegroundColor)
                .symbolRenderingMode(AppTheme.symbolRenderingMode)

            Text(value)
                .font(AppTheme.summaryValueFont)
                .bold()
                .monospacedDigit()
                .contentTransition(.numericText())

            if let subtitle, subtitle.isEmpty == false {
                StatusBadge(subtitle, tone: tone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.panelPadding)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .fill(AppTheme.elevatedSurfaceColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.strokeColor, lineWidth: 1)
        )
        .animation(AppTheme.countAnimation, value: value)

        if let accessibilityIdentifier {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityLabel(accessibilityLabel ?? "\(value) \(title)")
        } else {
            content
        }
    }
}
