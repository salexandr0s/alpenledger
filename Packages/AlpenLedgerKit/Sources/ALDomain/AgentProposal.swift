import Foundation

public enum AgentKind: String, Codable, CaseIterable, Sendable {
    case systemHeuristics
}

public enum ProposalType: String, Codable, CaseIterable, Sendable {
    case closingAccrualReview
    case documentLinkReview
    case counterpartyMergeReview
    case transactionMappingReview
    case transactionSplitReview
    case taxOverrideReview
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
    public var relatedRef: ObjectRef?
    public var summary: String
    public var rationale: String
    public var confidence: Double
    public var missingFields: [String]
    public var question: String?
    public var requiresManualReview: Bool
    public var status: ProposalStatus
    public let createdAt: Date
    public var decidedAt: Date?
    public var decidedBy: String?
    public var decisionReason: String?

    public init(
        id: AgentProposalID = AgentProposalID(),
        fingerprint: String,
        workspaceId: WorkspaceID,
        agentKind: AgentKind,
        proposalType: ProposalType,
        targetRef: ObjectRef,
        relatedRef: ObjectRef? = nil,
        summary: String,
        rationale: String,
        confidence: Double,
        missingFields: [String] = [],
        question: String? = nil,
        requiresManualReview: Bool = false,
        status: ProposalStatus = .pending,
        createdAt: Date = .now,
        decidedAt: Date? = nil,
        decidedBy: String? = nil,
        decisionReason: String? = nil
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.workspaceId = workspaceId
        self.agentKind = agentKind
        self.proposalType = proposalType
        self.targetRef = targetRef
        self.relatedRef = relatedRef
        self.summary = summary
        self.rationale = rationale
        self.confidence = confidence
        self.missingFields = missingFields
        self.question = question
        self.requiresManualReview = requiresManualReview
        self.status = status
        self.createdAt = createdAt
        self.decidedAt = decidedAt
        self.decidedBy = decidedBy
        self.decisionReason = decisionReason
    }
}
