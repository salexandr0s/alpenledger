import Foundation
import ALDomain
import ALStorage
import ALAudit

public final class LegalEntityService: @unchecked Sendable {
    private let storage: WorkspaceStorage
    private let auditLogger: AuditLogger
    private let calendar = Calendar(identifier: .gregorian)

    public init(storage: WorkspaceStorage, auditLogger: AuditLogger) {
        self.storage = storage
        self.auditLogger = auditLogger
    }

    public func listEntities() throws -> [LegalEntity] {
        try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
    }

    @discardableResult
    public func createDefaultNaturalPerson() throws -> LegalEntity {
        let existing = try listEntities()
        if let naturalPerson = existing.first(where: { $0.kind == .naturalPerson }) {
            return naturalPerson
        }

        let entity = LegalEntity(
            workspaceId: storage.manifest.workspace.id,
            kind: .naturalPerson,
            legalName: storage.manifest.workspace.name,
            displayName: "Personal",
            canton: "ZH"
        )
        try saveNewEntity(entity, defaultInstitutionName: "Personal Bank")
        return entity
    }

    @discardableResult
    public func createSoleProprietor(name: String) throws -> LegalEntity {
        let entity = LegalEntity(
            workspaceId: storage.manifest.workspace.id,
            kind: .soleProprietor,
            legalName: name,
            displayName: name,
            canton: "ZH"
        )
        try saveNewEntity(entity, defaultInstitutionName: "Business Bank")
        return entity
    }

    public func updateEntity(_ entity: LegalEntity) throws {
        try storage.legalEntityRepository.saveLegalEntity(entity)
        try auditLogger.log(
            actorType: .user,
            actorId: "user",
            eventType: .legalEntityUpdated,
            objectRef: ObjectRef(kind: .legalEntity, id: entity.id.rawValue)
        )
    }

    private func saveNewEntity(_ entity: LegalEntity, defaultInstitutionName: String) throws {
        try storage.legalEntityRepository.saveLegalEntity(entity)
        try auditLogger.log(
            actorType: .user,
            actorId: "user",
            eventType: .legalEntityCreated,
            objectRef: ObjectRef(kind: .legalEntity, id: entity.id.rawValue)
        )

        let accounts = LedgerTemplates.accounts(for: entity.kind, entityId: entity.id)
        for account in accounts {
            try storage.ledgerAccountRepository.saveLedgerAccount(account)
        }
        try auditLogger.log(
            eventType: .ledgerSeeded,
            objectRef: ObjectRef(kind: .legalEntity, id: entity.id.rawValue)
        )

        guard let controlAccount = accounts.first(where: \.isControlAccount) else {
            return
        }

        let financialAccount = FinancialAccount(
            entityId: entity.id,
            accountType: .bank,
            institutionName: defaultInstitutionName,
            displayName: controlAccount.name,
            ledgerControlAccountId: controlAccount.id
        )
        try storage.financialAccountRepository.saveFinancialAccount(financialAccount)
        try auditLogger.log(
            eventType: .financialAccountCreated,
            objectRef: ObjectRef(kind: .financialAccount, id: financialAccount.id.rawValue)
        )

        let currentYear = calendar.component(.year, from: .now)
        let periodStart = calendar.date(from: DateComponents(year: currentYear, month: entity.fiscalYearStartMonth, day: entity.fiscalYearStartDay)) ?? .now
        let periodEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: periodStart) ?? .now
        let taxYear = TaxYear(
            entityId: entity.id,
            year: currentYear,
            periodStart: periodStart,
            periodEnd: periodEnd,
            canton: entity.canton
        )
        try storage.taxYearRepository.saveTaxYear(taxYear)
    }
}
