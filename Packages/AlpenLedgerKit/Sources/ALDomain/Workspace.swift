import Foundation

public enum PrivacyMode: String, Codable, CaseIterable, Sendable {
    case standard
    case sensitive
}

public struct Workspace: Hashable, Codable, Sendable {
    public let id: WorkspaceID
    public var name: String
    public var storageVersion: Int
    public let createdAt: Date
    public var defaultCurrency: CurrencyCode
    public var privacyMode: PrivacyMode
    public var encryptionSaltRef: String

    public init(
        id: WorkspaceID = WorkspaceID(),
        name: String,
        storageVersion: Int = 1,
        createdAt: Date = .now,
        defaultCurrency: CurrencyCode = .chf,
        privacyMode: PrivacyMode = .standard,
        encryptionSaltRef: String
    ) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            throw DomainError.invalidWorkspaceName
        }
        self.id = id
        self.name = trimmedName
        self.storageVersion = storageVersion
        self.createdAt = createdAt
        self.defaultCurrency = defaultCurrency
        self.privacyMode = privacyMode
        self.encryptionSaltRef = encryptionSaltRef
    }
}
