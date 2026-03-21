import Foundation

public enum ObjectKind: String, Codable, CaseIterable, Sendable {
    case workspace
    case legalEntity
    case taxYear
    case taxFact
    case ledgerAccount
    case financialAccount
    case importJob
    case statementImport
    case transaction
    case journalEntry
    case journalLine
    case document
    case evidenceLink
    case auditEvent
    case requirement
    case issue
    case agentProposal
    case entityWorkspace
    case taxProfile
    case transactionCategory
    case invoiceRecord
    case filingPackage
}

public struct ObjectRef: Hashable, Codable, Sendable {
    public let kind: ObjectKind
    public let id: String

    public init(kind: ObjectKind, id: String) {
        self.kind = kind
        self.id = id
    }

    public init(kind: ObjectKind, id: UUID) {
        self.init(kind: kind, id: id.uuidString.lowercased())
    }

    public var stringValue: String {
        "\(kind.rawValue)|\(id)"
    }

    public static func parse(_ stringValue: String) -> ObjectRef? {
        let parts = stringValue.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2, let kind = ObjectKind(rawValue: parts[0]) else {
            return nil
        }
        return ObjectRef(kind: kind, id: parts[1])
    }
}
