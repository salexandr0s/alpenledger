import Foundation

public enum TaxationType: String, Codable, CaseIterable, Sendable {
    case personal
    case selfEmployed
    case corporate
}

public enum MaritalStatus: String, Codable, CaseIterable, Sendable {
    case single
    case married
    case divorced
    case widowed
    case separated
}

public struct TaxProfile: Hashable, Codable, Sendable {
    public let id: TaxProfileID
    public let entityId: LegalEntityID
    public var taxationType: TaxationType
    public var canton: CantonCode
    public var municipality: String?
    public var maritalStatus: MaritalStatus?
    public var numberOfDependents: Int
    public var rulesetVersionOverride: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: TaxProfileID = TaxProfileID(),
        entityId: LegalEntityID,
        taxationType: TaxationType,
        canton: CantonCode,
        municipality: String? = nil,
        maritalStatus: MaritalStatus? = nil,
        numberOfDependents: Int = 0,
        rulesetVersionOverride: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.entityId = entityId
        self.taxationType = taxationType
        self.canton = canton
        self.municipality = municipality
        self.maritalStatus = maritalStatus
        self.numberOfDependents = numberOfDependents
        self.rulesetVersionOverride = rulesetVersionOverride
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
