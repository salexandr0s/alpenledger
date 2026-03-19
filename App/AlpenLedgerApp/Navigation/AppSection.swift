import Foundation

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case overview
    case inbox
    case ledger
    case documents
    case taxStudio
    case settings

    var id: String { rawValue }

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

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .inbox: "tray"
        case .ledger: "list.bullet.rectangle"
        case .documents: "doc.text"
        case .taxStudio: "checkerboard.rectangle"
        case .settings: "gearshape"
        }
    }
}
