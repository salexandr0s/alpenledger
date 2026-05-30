import Foundation
import GRDB
import ALDomain

public protocol TaxFactRepository: Sendable {
    func fetchTaxFacts(entityId: LegalEntityID, taxYearId: TaxYearID, currentOnly: Bool) throws -> [TaxFact]
    func fetchTaxFact(id: TaxFactID) throws -> TaxFact?
    func fetchTaxFact(fingerprint: String, isCurrent: Bool?) throws -> TaxFact?
    func fetchCurrentTaxFacts(sourceRef: ObjectRef) throws -> [TaxFact]
    func saveTaxFact(_ fact: TaxFact) throws
}

public final class GRDBTaxFactRepository: TaxFactRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchTaxFacts(entityId: LegalEntityID, taxYearId: TaxYearID, currentOnly: Bool = true) throws -> [TaxFact] {
        try dbPool.read { db in
            var request = TaxFact
                .filter(Column("entityId") == entityId && Column("taxYearId") == taxYearId)
                .order(Column("conceptCode"), Column("createdAt").desc)

            if currentOnly {
                request = request.filter(Column("isCurrent") == true)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchTaxFact(fingerprint: String, isCurrent: Bool? = nil) throws -> TaxFact? {
        try dbPool.read { db in
            var request = TaxFact
                .filter(Column("fingerprint") == fingerprint)
                .order(Column("createdAt").desc)

            if let isCurrent {
                request = request.filter(Column("isCurrent") == isCurrent)
            }
            return try request.fetchOne(db)
        }
    }

    public func fetchTaxFact(id: TaxFactID) throws -> TaxFact? {
        try dbPool.read { db in
            try TaxFact.fetchOne(db, key: id)
        }
    }

    public func fetchCurrentTaxFacts(sourceRef: ObjectRef) throws -> [TaxFact] {
        try dbPool.read { db in
            let facts = try TaxFact
                .filter(Column("isCurrent") == true)
                .fetchAll(db)
            return facts.filter { $0.provenanceRefs.contains(sourceRef) }
        }
    }

    public func saveTaxFact(_ fact: TaxFact) throws {
        try dbPool.write { db in
            try fact.save(db)
        }
    }
}
