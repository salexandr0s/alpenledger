import Foundation

enum AppSection: String, CaseIterable, Hashable, Identifiable {
    case overview
    case ledger
    case documents
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .ledger: "Ledger"
        case .documents: "Documents"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .ledger: "list.bullet.rectangle"
        case .documents: "doc.text"
        case .settings: "gearshape"
        }
    }
}
