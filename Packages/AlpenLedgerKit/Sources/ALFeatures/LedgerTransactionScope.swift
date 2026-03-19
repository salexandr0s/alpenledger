import ALDomain

public enum LedgerTransactionScope: String, CaseIterable, Hashable, Sendable, Identifiable {
    case all
    case pending
    case reviewed

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            return "All"
        case .pending:
            return "Pending"
        case .reviewed:
            return "Reviewed"
        }
    }

    public func matches(_ transaction: Transaction) -> Bool {
        switch self {
        case .all:
            return true
        case .pending:
            return transaction.reviewState == .pending
        case .reviewed:
            return transaction.reviewState == .reviewed
        }
    }
}
