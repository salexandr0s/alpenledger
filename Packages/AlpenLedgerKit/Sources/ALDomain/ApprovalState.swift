import Foundation

public enum ApprovalState: String, Codable, CaseIterable, Sendable {
    case draft
    case pending
    case approved
    case rejected
}
