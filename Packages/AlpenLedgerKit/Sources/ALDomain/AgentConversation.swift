import Foundation

public enum AgentConversationStatus: String, Codable, CaseIterable, Sendable {
    case active
    case archived
}

public enum AgentMessageRole: String, Codable, CaseIterable, Sendable {
    case system
    case user
    case assistant
    case tool
}

public enum AgentPendingApprovalStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case approved
    case rejected
    case expired
}

public enum AgentRunStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case running
    case completed
    case blocked
    case failed
}

public enum AgentRunToolOutcome: String, Codable, CaseIterable, Sendable {
    case planned
    case executed
    case rejected
}

public struct AgentConversation: Hashable, Codable, Sendable {
    public let id: AgentConversationID
    public let workspaceId: WorkspaceID
    public var title: String
    public var activeEntityId: LegalEntityID?
    public var activeTaxYearId: TaxYearID?
    public var status: AgentConversationStatus
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: AgentConversationID = AgentConversationID(),
        workspaceId: WorkspaceID,
        title: String,
        activeEntityId: LegalEntityID? = nil,
        activeTaxYearId: TaxYearID? = nil,
        status: AgentConversationStatus = .active,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.title = title
        self.activeEntityId = activeEntityId
        self.activeTaxYearId = activeTaxYearId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AgentRunToolCall: Hashable, Codable, Sendable {
    public let toolName: String
    public let inputHash: String?
    public let outcome: AgentRunToolOutcome
    public let provenanceRefs: [ObjectRef]
    public let errorCode: String?
    public let durationMilliseconds: Int?
    public let finishedAt: Date?

    public init(
        toolName: String,
        inputHash: String? = nil,
        outcome: AgentRunToolOutcome,
        provenanceRefs: [ObjectRef] = [],
        errorCode: String? = nil,
        durationMilliseconds: Int? = nil,
        finishedAt: Date? = nil
    ) {
        self.toolName = toolName
        self.inputHash = inputHash
        self.outcome = outcome
        self.provenanceRefs = provenanceRefs
        self.errorCode = errorCode
        self.durationMilliseconds = durationMilliseconds
        self.finishedAt = finishedAt
    }
}

public struct AgentRunApprovalDecision: Hashable, Codable, Sendable {
    public let approvalId: AgentPendingApprovalID
    public let toolName: String
    public let inputHash: String
    public let targetRefs: [ObjectRef]
    public let status: AgentPendingApprovalStatus
    public let requestedBy: String
    public let requestedAt: Date
    public let decidedBy: String?
    public let decidedAt: Date?
    public let decisionReason: String?

    public init(
        approvalId: AgentPendingApprovalID,
        toolName: String,
        inputHash: String,
        targetRefs: [ObjectRef] = [],
        status: AgentPendingApprovalStatus,
        requestedBy: String,
        requestedAt: Date,
        decidedBy: String? = nil,
        decidedAt: Date? = nil,
        decisionReason: String? = nil
    ) {
        self.approvalId = approvalId
        self.toolName = toolName
        self.inputHash = inputHash
        self.targetRefs = targetRefs
        self.status = status
        self.requestedBy = requestedBy
        self.requestedAt = requestedAt
        self.decidedBy = decidedBy
        self.decidedAt = decidedAt
        self.decisionReason = decisionReason
    }

    public init(approval: AgentPendingApproval) {
        self.init(
            approvalId: approval.id,
            toolName: approval.toolName,
            inputHash: approval.inputHash,
            targetRefs: approval.targetRefs,
            status: approval.status,
            requestedBy: approval.requestedBy,
            requestedAt: approval.requestedAt,
            decidedBy: approval.decidedBy,
            decidedAt: approval.decidedAt,
            decisionReason: approval.decisionReason
        )
    }
}

public struct AgentRunTrace: Hashable, Codable, Sendable {
    public let id: AgentRunID
    public let conversationId: AgentConversationID
    public var userMessageId: AgentMessageID?
    public var assistantMessageId: AgentMessageID?
    public var status: AgentRunStatus
    public let intent: AgentIntent
    public let specialists: [AgentSpecialist]
    public let plannedToolNames: [String]
    public let unavailableToolNames: [String]
    public let requiredScopes: [AgentToolScope]
    public let contextRefs: [ObjectRef]
    public let clarificationQuestion: String?
    public let rationale: String
    public var modelProviderID: String?
    public var modelCapability: ModelProviderCapability?
    public var promptTemplateID: String?
    public var modelInputScope: ModelProviderInputScope?
    public var sentDataOffDevice: Bool
    public var toolCalls: [AgentRunToolCall]
    public var approvalDecisions: [AgentRunApprovalDecision]
    public var errorCode: String?
    public let startedAt: Date
    public var finishedAt: Date?

