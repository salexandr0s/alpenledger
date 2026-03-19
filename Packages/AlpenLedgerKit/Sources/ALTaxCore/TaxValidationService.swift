import Foundation
import ALDomain
import ALStorage

public enum TaxReadinessState: String, Codable, CaseIterable, Sendable {
    case notStarted
    case needsAttention
    case readyForReview
}

public struct TaxReadinessSummary: Hashable, Sendable {
    public let state: TaxReadinessState
    public let openIssueCount: Int
    public let pendingRequirementCount: Int
    public let currentFactCount: Int
    public let missingConceptCodes: [String]

    public init(
        state: TaxReadinessState,
        openIssueCount: Int,
        pendingRequirementCount: Int,
        currentFactCount: Int,
        missingConceptCodes: [String]
    ) {
        self.state = state
        self.openIssueCount = openIssueCount
        self.pendingRequirementCount = pendingRequirementCount
        self.currentFactCount = currentFactCount
        self.missingConceptCodes = missingConceptCodes
    }
}

public final class TaxValidationService: @unchecked Sendable {
    private let storage: WorkspaceStorage
    private let rulePackRegistry: RulePackRegistry

    public init(storage: WorkspaceStorage, rulePackRegistry: RulePackRegistry) {
        self.storage = storage
        self.rulePackRegistry = rulePackRegistry
    }

    public func readinessSummary(entityId: LegalEntityID, taxYearId: TaxYearID) throws -> TaxReadinessSummary {
        let entity = try requireEntity(entityId: entityId)
        let taxYear = try requireTaxYear(entityId: entityId, taxYearId: taxYearId)
        let currentFacts = try storage.taxFactRepository.fetchTaxFacts(entityId: entityId, taxYearId: taxYearId, currentOnly: true)
        return try readinessSummary(entity: entity, taxYear: taxYear, currentFacts: currentFacts)
    }

    public func readinessSummary(
        entity: LegalEntity,
        taxYear: TaxYear,
        currentFacts: [TaxFact]
    ) throws -> TaxReadinessSummary {
        let issues = try storage.issueRepository.fetchIssues(
            workspaceId: storage.manifest.workspace.id,
            entityId: entity.id,
            taxYearId: taxYear.id,
            status: .open
        )
        let pendingRequirements = try storage.requirementRepository
            .fetchRequirements(entityId: entity.id, taxYearId: taxYear.id)
            .filter { $0.status == .pending }

        let expectedConcepts = expectedConceptCodes(entity: entity, taxYear: taxYear)
        let presentConcepts = Set(currentFacts.map(\.conceptCode))
        let missingConceptCodes = expectedConcepts.subtracting(presentConcepts).sorted()

        let state: TaxReadinessState
        if currentFacts.isEmpty {
            state = .notStarted
        } else if issues.isEmpty == false || pendingRequirements.isEmpty == false || missingConceptCodes.isEmpty == false {
            state = .needsAttention
        } else {
            state = .readyForReview
        }

        return TaxReadinessSummary(
            state: state,
            openIssueCount: issues.count,
            pendingRequirementCount: pendingRequirements.count,
            currentFactCount: currentFacts.count,
            missingConceptCodes: missingConceptCodes
        )
    }

    private func expectedConceptCodes(entity: LegalEntity, taxYear: TaxYear) -> Set<String> {
        let jurisdictionCode = TaxComputationService.jurisdictionCode(entity: entity, taxYear: taxYear)
        guard let rulePack = rulePackRegistry.personalTaxRulePack(
            jurisdictionCode: jurisdictionCode,
            rulesetVersion: taxYear.rulesetVersion
        ) else {
            return []
        }
        return rulePack.expectedConceptCodes(for: entity)
    }

    private func requireEntity(entityId: LegalEntityID) throws -> LegalEntity {
        guard let entity = try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first(where: { $0.id == entityId })
        else {
            throw DomainError.workspaceNotFound
        }
        return entity
    }

    private func requireTaxYear(entityId: LegalEntityID, taxYearId: TaxYearID) throws -> TaxYear {
        guard let taxYear = try storage.taxYearRepository
            .fetchTaxYears(entityId: entityId)
            .first(where: { $0.id == taxYearId })
        else {
            throw DomainError.workspaceNotFound
        }
        return taxYear
    }
}
