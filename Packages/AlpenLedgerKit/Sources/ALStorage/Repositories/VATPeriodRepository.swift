import Foundation
import GRDB
import ALDomain

public protocol VATPeriodRepository: Sendable {
    func fetchVATPeriod(id: VATPeriodID) throws -> VATPeriod?
    func fetchVATPeriods(entityId: LegalEntityID) throws -> [VATPeriod]
    func fetchVATPeriods(entityId: LegalEntityID, overlapping start: Date, _ end: Date) throws -> [VATPeriod]
    func saveVATPeriod(_ period: VATPeriod) throws
    func deleteVATPeriods(entityId: LegalEntityID) throws
}

public final class GRDBVATPeriodRepository: VATPeriodRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchVATPeriod(id: VATPeriodID) throws -> VATPeriod? {
        try dbPool.read { db in
            try VATPeriod
                .filter(Column("id") == id)
                .fetchOne(db)
        }
    }

    public func fetchVATPeriods(entityId: LegalEntityID) throws -> [VATPeriod] {
        try dbPool.read { db in
            try VATPeriod
                .filter(Column("entityId") == entityId)
                .order(Column("periodStart").desc)
                .fetchAll(db)
        }
    }

    public func fetchVATPeriods(entityId: LegalEntityID, overlapping start: Date, _ end: Date) throws -> [VATPeriod] {
        try dbPool.read { db in
            try VATPeriod
                .filter(Column("entityId") == entityId)
                .filter(Column("periodStart") <= end && Column("periodEnd") >= start)
                .order(Column("periodStart"))
                .fetchAll(db)
        }
    }

    public func saveVATPeriod(_ period: VATPeriod) throws {
        try dbPool.write { db in
            try period.save(db)
        }
    }

    public func deleteVATPeriods(entityId: LegalEntityID) throws {
        try dbPool.write { db in
            _ = try VATPeriod.filter(Column("entityId") == entityId).deleteAll(db)
        }
    }
}
