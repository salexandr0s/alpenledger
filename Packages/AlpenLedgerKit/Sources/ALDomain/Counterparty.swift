import Foundation

public enum CounterpartyStatus: String, Codable, CaseIterable, Sendable {
    case active
    case merged
}

public struct Counterparty: Hashable, Codable, Sendable {
    public let id: CounterpartyID
    public let entityId: LegalEntityID
    public var displayName: String
    public var normalizedName: String
    public var status: CounterpartyStatus
    public var mergedIntoCounterpartyId: CounterpartyID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: CounterpartyID = CounterpartyID(),
        entityId: LegalEntityID,
        displayName: String,
        normalizedName: String? = nil,
        status: CounterpartyStatus = .active,
        mergedIntoCounterpartyId: CounterpartyID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.entityId = entityId
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = trimmedDisplayName.isEmpty ? "Unknown counterparty" : trimmedDisplayName
        let normalized = normalizedName ?? Self.normalizedName(self.displayName)
        self.normalizedName = normalized.isEmpty ? Self.normalizedName("Unknown counterparty") : normalized
        self.status = status
        self.mergedIntoCounterpartyId = mergedIntoCounterpartyId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public static func normalizedName(_ displayName: String) -> String {
        displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .lowercased()
    }
}
