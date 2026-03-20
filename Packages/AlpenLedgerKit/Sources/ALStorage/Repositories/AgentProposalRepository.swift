import Foundation
import GRDB
import ALDomain

public protocol AgentProposalRepository: Sendable {
    func fetchAgentProposals(workspaceId: WorkspaceID, status: ProposalStatus?) throws -> [AgentProposal]
    func fetchAgentProposal(id: AgentProposalID) throws -> AgentProposal?
    func fetchAgentProposal(fingerprint: String) throws -> AgentProposal?
    func saveAgentProposal(_ proposal: AgentProposal) throws
}

public final class GRDBAgentProposalRepository: AgentProposalRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchAgentProposals(workspaceId: WorkspaceID, status: ProposalStatus? = nil) throws -> [AgentProposal] {
        try dbPool.read { db in
            var request = AgentProposal
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("createdAt").desc)

            if let status {
                request = request.filter(Column("status") == status.rawValue)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchAgentProposal(fingerprint: String) throws -> AgentProposal? {
        try dbPool.read { db in
            try AgentProposal
                .filter(Column("fingerprint") == fingerprint)
                .fetchOne(db)
        }
    }

    public func fetchAgentProposal(id: AgentProposalID) throws -> AgentProposal? {
        try dbPool.read { db in
            try AgentProposal.fetchOne(db, key: id)
        }
    }

    public func saveAgentProposal(_ proposal: AgentProposal) throws {
        try dbPool.write { db in
            try proposal.save(db)
        }
    }
}