    public init(
        id: AgentRunID = AgentRunID(),
        conversationId: AgentConversationID,
        userMessageId: AgentMessageID? = nil,
        assistantMessageId: AgentMessageID? = nil,
        status: AgentRunStatus = .planned,
        intent: AgentIntent,
        specialists: [AgentSpecialist],
        plannedToolNames: [String],
        unavailableToolNames: [String] = [],
        requiredScopes: [AgentToolScope],
        contextRefs: [ObjectRef],
        clarificationQuestion: String? = nil,
        rationale: String,
        modelProviderID: String? = nil,
        modelCapability: ModelProviderCapability? = nil,
        promptTemplateID: String? = nil,
        modelInputScope: ModelProviderInputScope? = nil,
        sentDataOffDevice: Bool = false,
        toolCalls: [AgentRunToolCall] = [],
        approvalDecisions: [AgentRunApprovalDecision] = [],
        errorCode: String? = nil,
        startedAt: Date = .now,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.userMessageId = userMessageId
        self.assistantMessageId = assistantMessageId
        self.status = status
        self.intent = intent
        self.specialists = specialists
        self.plannedToolNames = plannedToolNames
        self.unavailableToolNames = unavailableToolNames
        self.requiredScopes = requiredScopes
        self.contextRefs = contextRefs
        self.clarificationQuestion = clarificationQuestion
        self.rationale = rationale
        self.modelProviderID = modelProviderID
        self.modelCapability = modelCapability
        self.promptTemplateID = promptTemplateID
        self.modelInputScope = modelInputScope
        self.sentDataOffDevice = sentDataOffDevice
        self.toolCalls = toolCalls
        self.approvalDecisions = approvalDecisions
        self.errorCode = errorCode
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }

    public init(
        conversationId: AgentConversationID,
        userMessageId: AgentMessageID? = nil,
        assistantMessageId: AgentMessageID? = nil,
        status: AgentRunStatus = .planned,
        plan: AgentExecutionPlan,
        modelProviderID: String? = nil,
        modelCapability: ModelProviderCapability? = nil,
        promptTemplateID: String? = nil,
        modelInputScope: ModelProviderInputScope? = nil,
        sentDataOffDevice: Bool = false,
        startedAt: Date = .now,
        finishedAt: Date? = nil
    ) {
        self.init(
            conversationId: conversationId,
            userMessageId: userMessageId,
            assistantMessageId: assistantMessageId,
            status: status,
            intent: plan.intent,
            specialists: plan.specialists,
            plannedToolNames: plan.toolNames,
            unavailableToolNames: plan.unavailableToolNames,
            requiredScopes: plan.requiredScopes,
            contextRefs: plan.contextRefs,
            clarificationQuestion: plan.clarificationQuestion,
            rationale: plan.rationale,
            modelProviderID: modelProviderID,
            modelCapability: modelCapability,
            promptTemplateID: promptTemplateID,
            modelInputScope: modelInputScope,
            sentDataOffDevice: sentDataOffDevice,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }

    public var objectRef: ObjectRef {
        ObjectRef(kind: .agentRun, id: id.rawValue)
    }
}

public struct AgentMessage: Hashable, Codable, Sendable {
    public let id: AgentMessageID
    public let conversationId: AgentConversationID
    public var role: AgentMessageRole
    public var content: String
    public var sourceRefs: [ObjectRef]
    public var unresolvedQuestions: [String]
    public var providerID: String?
    public var promptTemplateID: String?
    public var sentDataOffDevice: Bool
    public let createdAt: Date

    public init(
        id: AgentMessageID = AgentMessageID(),
        conversationId: AgentConversationID,
        role: AgentMessageRole,
        content: String,
        sourceRefs: [ObjectRef] = [],
        unresolvedQuestions: [String] = [],
        providerID: String? = nil,
        promptTemplateID: String? = nil,
        sentDataOffDevice: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.conversationId = conversationId
        self.role = role
        self.content = content
        self.sourceRefs = sourceRefs
        self.unresolvedQuestions = unresolvedQuestions
        self.providerID = providerID
        self.promptTemplateID = promptTemplateID
        self.sentDataOffDevice = sentDataOffDevice
        self.createdAt = createdAt
    }
}

public struct AgentPendingApproval: Hashable, Codable, Sendable {
    public let id: AgentPendingApprovalID
    public let conversationId: AgentConversationID
    public var toolName: String
    public var inputHash: String
    public var inputSummary: String
    public var requiredScopes: [AgentToolScope]
    public var targetRefs: [ObjectRef]
    public var status: AgentPendingApprovalStatus
    public var requestedBy: String
    public let requestedAt: Date
    public var decidedBy: String?
    public var decidedAt: Date?
    public var decisionReason: String?

    public init(
        id: AgentPendingApprovalID = AgentPendingApprovalID(),
        conversationId: AgentConversationID,
        toolName: String,
        inputHash: String,
        inputSummary: String,
        requiredScopes: [AgentToolScope],
        targetRefs: [ObjectRef] = [],
        status: AgentPendingApprovalStatus = .pending,
        requestedBy: String,
        requestedAt: Date = .now,
        decidedBy: String? = nil,
        decidedAt: Date? = nil,
        decisionReason: String? = nil
    ) {
        self.id = id
        self.conversationId = conversationId
        self.toolName = toolName
        self.inputHash = inputHash
        self.inputSummary = inputSummary
        self.requiredScopes = requiredScopes
        self.targetRefs = targetRefs
        self.status = status
        self.requestedBy = requestedBy
        self.requestedAt = requestedAt
        self.decidedBy = decidedBy
        self.decidedAt = decidedAt
        self.decisionReason = decisionReason
    }

    public func confirmation() -> AgentToolConfirmation? {
        guard status == .approved,
              let decidedBy,
              let decisionReason,
              let decidedAt
        else {
            return nil
        }

        return AgentToolConfirmation(
            toolName: toolName,
            approvedInputHash: inputHash,
            approvedBy: decidedBy,
            approvedAt: decidedAt,
            reason: decisionReason
        )
    }
}
