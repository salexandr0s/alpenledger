import SwiftUI

public struct StatusBadge: View {
    public enum Tone: Sendable, Hashable {
        case neutral
        case info
        case success
        case warning
        case critical
        case accent(Color)

        public static func == (lhs: Tone, rhs: Tone) -> Bool {
            switch (lhs, rhs) {
            case (.neutral, .neutral), (.info, .info), (.success, .success), (.warning, .warning), (.critical, .critical):
                return true
            case (.accent, .accent):
                return true
            default:
                return false
            }
        }

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .neutral:
                hasher.combine(0)
            case .info:
                hasher.combine(1)
            case .success:
                hasher.combine(2)
            case .warning:
                hasher.combine(3)
            case .critical:
                hasher.combine(4)
            case .accent:
                hasher.combine(5)
            }
        }

        fileprivate var foregroundStyle: Color {
            switch self {
            case .neutral:
                return .secondary
            case .info:
                return .blue
            case .success:
                return .green
            case .warning:
                return .orange
            case .critical:
                return .red
            case let .accent(color):
                return color
            }
        }

        fileprivate var backgroundStyle: Color {
            foregroundStyle.opacity(0.12)
        }
    }

    private let title: String
    private let tone: Tone
    private let systemImage: String?
    private let accessibilityIdentifier: String?

    public init(
        _ title: String,
        tone: Tone,
        systemImage: String? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.title = title
        self.tone = tone
        self.systemImage = systemImage
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    public init(_ title: String, tint: Color, accessibilityIdentifier: String? = nil) {
        self.init(title, tone: .accent(tint), accessibilityIdentifier: accessibilityIdentifier)
    }

    public var body: some View {
        let content = Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, AppTheme.spacingS)
        .padding(.vertical, AppTheme.spacingXS)
        .foregroundStyle(tone.foregroundStyle)
        .background(tone.backgroundStyle, in: Capsule())
        .accessibilityLabel(title)

        if let accessibilityIdentifier {
            content
                .accessibilityIdentifier(accessibilityIdentifier)
        } else {
            content
        }
    }
}
