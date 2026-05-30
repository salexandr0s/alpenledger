import Foundation
import GRDB
import ALDomain

public struct CounterpartyMergeResult: Hashable, Sendable {
    public let source: Counterparty
    public let target: Counterparty
    public let linkedTransactionCount: Int

    public init(source: Counterparty, target: Counterparty, linkedTransactionCount: Int) {
        self.source = source
        self.target = target
        self.linkedTransactionCount = linkedTransactionCount
    }
}

public protocol CounterpartyRepository: Sendable {
    func fetchCounterparty(id: CounterpartyID) throws -> Counterparty?
    func fetchCounterparty(entityId: LegalEntityID, normalizedName: String) throws -> Counterparty?
    func fetchCounterparties(entityId: LegalEntityID, includeMerged: Bool) throws -> [Counterparty]
    func saveCounterparty(_ counterparty: Counterparty) throws
    func mergeCounterparty(sourceId: CounterpartyID, targetId: CounterpartyID, approvedAt: Date) throws -> CounterpartyMergeResult
}

public final class GRDBCounterpartyRepository: CounterpartyRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchCounterparty(id: CounterpartyID) throws -> Counterparty? {
        try dbPool.read { db in
            try Counterparty
                .filter(Column("id") == id)
                .fetchOne(db)
        }
    }

    public func fetchCounterparty(entityId: LegalEntityID, normalizedName: String) throws -> Counterparty? {
        try dbPool.read { db in
            try Counterparty
                .filter(Column("entityId") == entityId && Column("normalizedName") == normalizedName)
                .fetchOne(db)
        }
    }

    public func fetchCounterparties(entityId: LegalEntityID, includeMerged: Bool = false) throws -> [Counterparty] {
        try dbPool.read { db in
            let request = Counterparty
                .filter(Column("entityId") == entityId)
                .order(Column("displayName"))
            if includeMerged {
                return try request.fetchAll(db)
            }
            return try request
                .filter(Column("status") == CounterpartyStatus.active.rawValue)
                .fetchAll(db)
        }
    }

    public func saveCounterparty(_ counterparty: Counterparty) throws {
        try dbPool.write { db in
            try counterparty.save(db)
        }
    }

    public func mergeCounterparty(
        sourceId: CounterpartyID,
        targetId: CounterpartyID,
        approvedAt: Date
    ) throws -> CounterpartyMergeResult {
        try dbPool.write { db in
            guard var source = try Counterparty.filter(Column("id") == sourceId).fetchOne(db),
                  let target = try Counterparty.filter(Column("id") == targetId).fetchOne(db)
            else {
                throw DomainError.counterpartyNotFound
            }
            guard source.id != target.id,
                  source.entityId == target.entityId,
                  source.status == .active,
                  target.status == .active
            else {
                throw DomainError.invalidCounterpartyMerge
            }

            let linkedTransactionCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM transactions WHERE counterpartyId = ?",
                arguments: [source.id]
            ) ?? 0

            source.status = .merged
            source.mergedIntoCounterpartyId = target.id
            source.updatedAt = approvedAt
            try source.save(db)

            return CounterpartyMergeResult(
                source: source,
                target: target,
                linkedTransactionCount: linkedTransactionCount
            )
        }
    }
}

public func transactionByEnsuringCounterparty(_ transaction: Transaction, in db: Database) throws -> Transaction {
    let entityId: LegalEntityID? = try LegalEntityID.fetchOne(
        db,
        sql: "SELECT entityId FROM financialAccounts WHERE id = ?",
        arguments: [transaction.accountId]
    )
    guard let entityId else {
        throw DomainError.financialAccountNotFound
    }

    if let counterpartyId = transaction.counterpartyId {
        guard let counterparty = try Counterparty
            .filter(Column("id") == counterpartyId)
            .fetchOne(db),
            counterparty.entityId == entityId
        else {
            throw DomainError.counterpartyNotFound
        }
        return transaction
    }

    let displayName = transaction.counterpartyName
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let counterparty = try fetchOrCreateCounterparty(
        entityId: entityId,
        displayName: displayName.isEmpty ? "Unknown counterparty" : displayName,
        db: db
    )

    var linkedTransaction = transaction
    linkedTransaction.counterpartyId = counterparty.id
    linkedTransaction.counterpartyName = counterparty.displayName
    return linkedTransaction
}

private func fetchOrCreateCounterparty(
    entityId: LegalEntityID,
    displayName: String,
    db: Database
) throws -> Counterparty {
    let normalizedName = Counterparty.normalizedName(displayName)
    if let counterparty = try Counterparty
        .filter(Column("entityId") == entityId && Column("normalizedName") == normalizedName)
        .fetchOne(db) {
        return counterparty
    }

    let now = Date()
    let counterparty = Counterparty(
        entityId: entityId,
        displayName: displayName,
        normalizedName: normalizedName,
        createdAt: now,
        updatedAt: now
    )
    try counterparty.insert(db)
    return counterparty
}
