import SwiftUI

public struct SummaryTile: View {
    public enum Style: Sendable {
        case prominent
        case compact
    }

    public enum SubtitlePresentation: Sendable {
        case secondary
        case badge
    }

    private let title: String
    private let value: String
    private let subtitle: String?
    private let tone: StatusBadge.Tone
    private let style: Style
    private let subtitlePresentation: SubtitlePresentation
    private let systemImage: String
    private let accessibilityIdentifier: String?
    private let accessibilityLabel: String?

    public init(
        _ title: String,
        value: String,
        subtitle: String? = nil,
        tone: StatusBadge.Tone = .neutral,
        style: Style = .prominent,
        subtitlePresentation: SubtitlePresentation = .secondary,
        systemImage: String,
        accessibilityIdentifier: String? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.tone = tone
        self.style = style
        self.subtitlePresentation = subtitlePresentation
        self.systemImage = systemImage
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let content = GroupBox {
            VStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                Label(title, systemImage: systemImage)
                    .font(style == .prominent ? AppTheme.summaryTitleFont : AppTheme.metaFont)
                    .foregroundStyle(AppTheme.subduedForegroundColor)
                    .symbolRenderingMode(AppTheme.symbolRenderingMode)

                Text(value)
                    .font(style == .prominent ? AppTheme.summaryValueFont : AppTheme.compactMetricValueFont)
                    .bold()
                    .monospacedDigit()
                    .contentTransition(.numericText())

                if let subtitle, subtitle.isEmpty == false {
                    switch subtitlePresentation {
                    case .secondary:
                        Text(subtitle)
                            .font(AppTheme.metaFont)
                            .foregroundStyle(AppTheme.subduedForegroundColor)
                    case .badge:
                        StatusBadge(subtitle, tone: tone)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(AppTheme.countAnimation, value: value)

        if let accessibilityIdentifier {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityLabel(accessibilityLabel ?? "\(value) \(title)")
                .accessibilityValue(accessibilityLabel ?? "\(value) \(title)")
        } else {
            content
        }
    }
}
