import Foundation
import GRDB
import ALDomain

public protocol RequirementRepository: Sendable {
    func fetchRequirements(entityId: LegalEntityID, taxYearId: TaxYearID?) throws -> [Requirement]
    func fetchRequirement(fingerprint: String) throws -> Requirement?
    func fetchRequirements(satisfiedByRef: ObjectRef) throws -> [Requirement]
    func saveRequirement(_ requirement: Requirement) throws
}

public extension RequirementRepository {
    func fetchRequirements(entityId: LegalEntityID) throws -> [Requirement] {
        try fetchRequirements(entityId: entityId, taxYearId: nil)
    }
}

public final class GRDBRequirementRepository: RequirementRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchRequirements(entityId: LegalEntityID, taxYearId: TaxYearID? = nil) throws -> [Requirement] {
        try dbPool.read { db in
            var request = Requirement
                .filter(Column("entityId") == entityId)
                .order(Column("updatedAt").desc)

            if let taxYearId {
                request = request.filter(Column("taxYearId") == taxYearId)
            }

            return try request.fetchAll(db)
        }
    }

    public func fetchRequirement(fingerprint: String) throws -> Requirement? {
        try dbPool.read { db in
            try Requirement
                .filter(Column("fingerprint") == fingerprint)
                .fetchOne(db)
        }
    }

    public func fetchRequirements(satisfiedByRef: ObjectRef) throws -> [Requirement] {
        try dbPool.read { db in
            try Requirement
                .filter(Column("satisfiedByRef") == satisfiedByRef)
                .fetchAll(db)
        }
    }

    public func saveRequirement(_ requirement: Requirement) throws {
        try dbPool.write { db in
            try requirement.save(db)
        }
    }
}
