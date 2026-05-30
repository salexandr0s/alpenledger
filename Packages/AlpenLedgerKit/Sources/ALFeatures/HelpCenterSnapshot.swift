import Foundation

public struct HelpCenterSnapshot: Sendable {
    public struct HelpSection: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let systemImage: String
        public let items: [HelpItem]

        public init(id: String, title: String, systemImage: String, items: [HelpItem]) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.items = items
        }
    }

    public struct HelpItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let detail: String

        public init(id: String, title: String, detail: String) {
            self.id = id
            self.title = title
            self.detail = detail
        }
    }

    public let title: String
    public let subtitle: String
    public let privacyNotice: String
    public let sections: [HelpSection]

    public init(
        title: String,
        subtitle: String,
        privacyNotice: String,
        sections: [HelpSection]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.privacyNotice = privacyNotice
        self.sections = sections
    }
}
