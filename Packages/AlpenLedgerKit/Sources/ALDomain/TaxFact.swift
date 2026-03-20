import Foundation

public enum TaxFactValueType: String, Codable, CaseIterable, Sendable {
    case money
    case text
    case bool
    case date
}

public enum TaxFactStatus: String, Codable, CaseIterable, Sendable {
    case observed
    case derived
    case overridden
}

public struct TaxFact: Hashable, Codable, Sendable {
    public let id: TaxFactID
    public let fingerprint: String
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public var jurisdictionCode: String
    public var conceptCode: String
    public var valueType: TaxFactValueType
    public var moneyMinor: Int64?
    public var textValue: String?
    public var boolValue: Bool?
    public var dateValue: Date?
    public var currency: CurrencyCode?
    public var status: TaxFactStatus
    public var rulesetVersion: String
    public var provenanceRefs: [ObjectRef]
    public var confidence: Double
    public let supersedesFactId: TaxFactID?
    public var isCurrent: Bool
    public var overrideReason: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: TaxFactID = TaxFactID(),
        fingerprint: String,
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        jurisdictionCode: String,
        conceptCode: String,
        valueType: TaxFactValueType,
        moneyMinor: Int64? = nil,
        textValue: String? = nil,
        boolValue: Bool? = nil,
        dateValue: Date? = nil,
        currency: CurrencyCode? = nil,
        status: TaxFactStatus,
        rulesetVersion: String,
        provenanceRefs: [ObjectRef] = [],
        confidence: Double = 1.0,
        supersedesFactId: TaxFactID? = nil,
        isCurrent: Bool = true,
        overrideReason: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.jurisdictionCode = jurisdictionCode
        self.conceptCode = conceptCode
        self.valueType = valueType
        self.moneyMinor = moneyMinor
        self.textValue = textValue
        self.boolValue = boolValue
        self.dateValue = dateValue
        self.currency = currency
        self.status = status
        self.rulesetVersion = rulesetVersion
        self.provenanceRefs = provenanceRefs
        self.confidence = confidence
        self.supersedesFactId = supersedesFactId
        self.isCurrent = isCurrent
        self.overrideReason = overrideReason
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
