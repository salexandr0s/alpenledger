import Foundation
import ALAudit
import ALDomain
import ALStorage

public final class TaxComputationService: Sendable {
    private let storage: WorkspaceStorage
    private let rulePackRegistry: RulePackRegistry
    private let factService: TaxFactService
    private let auditLogger: AuditLogger
    private let nowProvider: @Sendable () -> Date

    public init(
        storage: WorkspaceStorage,
        rulePackRegistry: RulePackRegistry,
        factService: TaxFactService? = nil,
        auditLogger: AuditLogger? = nil,
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.storage = storage
        self.rulePackRegistry = rulePackRegistry
        self.factService = factService ?? TaxFactService(storage: storage)
        self.auditLogger = auditLogger ?? AuditLogger(storage: storage)
        self.nowProvider = nowProvider
    }

    @discardableResult
    public func refreshFacts(entityId: LegalEntityID, taxYearId: TaxYearID) throws -> [TaxFact] {
        let entity = try storage.requireEntity(entityId: entityId)
        let taxYear = try storage.requireTaxYear(entityId: entityId, taxYearId: taxYearId)
        guard taxYear.status == .open else {
            throw DomainError.lockedPeriod
        }
        let jurisdictionCode = Self.jurisdictionCode(entity: entity, taxYear: taxYear)
        guard let rulePack = rulePackRegistry.personalTaxRulePack(
            jurisdictionCode: jurisdictionCode,
            rulesetVersion: taxYear.rulesetVersion
        ) else {
            return try factService.listTaxFacts(entityId: entityId, taxYearId: taxYearId, currentOnly: true)
        }

        let financialAccounts = try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id)
        let transactions = try financialAccounts.flatMap { account in
            try storage.transactionRepository.fetchTransactions(accountId: account.id)
        }
        let documents = try storage.documentRepository.fetchDocuments(workspaceId: storage.manifest.workspace.id)
        let context = TaxComputationContext(
            entity: entity,
            taxYear: taxYear,
            documents: documents,
            financialAccounts: financialAccounts,
            transactions: transactions
        )
        let computedFacts = try rulePack.computeFacts(context: context)
        return try factService.syncFacts(
            computedFacts,
            entityId: entity.id,
            taxYearId: taxYear.id,
            jurisdictionCode: rulePack.jurisdictionCode,
            rulesetVersion: rulePack.rulesetVersion,
            now: nowProvider()
        )
    }

    @discardableResult
    public func markFactOverridden(factId: TaxFactID, reason: String) throws -> TaxFact {
        let fact = try factService.markFactOverridden(
            factId: factId,
            reason: reason,
            now: nowProvider()
        )
        try auditLogger.log(
            actorType: .user,
            actorId: "user",
            eventType: .taxFactOverridden,
            objectRef: ObjectRef(kind: .taxFact, id: fact.id.rawValue),
            payload: fact.overrideReason
        )
        return fact
    }

    public func expectedConceptCodes(entityId: LegalEntityID, taxYearId: TaxYearID) throws -> Set<String> {
        let entity = try storage.requireEntity(entityId: entityId)
        let taxYear = try storage.requireTaxYear(entityId: entityId, taxYearId: taxYearId)
        let jurisdictionCode = Self.jurisdictionCode(entity: entity, taxYear: taxYear)
        guard let rulePack = rulePackRegistry.personalTaxRulePack(
            jurisdictionCode: jurisdictionCode,
            rulesetVersion: taxYear.rulesetVersion
        ) else {
            return []
        }
        return rulePack.expectedConceptCodes(for: entity)
    }

    public static func jurisdictionCode(entity: LegalEntity, taxYear: TaxYear) -> String {
        let canton = taxYear.canton ?? entity.canton ?? .zh
        return "CH-\(canton.rawValue)"
    }

}
