import Foundation
import GRDB
import ALDomain

public protocol AgentConversationRepository: Sendable {
    func fetchConversations(workspaceId: WorkspaceID, status: AgentConversationStatus?) throws -> [AgentConversation]
    func fetchConversation(id: AgentConversationID) throws -> AgentConversation?
    func saveConversation(_ conversation: AgentConversation) throws

    func fetchMessages(conversationId: AgentConversationID) throws -> [AgentMessage]
    func fetchMessage(id: AgentMessageID) throws -> AgentMessage?
    func saveMessage(_ message: AgentMessage) throws

    func fetchAgentRuns(conversationId: AgentConversationID) throws -> [AgentRunTrace]
    func fetchAgentRun(id: AgentRunID) throws -> AgentRunTrace?
    func saveAgentRun(_ run: AgentRunTrace) throws

    func fetchPendingApprovals(
        conversationId: AgentConversationID,
        status: AgentPendingApprovalStatus?
    ) throws -> [AgentPendingApproval]
    func fetchPendingApproval(id: AgentPendingApprovalID) throws -> AgentPendingApproval?
    func savePendingApproval(_ approval: AgentPendingApproval) throws
}

public final class GRDBAgentConversationRepository: AgentConversationRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchConversations(
        workspaceId: WorkspaceID,
        status: AgentConversationStatus? = nil
    ) throws -> [AgentConversation] {
        try dbPool.read { db in
            var request = AgentConversation
                .filter(Column("workspaceId") == workspaceId)
                .order(Column("updatedAt").desc)

            if let status {
                request = request.filter(Column("status") == status.rawValue)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchConversation(id: AgentConversationID) throws -> AgentConversation? {
        try dbPool.read { db in
            try AgentConversation.fetchOne(db, key: id)
        }
    }

    public func saveConversation(_ conversation: AgentConversation) throws {
        try dbPool.write { db in
            try conversation.save(db)
        }
    }

    public func fetchMessages(conversationId: AgentConversationID) throws -> [AgentMessage] {
        try dbPool.read { db in
            try AgentMessage
                .filter(Column("conversationId") == conversationId)
                .order(Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    public func fetchMessage(id: AgentMessageID) throws -> AgentMessage? {
        try dbPool.read { db in
            try AgentMessage.fetchOne(db, key: id)
        }
    }

    public func saveMessage(_ message: AgentMessage) throws {
        try dbPool.write { db in
            try message.save(db)
        }
    }

    public func fetchAgentRuns(conversationId: AgentConversationID) throws -> [AgentRunTrace] {
        try dbPool.read { db in
            try AgentRunTrace
                .filter(Column("conversationId") == conversationId)
                .order(Column("startedAt").asc)
                .fetchAll(db)
        }
    }

    public func fetchAgentRun(id: AgentRunID) throws -> AgentRunTrace? {
        try dbPool.read { db in
            try AgentRunTrace.fetchOne(db, key: id)
        }
    }

    public func saveAgentRun(_ run: AgentRunTrace) throws {
        try dbPool.write { db in
            try run.save(db)
        }
    }

    public func fetchPendingApprovals(
        conversationId: AgentConversationID,
        status: AgentPendingApprovalStatus? = nil
    ) throws -> [AgentPendingApproval] {
        try dbPool.read { db in
            var request = AgentPendingApproval
                .filter(Column("conversationId") == conversationId)
                .order(Column("requestedAt").desc)

            if let status {
                request = request.filter(Column("status") == status.rawValue)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchPendingApproval(id: AgentPendingApprovalID) throws -> AgentPendingApproval? {
        try dbPool.read { db in
            try AgentPendingApproval.fetchOne(db, key: id)
        }
    }

    public func savePendingApproval(_ approval: AgentPendingApproval) throws {
        try dbPool.write { db in
            try approval.save(db)
        }
    }
}
