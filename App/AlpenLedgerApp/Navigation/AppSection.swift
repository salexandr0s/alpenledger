import Foundation
import SwiftUI

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    enum Group: String, CaseIterable, Hashable, Identifiable {
        case home
        case records
        case filing
        case utility

        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: "Home"
            case .records: "Records"
            case .filing: "Filing"
            case .utility: "Utility"
            }
        }

        var sections: [AppSection] {
            AppSection.allCases.filter { $0.group == self }
        }
    }

    case overview
    case inbox
    case ledger
    case documents
    case taxStudio
    case settings

    var id: String { rawValue }

    var group: Group {
        switch self {
        case .overview, .inbox:
            return .home
        case .ledger, .documents:
            return .records
        case .taxStudio:
            return .filing
        case .settings:
            return .utility
        }
    }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .inbox: "Inbox"
        case .ledger: "Ledger"
        case .documents: "Documents"
        case .taxStudio: "Tax Studio"
        case .settings: "Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: "Workspace status and next steps"
        case .inbox: "Imports, proposals, and issues"
        case .ledger: "Transactions and linked evidence"
        case .documents: "Search and preview source files"
        case .taxStudio: "Readiness, facts, and blockers"
        case .settings: "Workspace and entity configuration"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.stack"
        case .inbox: "tray.full"
        case .ledger: "list.bullet.rectangle"
        case .documents: "doc.text"
        case .taxStudio: "checkmark.shield"
        case .settings: "gearshape"
        }
    }

    var commandTitle: String {
        "Show \(title)"
    }

    var keyboardShortcut: KeyEquivalent {
        switch self {
        case .overview: "1"
        case .inbox: "2"
        case .ledger: "3"
        case .documents: "4"
        case .taxStudio: "5"
        case .settings: "6"
        }
    }
}
