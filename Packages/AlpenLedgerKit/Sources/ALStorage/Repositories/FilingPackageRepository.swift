import Foundation
import GRDB
import ALDomain

public protocol FilingPackageRepository: Sendable {
    func fetchFilingPackages(entityId: LegalEntityID) throws -> [FilingPackage]
    func fetchFilingPackage(id: FilingPackageID) throws -> FilingPackage?
    func saveFilingPackage(_ filingPackage: FilingPackage) throws
    func deleteFilingPackage(id: FilingPackageID) throws
}

public final class GRDBFilingPackageRepository: FilingPackageRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchFilingPackages(entityId: LegalEntityID) throws -> [FilingPackage] {
        try dbPool.read { db in
            try FilingPackage
                .filter(Column("entityId") == entityId)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    public func fetchFilingPackage(id: FilingPackageID) throws -> FilingPackage? {
        try dbPool.read { db in
            try FilingPackage.fetchOne(db, key: id)
        }
    }

    public func saveFilingPackage(_ filingPackage: FilingPackage) throws {
        try dbPool.write { db in
            try filingPackage.save(db)
        }
    }

    public func deleteFilingPackage(id: FilingPackageID) throws {
        try dbPool.write { db in
            _ = try FilingPackage.deleteOne(db, key: id)
        }
    }
}
