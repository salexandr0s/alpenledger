import Foundation
import GRDB
import ALDomain

public protocol TaxProfileRepository: Sendable {
    func fetchTaxProfile(entityId: LegalEntityID) throws -> TaxProfile?
    func fetchTaxProfile(id: TaxProfileID) throws -> TaxProfile?
    func saveTaxProfile(_ taxProfile: TaxProfile) throws
    func deleteTaxProfile(id: TaxProfileID) throws
}

public final class GRDBTaxProfileRepository: TaxProfileRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchTaxProfile(entityId: LegalEntityID) throws -> TaxProfile? {
        try dbPool.read { db in
            try TaxProfile
                .filter(Column("entityId") == entityId)
                .fetchOne(db)
        }
    }

    public func fetchTaxProfile(id: TaxProfileID) throws -> TaxProfile? {
        try dbPool.read { db in
            try TaxProfile.fetchOne(db, key: id)
        }
    }

    public func saveTaxProfile(_ taxProfile: TaxProfile) throws {
        try dbPool.write { db in
            try taxProfile.save(db)
        }
    }

    public func deleteTaxProfile(id: TaxProfileID) throws {
        try dbPool.write { db in
            _ = try TaxProfile.deleteOne(db, key: id)
        }
    }
}
