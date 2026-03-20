import Foundation
import ALDomain
import ALStorage
import ALAudit

public final class LegalEntityService: Sendable {
    public struct DeletionCheck: Sendable, Equatable {
        public let statementImportCount: Int
        public let transactionCount: Int
        public let documentCount: Int
        public let taxFactCount: Int
        public let issueCount: Int
        public let requirementCount: Int

        public init(
            statementImportCount: Int,
            transactionCount: Int,
            documentCount: Int,
            taxFactCount: Int,
            issueCount: Int,
            requirementCount: Int
        ) {
            self.statementImportCount = statementImportCount
            self.transactionCount = transactionCount
            self.documentCount = documentCount
            self.taxFactCount = taxFactCount
            self.issueCount = issueCount
            self.requirementCount = requirementCount
        }

        public var canDelete: Bool {
            statementImportCount == 0 &&
            transactionCount == 0 &&
            documentCount == 0 &&
            taxFactCount == 0 &&
            issueCount == 0 &&
            requirementCount == 0
        }
    }

    private let storage: WorkspaceStorage
    private let auditLogger: AuditLogger
    private let nowProvider: @Sendable () -> Date
    private let calendar = Calendar(identifier: .gregorian)

    public init(
        storage: WorkspaceStorage,
        auditLogger: AuditLogger,
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.storage = storage
        self.auditLogger = auditLogger
        self.nowProvider = nowProvider
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
            canton: .zh
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
            canton: .zh
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

    public func deletionCheck(for entityId: LegalEntityID) throws -> DeletionCheck {
        let accounts = try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entityId)

        var statementImportCount = 0
        var transactionCount = 0
        for account in accounts {
            statementImportCount += try storage.statementImportRepository.fetchStatementImports(accountId: account.id).count
            transactionCount += try storage.transactionRepository.fetchTransactions(accountId: account.id).count
        }

        let documents = try storage.documentRepository.fetchDocuments(workspaceId: storage.manifest.workspace.id)
        let documentCount = documents.filter { $0.detectedEntityId == entityId }.count
        let taxYears = try storage.taxYearRepository.fetchTaxYears(entityId: entityId)
        let taxFactCount = try taxYears.reduce(into: 0) { count, taxYear in
            count += try storage.taxFactRepository.fetchTaxFacts(entityId: entityId, taxYearId: taxYear.id, currentOnly: false).count
        }
        let issueCount = try storage.issueRepository.fetchIssues(
            workspaceId: storage.manifest.workspace.id,
            entityId: entityId,
            taxYearId: nil,
            status: nil
        ).count
        let requirementCount = try storage.requirementRepository.fetchRequirements(entityId: entityId).count

        return DeletionCheck(
            statementImportCount: statementImportCount,
            transactionCount: transactionCount,
            documentCount: documentCount,
            taxFactCount: taxFactCount,
            issueCount: issueCount,
            requirementCount: requirementCount
        )
    }

    public func deleteEntity(_ entityId: LegalEntityID) throws -> DeletionCheck {
        let check = try deletionCheck(for: entityId)
        guard check.canDelete else {
            return check
        }

        try storage.taxYearRepository.deleteTaxYears(entityId: entityId)
        try storage.financialAccountRepository.deleteFinancialAccounts(entityId: entityId)
        try storage.ledgerAccountRepository.deleteLedgerAccounts(entityId: entityId)
        try storage.legalEntityRepository.deleteLegalEntity(entityId)

        try auditLogger.log(
            actorType: .user,
            actorId: "user",
            eventType: .legalEntityRemoved,
            objectRef: ObjectRef(kind: .legalEntity, id: entityId.rawValue)
        )

        return check
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

        let currentDate = nowProvider()
        let currentYear = calendar.component(.year, from: currentDate)
        let periodStart = calendar.date(from: DateComponents(year: currentYear, month: entity.fiscalYearStartMonth, day: entity.fiscalYearStartDay)) ?? currentDate
        let periodEnd = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: periodStart) ?? currentDate

        let financialAccount = FinancialAccount(
            entityId: entity.id,
            accountType: .bank,
            institutionName: defaultInstitutionName,
            displayName: controlAccount.name,
            ledgerControlAccountId: controlAccount.id,
            openedAt: periodStart
        )
        try storage.financialAccountRepository.saveFinancialAccount(financialAccount)
        try auditLogger.log(
            eventType: .financialAccountCreated,
            objectRef: ObjectRef(kind: .financialAccount, id: financialAccount.id.rawValue)
        )

        let taxYear = TaxYear(
            entityId: entity.id,
            year: currentYear,
            periodStart: periodStart,
            periodEnd: periodEnd,
            canton: entity.canton,
            rulesetVersion: entity.canton == .zh ? "zh-personal-2026-v1" : "ch.v1"
        )
        try storage.taxYearRepository.saveTaxYear(taxYear)
    }
}
