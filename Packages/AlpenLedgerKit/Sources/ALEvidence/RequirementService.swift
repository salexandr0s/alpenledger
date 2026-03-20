import Foundation
import ALDomain
import ALStorage

public final class RequirementService: Sendable {
    private let repository: any RequirementRepository

    public init(storage: WorkspaceStorage) {
        self.repository = storage.requirementRepository
    }

    public func listRequirements(entityId: LegalEntityID, taxYearId: TaxYearID? = nil) throws -> [Requirement] {
        try repository.fetchRequirements(entityId: entityId, taxYearId: taxYearId)
    }

    @discardableResult
    public func syncRequirement(
        fingerprint: String,
        entityId: LegalEntityID,
        taxYearId: TaxYearID?,
        code: RequirementCode,
        subjectRef: ObjectRef,
        summary: String,
        coverageStart: Date?,
        coverageEnd: Date?,
        status: RequirementStatus,
        satisfiedByRef: ObjectRef?,
        now: Date
    ) throws -> Requirement {
        var requirement = try repository.fetchRequirement(fingerprint: fingerprint) ?? Requirement(
            fingerprint: fingerprint,
            entityId: entityId,
            taxYearId: taxYearId,
            requirementCode: code,
            subjectRef: subjectRef,
            summary: summary,
            coverageStart: coverageStart,
            coverageEnd: coverageEnd,
            status: status,
            satisfiedByRef: satisfiedByRef,
            createdAt: now,
            updatedAt: now
        )
        requirement.taxYearId = taxYearId
        requirement.requirementCode = code
        requirement.subjectRef = subjectRef
        requirement.summary = summary
        requirement.coverageStart = coverageStart
        requirement.coverageEnd = coverageEnd
        requirement.status = status
        requirement.satisfiedByRef = satisfiedByRef
        requirement.updatedAt = now
        try repository.saveRequirement(requirement)
        return requirement
    }
}
