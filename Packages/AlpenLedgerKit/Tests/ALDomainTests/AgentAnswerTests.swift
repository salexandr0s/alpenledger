import Foundation
import Testing
@testable import ALDomain

@Test
func agentAnswerComposerBuildsOnlyCitedAnswersFromToolGrounding() throws {
    let transactionRef = ObjectRef(kind: .transaction, id: "txn-1")
    let issueRef = ObjectRef(kind: .issue, id: "issue-1")
    let toolResult = AgentToolExecutionResult(
        outputJSON: Data(#"{"total":1250}"#.utf8),
        provenanceRefs: [transactionRef, issueRef]
    )
    let draft = AgentAnswerDraft(
        question: "Why is this expense still open?",
        claims: [
            AgentAnswerClaim(
                text: "The transaction is still awaiting supporting evidence.",
                kind: .observedFact,
                sourceRefs: [transactionRef, issueRef]
            ),
            AgentAnswerClaim(
                text: "Upload or link the missing receipt before treating the issue as resolved.",
                kind: .agentSuggestion,
                sourceRefs: [issueRef]
            ),
        ],
        confidence: 0.82,
        unresolvedQuestions: ["Which receipt should support this transaction?"]
    )

    let answer = try AgentAnswerComposer().compose(
        draft: draft,
        groundingSet: AgentAnswerGroundingSet(toolResults: [toolResult]),
        createdAt: Date(timeIntervalSince1970: 0)
    )

    #expect(answer.question == "Why is this expense still open?")
    #expect(answer.sourceRefs == [transactionRef, issueRef])
    #expect(answer.confidence == 0.82)
    #expect(answer.unresolvedQuestions == ["Which receipt should support this transaction?"])
    #expect(answer.renderedMarkdown.contains("`transaction|txn-1`"))
    #expect(answer.renderedMarkdown.contains("`issue|issue-1`"))
}

@Test
func agentAnswerComposerAcceptsModelResponseSourcesAsGrounding() throws {
    let documentRef = ObjectRef(kind: .document, id: "doc-1")
    let modelResponse = ModelProviderResponse(
        providerID: "local.rules",
        capability: .reconciliationExplanation,
        outputText: "receipt supports transaction",
        sourceRefs: [documentRef],
        sentDataOffDevice: false
    )
    let draft = AgentAnswerDraft(
        question: "What supports this match?",
        claims: [
            AgentAnswerClaim(
                text: "The local model response cited the receipt document.",
                kind: .observedFact,
                sourceRefs: [documentRef]
            ),
        ]
    )

    let answer = try AgentAnswerComposer().compose(
        draft: draft,
        groundingSet: AgentAnswerGroundingSet(toolResults: [], modelResponses: [modelResponse])
    )

    #expect(answer.sourceRefs == [documentRef])
}

@Test
func agentAnswerComposerRejectsUncitedClaims() {
    let draft = AgentAnswerDraft(
        question: "Can I file now?",
        claims: [
            AgentAnswerClaim(
                text: "You are ready to file.",
                kind: .derivedValue,
                sourceRefs: []
            ),
        ]
    )

    #expect(throws: AgentAnswerValidationError.uncitedClaim(index: 0)) {
        _ = try AgentAnswerComposer().compose(
            draft: draft,
            groundingSet: AgentAnswerGroundingSet(sourceRefs: [])
        )
    }
}

@Test
func agentAnswerComposerRejectsUnknownCitations() {
    let citedRef = ObjectRef(kind: .taxFact, id: "fact-1")
    let groundedRef = ObjectRef(kind: .taxYear, id: "year-1")
    let draft = AgentAnswerDraft(
        question: "What changed?",
        claims: [
            AgentAnswerClaim(
                text: "The salary fact changed.",
                kind: .observedFact,
                sourceRefs: [citedRef]
            ),
        ]
    )

    #expect(throws: AgentAnswerValidationError.unknownCitation(index: 0, sourceRef: citedRef)) {
        _ = try AgentAnswerComposer().compose(
            draft: draft,
            groundingSet: AgentAnswerGroundingSet(sourceRefs: [groundedRef])
        )
    }
}

@Test
func agentAnswerComposerRejectsInvalidConfidenceAndEmptyQuestions() {
    let transactionRef = ObjectRef(kind: .transaction, id: "txn-1")
    let claim = AgentAnswerClaim(
        text: "The transaction exists.",
        kind: .observedFact,
        sourceRefs: [transactionRef]
    )

    #expect(throws: AgentAnswerValidationError.emptyQuestion) {
        _ = try AgentAnswerComposer().compose(
            draft: AgentAnswerDraft(question: "   ", claims: [claim]),
            groundingSet: AgentAnswerGroundingSet(sourceRefs: [transactionRef])
        )
    }

    #expect(throws: AgentAnswerValidationError.invalidConfidence(1.1)) {
        _ = try AgentAnswerComposer().compose(
            draft: AgentAnswerDraft(question: "What happened?", claims: [claim], confidence: 1.1),
            groundingSet: AgentAnswerGroundingSet(sourceRefs: [transactionRef])
        )
    }
}
