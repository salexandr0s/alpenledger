import Foundation

public enum JournalEntryKind: String, Codable, CaseIterable, Sendable {
    case manual
    case importAdjustment
}

public enum JournalEntryStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case posted
    case reversed
}

public struct JournalEntry: Hashable, Codable, Sendable {
    public let id: JournalEntryID
    public let entityId: LegalEntityID
    public var taxYearId: TaxYearID?
    public var entryNumber: String
    public var effectiveDate: Date
    public var kind: JournalEntryKind
    public var status: JournalEntryStatus
    public var memo: String
    public var reversalOfId: JournalEntryID?
    public var createdBy: String
    public var approvedBy: String?
    public var approvedAt: Date?
    public var lines: [JournalLine]

    public init(
        id: JournalEntryID = JournalEntryID(),
        entityId: LegalEntityID,
        taxYearId: TaxYearID? = nil,
        entryNumber: String,
        effectiveDate: Date,
        kind: JournalEntryKind = .manual,
        status: JournalEntryStatus = .draft,
        memo: String = "",
        reversalOfId: JournalEntryID? = nil,
        createdBy: String,
        approvedBy: String? = nil,
        approvedAt: Date? = nil,
        lines: [JournalLine]
    ) throws {
        let debitTotal = lines.reduce(into: Int64.zero) { $0 += $1.debitMinor }
        let creditTotal = lines.reduce(into: Int64.zero) { $0 += $1.creditMinor }
        guard debitTotal == creditTotal, lines.isEmpty == false else {
            throw DomainError.unbalancedJournalEntry
        }
        self.id = id
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.entryNumber = entryNumber
        self.effectiveDate = effectiveDate
        self.kind = kind
        self.status = status
        self.memo = memo
        self.reversalOfId = reversalOfId
        self.createdBy = createdBy
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.lines = lines
    }
}
