import Foundation
import Testing
@testable import ALDomain
@testable import ALStorage
@testable import ALWorkspace

@Test
func agentConversationStoragePersistsHistoryRefsAndPendingApprovals() throws {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Copilot Storage Workspace")
    let entity = try #require(
        try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first
    )
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
    let createdAt = try #require(ISO8601DateFormatter().date(from: "2026-05-30T08:00:00Z"))
    let decidedAt = try #require(ISO8601DateFormatter().date(from: "2026-05-30T08:05:00Z"))

    var conversation = AgentConversation(
        workspaceId: storage.manifest.workspace.id,
        title: "Zurich 2026 readiness",
        activeEntityId: entity.id,
        activeTaxYearId: taxYear.id,
        createdAt: createdAt,
        updatedAt: createdAt
    )
    try storage.agentConversationRepository.saveConversation(conversation)

    let userMessage = AgentMessage(
        conversationId: conversation.id,
        role: .user,
        content: "What is missing for my Zurich tax return?",
        createdAt: createdAt
    )
    let taxYearRef = ObjectRef(kind: .taxYear, id: taxYear.id.rawValue)
    let assistantMessage = AgentMessage(
        conversationId: conversation.id,
        role: .assistant,
        content: "One blocker still needs review.",
        sourceRefs: [taxYearRef],
        unresolvedQuestions: ["Which salary certificate should support the return?"],
        providerID: "local.rules",
        promptTemplateID: "tax.readiness.answer.v1",
        sentDataOffDevice: false,
        createdAt: createdAt.addingTimeInterval(1)
    )
    try storage.agentConversationRepository.saveMessage(userMessage)
    try storage.agentConversationRepository.saveMessage(assistantMessage)

    let reviewedInput = Data(#"{"entryNumber":"JE-2026-001"}"#.utf8)
    var approval = AgentPendingApproval(
        conversationId: conversation.id,
        toolName: "ledger.apply_draft_entry",
        inputHash: AgentToolInputHash.hash(reviewedInput),
        inputSummary: "Post reviewed year-end journal entry JE-2026-001.",
        requiredScopes: [.ledgerWrite],
        targetRefs: [taxYearRef],
        requestedBy: "assistant",
        requestedAt: createdAt.addingTimeInterval(2)
    )
    try storage.agentConversationRepository.savePendingApproval(approval)

    conversation.status = .archived
    conversation.updatedAt = createdAt.addingTimeInterval(3)
    try storage.agentConversationRepository.saveConversation(conversation)

    let conversations = try storage.agentConversationRepository.fetchConversations(
        workspaceId: storage.manifest.workspace.id,
        status: nil
    )
    #expect(conversations.map(\.id) == [conversation.id])
    #expect(conversations.first?.status == .archived)
    #expect(conversations.first?.activeEntityId == entity.id)
    #expect(conversations.first?.activeTaxYearId == taxYear.id)

    let messages = try storage.agentConversationRepository.fetchMessages(conversationId: conversation.id)
    #expect(messages.map(\.role) == [.user, .assistant])
    #expect(messages.last?.sourceRefs == [taxYearRef])
    #expect(messages.last?.unresolvedQuestions == ["Which salary certificate should support the return?"])
    #expect(messages.last?.sentDataOffDevice == false)

    let pendingApprovals = try storage.agentConversationRepository.fetchPendingApprovals(
        conversationId: conversation.id,
        status: .pending
    )
    #expect(pendingApprovals.map(\.id) == [approval.id])
    #expect(pendingApprovals.first?.requiredScopes == [.ledgerWrite])
    #expect(pendingApprovals.first?.targetRefs == [taxYearRef])

    approval.status = .approved
    approval.decidedBy = "reviewer"
    approval.decidedAt = decidedAt
    approval.decisionReason = "Reviewed the draft entry and supporting year-end checklist."
    try storage.agentConversationRepository.savePendingApproval(approval)

    let routingPlan = AgentRouter().plan(
        for: userMessage.content,
        context: AgentRouterContext(
            workspaceId: storage.manifest.workspace.id,
            activeEntityId: entity.id,
            activeTaxYearId: taxYear.id,
            canton: taxYear.canton
        )
    )
    var run = AgentRunTrace(
        conversationId: conversation.id,
        userMessageId: userMessage.id,
        assistantMessageId: assistantMessage.id,
        status: .completed,
        plan: routingPlan,
        modelProviderID: "local.rules",
        modelCapability: .taxExplanation,
        promptTemplateID: "tax.readiness.answer.v1",
        modelInputScope: .metadataOnly,
        sentDataOffDevice: false,
        startedAt: createdAt.addingTimeInterval(1),
        finishedAt: decidedAt
    )
    run.toolCalls = [
        AgentRunToolCall(
            toolName: "tax.preview_status",
            inputHash: AgentToolInputHash.hash(Data(#"{"scope":"tax-readiness"}"#.utf8)),
            outcome: .executed,
            provenanceRefs: [taxYearRef],
            durationMilliseconds: 12,
            finishedAt: createdAt.addingTimeInterval(2)
        ),
        AgentRunToolCall(
            toolName: "ledger.apply_draft_entry",
            inputHash: approval.inputHash,
            outcome: .planned,
            provenanceRefs: [taxYearRef],
            finishedAt: createdAt.addingTimeInterval(3)
        ),
    ]
    run.approvalDecisions = [AgentRunApprovalDecision(approval: approval)]
    try storage.agentConversationRepository.saveAgentRun(run)

    let approved = try #require(
        try storage.agentConversationRepository.fetchPendingApproval(id: approval.id)
    )
    let confirmation = try #require(approved.confirmation())
    let invocation = AgentToolInvocation(
        toolName: "ledger.apply_draft_entry",
        inputJSON: reviewedInput,
        grantedScopes: [.ledgerWrite]
    )
    #expect(confirmation.isExplicitApproval(for: invocation))

    let runs = try storage.agentConversationRepository.fetchAgentRuns(conversationId: conversation.id)
    #expect(runs.map(\.id) == [run.id])
    #expect(runs.first?.intent == .missingTaxEvidence)
    #expect(runs.first?.specialists == [.personalTax, .missingEvidence])
    #expect(runs.first?.plannedToolNames == routingPlan.toolNames)
    #expect(runs.first?.contextRefs == routingPlan.contextRefs)
    #expect(runs.first?.modelProviderID == "local.rules")
    #expect(runs.first?.modelCapability == .taxExplanation)
    #expect(runs.first?.promptTemplateID == "tax.readiness.answer.v1")
    #expect(runs.first?.modelInputScope == .metadataOnly)
    #expect(runs.first?.sentDataOffDevice == false)
    #expect(runs.first?.toolCalls.map(\.toolName) == ["tax.preview_status", "ledger.apply_draft_entry"])
    #expect(runs.first?.approvalDecisions.map(\.status) == [.approved])

    let fetchedRun = try #require(try storage.agentConversationRepository.fetchAgentRun(id: run.id))
    #expect(fetchedRun.objectRef == ObjectRef(kind: .agentRun, id: run.id.rawValue))
    #expect(fetchedRun.approvalDecisions.first?.decidedBy == "reviewer")
    #expect(fetchedRun.approvalDecisions.first?.decisionReason == "Reviewed the draft entry and supporting year-end checklist.")
    #expect(try storage.databaseHealthReport().isHealthy)
}
