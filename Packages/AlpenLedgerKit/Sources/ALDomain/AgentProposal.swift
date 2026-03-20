import Foundation

public enum AgentKind: String, Codable, CaseIterable, Sendable {
    case systemHeuristics
}

public enum ProposalType: String, Codable, CaseIterable, Sendable {
    case documentLinkReview
}

public enum ProposalStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case resolved
    case rejected
}

public struct AgentProposal: Hashable, Codable, Sendable {
    public let id: AgentProposalID
    public let fingerprint: String
    public let workspaceId: WorkspaceID
    public var agentKind: AgentKind
    public var proposalType: ProposalType
    public var targetRef: ObjectRef
    public var summary: String
    public var rationale: String
    public var confidence: Double
    public var status: ProposalStatus
    public let createdAt: Date
    public var decidedAt: Date?

    public init(
        id: AgentProposalID = AgentProposalID(),
        fingerprint: String,
        workspaceId: WorkspaceID,
        agentKind: AgentKind,
        proposalType: ProposalType,
        targetRef: ObjectRef,
        summary: String,
        rationale: String,
        confidence: Double,
        status: ProposalStatus = .pending,
        createdAt: Date = .now,
        decidedAt: Date? = nil
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.workspaceId = workspaceId
        self.agentKind = agentKind
        self.proposalType = proposalType
        self.targetRef = targetRef
        self.summary = summary
        self.rationale = rationale
        self.confidence = confidence
        self.status = status
        self.createdAt = createdAt
        self.decidedAt = decidedAt
    }
}
