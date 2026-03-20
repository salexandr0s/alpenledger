import Foundation
import GRDB
import ALDomain

public protocol TaxYearRepository: Sendable {
    func fetchTaxYears(entityId: LegalEntityID) throws -> [TaxYear]
    func saveTaxYear(_ taxYear: TaxYear) throws
    func deleteTaxYears(entityId: LegalEntityID) throws
}

public final class GRDBTaxYearRepository: TaxYearRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchTaxYears(entityId: LegalEntityID) throws -> [TaxYear] {
        try dbPool.read { db in
            try TaxYear
                .filter(Column("entityId") == entityId)
                .order(Column("year").desc)
                .fetchAll(db)
        }
    }

    public func saveTaxYear(_ taxYear: TaxYear) throws {
        try dbPool.write { db in
            try taxYear.save(db)
        }
    }

    public func deleteTaxYears(entityId: LegalEntityID) throws {
        try dbPool.write { db in
            _ = try TaxYear.filter(Column("entityId") == entityId).deleteAll(db)
        }
    }
}
