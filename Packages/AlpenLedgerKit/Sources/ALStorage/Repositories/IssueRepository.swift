import Foundation
import GRDB
import ALDomain

public protocol IssueRepository: Sendable {
    func fetchIssues(workspaceId: WorkspaceID, entityId: LegalEntityID?, taxYearId: TaxYearID?, status: IssueStatus?) throws -> [Issue]
    func fetchIssue(id: IssueID) throws -> Issue?
    func fetchIssue(fingerprint: String) throws -> Issue?
    func saveIssue(_ issue: Issue) throws
}

public extension IssueRepository {
    func fetchIssues(workspaceId: WorkspaceID, status: IssueStatus?) throws -> [Issue] {
        try fetchIssues(workspaceId: workspaceId, entityId: nil, taxYearId: nil, status: status)
    }
}

public final class GRDBIssueRepository: IssueRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchIssues(
        workspaceId: WorkspaceID,
        entityId: LegalEntityID? = nil,
        taxYearId: TaxYearID? = nil,
        status: IssueStatus? = nil
    ) throws -> [Issue] {
        try dbPool.read { db in
            var request = Issue
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("lastDetectedAt").desc)

            if let entityId {
                request = request.filter(Column("entityId") == entityId)
            }
            if let taxYearId {
                request = request.filter(Column("taxYearId") == taxYearId)
            }
            if let status {
                request = request.filter(Column("status") == status.rawValue)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchIssue(fingerprint: String) throws -> Issue? {
        try dbPool.read { db in
            try Issue
                .filter(Column("fingerprint") == fingerprint)
                .fetchOne(db)
        }
    }

    public func fetchIssue(id: IssueID) throws -> Issue? {
        try dbPool.read { db in
            try Issue.fetchOne(db, key: id)
        }
    }

    public func saveIssue(_ issue: Issue) throws {
        try dbPool.write { db in
            try issue.save(db)
        }
    }
}
