import Foundation

public enum RequirementCode: String, Codable, CaseIterable, Sendable {
    case statementCoverage
    case expenseEvidence
}

public enum RequirementStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case satisfied
}

public struct Requirement: Hashable, Codable, Sendable {
    public let id: RequirementID
    public let fingerprint: String
    public let entityId: LegalEntityID
    public var taxYearId: TaxYearID?
    public var requirementCode: RequirementCode
    public var subjectRef: ObjectRef
    public var summary: String
    public var coverageStart: Date?
    public var coverageEnd: Date?
    public var status: RequirementStatus
    public var satisfiedByRef: ObjectRef?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: RequirementID = RequirementID(),
        fingerprint: String,
        entityId: LegalEntityID,
        taxYearId: TaxYearID? = nil,
        requirementCode: RequirementCode,
        subjectRef: ObjectRef,
        summary: String,
        coverageStart: Date? = nil,
        coverageEnd: Date? = nil,
        status: RequirementStatus,
        satisfiedByRef: ObjectRef? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.requirementCode = requirementCode
        self.subjectRef = subjectRef
        self.summary = summary
        self.coverageStart = coverageStart
        self.coverageEnd = coverageEnd
        self.status = status
        self.satisfiedByRef = satisfiedByRef
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
