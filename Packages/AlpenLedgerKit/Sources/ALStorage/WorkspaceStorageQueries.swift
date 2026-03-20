import ALDomain

extension WorkspaceStorage {
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
}
