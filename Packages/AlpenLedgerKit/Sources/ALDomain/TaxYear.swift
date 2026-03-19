import Foundation

public enum TaxYearStatus: String, Codable, CaseIterable, Sendable {
    case open
    case locked
    case filed
}

public struct TaxYear: Hashable, Codable, Sendable {
    public let id: TaxYearID
    public let entityId: LegalEntityID
    public var year: Int
    public var periodStart: Date
    public var periodEnd: Date
    public var canton: String?
    public var filingMode: String
    public var rulesetVersion: String
    public var status: TaxYearStatus

    public init(
        id: TaxYearID = TaxYearID(),
        entityId: LegalEntityID,
        year: Int,
        periodStart: Date,
        periodEnd: Date,
        canton: String? = nil,
        filingMode: String = "standard",
        rulesetVersion: String = "ch.v1",
        status: TaxYearStatus = .open
    ) {
        self.id = id
        self.entityId = entityId
        self.year = year
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.canton = canton
        self.filingMode = filingMode
        self.rulesetVersion = rulesetVersion
        self.status = status
    }
}
