import ALDomain

extension WorkspaceStorage {
    public func requireFinancialAccount(accountId: FinancialAccountID) throws -> FinancialAccount {
        guard let account = try financialAccountRepository.fetchFinancialAccount(id: accountId) else {
            throw DomainError.financialAccountNotFound
        }
        return account
    }

    public func requireCounterparty(entityId: LegalEntityID, counterpartyId: CounterpartyID) throws -> Counterparty {
        guard let counterparty = try counterpartyRepository.fetchCounterparty(id: counterpartyId) else {
            throw DomainError.counterpartyNotFound
        }
        guard counterparty.entityId == entityId else {
            throw DomainError.invalidCounterpartyMerge
        }
        return counterparty
    }

    public func requireEntity(entityId: LegalEntityID) throws -> LegalEntity {
        guard let entity = try legalEntityRepository
            .fetchLegalEntities(workspaceId: manifest.workspace.id)
            .first(where: { $0.id == entityId })
        else {
            throw DomainError.entityNotFound
        }
        return entity
    }

    public func requireTaxYear(entityId: LegalEntityID, taxYearId: TaxYearID) throws -> TaxYear {
        guard let taxYear = try taxYearRepository
            .fetchTaxYears(entityId: entityId)
            .first(where: { $0.id == taxYearId })
        else {
            throw DomainError.taxYearNotFound
        }
        return taxYear
    }

    public func requireVATPeriod(vatPeriodId: VATPeriodID) throws -> VATPeriod {
        guard let period = try vatPeriodRepository.fetchVATPeriod(id: vatPeriodId) else {
            throw DomainError.vatPeriodNotFound
        }
        return period
    }
}
