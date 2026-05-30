import Foundation
import ALAudit
import ALDomain
import ALStorage

public final class VATPeriodService: Sendable {
    private let storage: WorkspaceStorage
    private let repository: any VATPeriodRepository
    private let computationService: VATPeriodComputationService
    private let auditLogger: AuditLogger?

    public init(
        storage: WorkspaceStorage,
        codeBook: VATCodeBook,
        auditLogger: AuditLogger? = nil
    ) {
        self.storage = storage
        self.repository = storage.vatPeriodRepository
        self.computationService = VATPeriodComputationService(codeBook: codeBook)
        self.auditLogger = auditLogger
    }

    public func listVATPeriods(entityId: LegalEntityID) throws -> [VATPeriod] {
        try repository.fetchVATPeriods(entityId: entityId)
    }

    @discardableResult
    public func createVATPeriod(
        entityId: LegalEntityID,
        periodStart: Date,
        periodEnd: Date,
        currency: CurrencyCode = .chf,
        actorId: String = "user"
    ) throws -> VATPeriod {
        _ = try storage.requireEntity(entityId: entityId)
        guard periodStart <= periodEnd else {
            throw DomainError.invalidVATPeriod(reason: "start date must be on or before end date")
        }

        let overlappingPeriods = try repository.fetchVATPeriods(entityId: entityId, overlapping: periodStart, periodEnd)
        guard overlappingPeriods.isEmpty else {
            throw DomainError.invalidVATPeriod(reason: "period overlaps an existing VAT period")
        }

        let period = VATPeriod(
            entityId: entityId,
            periodStart: periodStart,
            periodEnd: periodEnd,
            currency: currency,
            status: .open
        )
        try repository.saveVATPeriod(period)
        try auditLogger?.log(
            actorType: .user,
            actorId: actorId,
            eventType: .vatPeriodCreated,
            objectRef: ObjectRef(kind: .vatPeriod, id: period.id.rawValue),
            payload: "\(periodStart.alpenLedgerISO8601DateString)..\(periodEnd.alpenLedgerISO8601DateString)"
        )
        return period
    }

    public func reconcileVATPeriod(_ periodId: VATPeriodID) throws -> VATReconciliationReport {
        let period = try storage.requireVATPeriod(vatPeriodId: periodId)
        let transactions = try storage.transactionRepository.fetchTransactions(
            entityId: period.entityId,
            from: period.periodStart,
            through: period.periodEnd
        )
        return computationService.reconcile(period: period, transactions: transactions)
    }

    @discardableResult
    public func lockVATPeriod(
        _ periodId: VATPeriodID,
        actorId: String = "user"
    ) throws -> VATPeriod {
        let report = try reconcileVATPeriod(periodId)
        guard report.blockerCount == 0 else {
            throw DomainError.vatPeriodHasBlockers(report.blockerCount)
        }
        return try transitionVATPeriod(
            periodId,
            to: .locked,
            eventType: .vatPeriodLocked,
            actorId: actorId
        )
    }

    @discardableResult
    public func unlockVATPeriod(
        _ periodId: VATPeriodID,
        actorId: String = "user"
    ) throws -> VATPeriod {
        try transitionVATPeriod(
            periodId,
            to: .open,
            eventType: .vatPeriodUnlocked,
            actorId: actorId
        )
    }

    private func transitionVATPeriod(
        _ periodId: VATPeriodID,
        to newStatus: VATPeriodStatus,
        eventType: AuditEventType,
        actorId: String
    ) throws -> VATPeriod {
        var period = try storage.requireVATPeriod(vatPeriodId: periodId)
        guard period.status != newStatus else { return period }
        let oldStatus = period.status
        period.status = newStatus
        try repository.saveVATPeriod(period)
        try auditLogger?.log(
            actorType: .user,
            actorId: actorId,
            eventType: eventType,
            objectRef: ObjectRef(kind: .vatPeriod, id: period.id.rawValue),
            payload: "\(oldStatus.rawValue)->\(newStatus.rawValue)"
        )
        return period
    }
}

private extension Date {
    var alpenLedgerISO8601DateString: String {
        ISO8601DateFormatter().string(from: self)
    }
}
