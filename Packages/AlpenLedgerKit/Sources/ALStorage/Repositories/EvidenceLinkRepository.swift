import Foundation
import GRDB
import ALDomain

public protocol EvidenceLinkRepository: Sendable {
    func fetchEvidenceLinks(for objectRef: ObjectRef) throws -> [EvidenceLink]
    func saveEvidenceLink(_ evidenceLink: EvidenceLink) throws
}

public final class GRDBEvidenceLinkRepository: EvidenceLinkRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchEvidenceLinks(for objectRef: ObjectRef) throws -> [EvidenceLink] {
        try dbPool.read { db in
            try EvidenceLink
                .filter(Column("sourceRef") == objectRef || Column("targetRef") == objectRef)
                .fetchAll(db)
        }
    }

    public func saveEvidenceLink(_ evidenceLink: EvidenceLink) throws {
        try dbPool.write { db in
            try evidenceLink.save(db)
        }
    }
}
