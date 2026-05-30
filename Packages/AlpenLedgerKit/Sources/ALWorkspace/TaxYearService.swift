import Foundation
import ALAudit
import ALDomain
import ALStorage

public final class TaxYearService: Sendable {
    private let storage: WorkspaceStorage
    private let repository: any TaxYearRepository
    private let auditLogger: AuditLogger?

    public init(storage: WorkspaceStorage, auditLogger: AuditLogger? = nil) {
        self.storage = storage
        self.repository = storage.taxYearRepository
        self.auditLogger = auditLogger
    }

    public func listTaxYears(entityId: LegalEntityID) throws -> [TaxYear] {
        try repository.fetchTaxYears(entityId: entityId)
    }

    @discardableResult
    public func lockTaxYear(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        actorId: String = "user"
    ) throws -> TaxYear {
        try transitionTaxYear(
            entityId: entityId,
            taxYearId: taxYearId,
            to: .locked,
            eventType: .taxYearLocked,
            actorId: actorId
        )
    }

    @discardableResult
    public func unlockTaxYear(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        actorId: String = "user"
    ) throws -> TaxYear {
        try transitionTaxYear(
            entityId: entityId,
            taxYearId: taxYearId,
            to: .open,
            eventType: .taxYearUnlocked,
            actorId: actorId
        )
    }

    private func transitionTaxYear(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        to newStatus: TaxYearStatus,
        eventType: AuditEventType,
        actorId: String
    ) throws -> TaxYear {
        var taxYear = try storage.requireTaxYear(entityId: entityId, taxYearId: taxYearId)
        guard taxYear.status != newStatus else { return taxYear }
        guard isAllowedTransition(from: taxYear.status, to: newStatus) else {
            throw DomainError.invalidTaxYearStatusTransition
        }

        let oldStatus = taxYear.status
        taxYear.status = newStatus
        try repository.saveTaxYear(taxYear)
        try auditLogger?.log(
            actorType: .user,
            actorId: actorId,
            eventType: eventType,
            objectRef: ObjectRef(kind: .taxYear, id: taxYear.id.rawValue),
            payload: "\(oldStatus.rawValue)->\(newStatus.rawValue)"
        )
        return taxYear
    }

    private func isAllowedTransition(from oldStatus: TaxYearStatus, to newStatus: TaxYearStatus) -> Bool {
        switch (oldStatus, newStatus) {
        case (.open, .locked), (.locked, .open):
            return true
        case (.open, .open), (.locked, .locked), (.filed, .filed):
            return true
        case (.open, .filed), (.locked, .filed), (.filed, .open), (.filed, .locked):
            return false
        }
    }
}
