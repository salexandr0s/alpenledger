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
        let resolvedSystemImage = resolvedSystemImage
        let content = Group {
            if let resolvedSystemImage {
                Label(title, systemImage: resolvedSystemImage)
            } else {
                Text(title)
            }
        }
        .font(.caption2.bold())
        .symbolRenderingMode(AppTheme.symbolRenderingMode)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(tone.foregroundStyle)
        .background(tone.backgroundStyle, in: Capsule())
        .overlay(
            Capsule()
                .stroke(tone.foregroundStyle.opacity(0.16), lineWidth: 1)
        )
        .accessibilityLabel(title)

        if let accessibilityIdentifier {
            content
                .accessibilityIdentifier(accessibilityIdentifier)
        } else {
            content
        }
    }

    private var resolvedSystemImage: String? {
        if let systemImage {
            return systemImage
        }

        switch tone {
        case .neutral:
            return nil
        case .info:
            return "info.circle"
        case .success:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .critical:
            return "exclamationmark.octagon"
        case .accent:
            return nil
        }
    }
}
