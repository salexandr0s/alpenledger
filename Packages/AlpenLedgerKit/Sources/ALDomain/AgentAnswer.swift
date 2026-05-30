import Foundation

public enum AgentAnswerClaimKind: String, Codable, CaseIterable, Sendable {
    case observedFact
    case derivedValue
    case userOverride
    case agentSuggestion
    case missingInformation
}

public struct AgentAnswerClaim: Hashable, Codable, Sendable {
    public let text: String
    public let kind: AgentAnswerClaimKind
    public let sourceRefs: [ObjectRef]

    public init(
        text: String,
        kind: AgentAnswerClaimKind,
        sourceRefs: [ObjectRef]
    ) {
        self.text = text
        self.kind = kind
        self.sourceRefs = sourceRefs
    }
}

public struct AgentAnswerDraft: Hashable, Sendable {
    public let question: String
    public let claims: [AgentAnswerClaim]
    public let confidence: Double?
    public let unresolvedQuestions: [String]

    public init(
        question: String,
        claims: [AgentAnswerClaim],
        confidence: Double? = nil,
        unresolvedQuestions: [String] = []
    ) {
        self.question = question
        self.claims = claims
        self.confidence = confidence
        self.unresolvedQuestions = unresolvedQuestions
    }
}

public struct AgentAnswerGroundingSet: Hashable, Sendable {
    public let sourceRefs: Set<ObjectRef>

    public init(sourceRefs: Set<ObjectRef>) {
        self.sourceRefs = sourceRefs
    }

    public init(
        toolResults: [AgentToolExecutionResult],
        modelResponses: [ModelProviderResponse] = []
    ) {
        var refs = Set<ObjectRef>()
        for result in toolResults {
            refs.formUnion(result.provenanceRefs)
        }
        for response in modelResponses {
            refs.formUnion(response.sourceRefs)
        }
        self.sourceRefs = refs
    }
}

public struct ProvenanceBackedAgentAnswer: Hashable, Codable, Sendable {
    public let question: String
    public let claims: [AgentAnswerClaim]
    public let sourceRefs: [ObjectRef]
    public let confidence: Double?
    public let unresolvedQuestions: [String]
    public let createdAt: Date

    public var renderedMarkdown: String {
        claims.map { claim in
            let sources = claim.sourceRefs
                .map { "`\($0.stringValue)`" }
                .joined(separator: ", ")
            return "- \(claim.text) _\(claim.kind.rawValue)_ Sources: \(sources)"
        }
        .joined(separator: "\n")
    }
}

public enum AgentAnswerValidationError: Error, Hashable, Sendable {
    case emptyQuestion
    case emptyClaims
    case emptyClaimText(index: Int)
    case uncitedClaim(index: Int)
    case unknownCitation(index: Int, sourceRef: ObjectRef)
    case invalidConfidence(Double)
    case emptyUnresolvedQuestion(index: Int)
}

public struct AgentAnswerComposer: Sendable {
    public init() {}

    public func compose(
        draft: AgentAnswerDraft,
        groundingSet: AgentAnswerGroundingSet,
        createdAt: Date = .now
    ) throws -> ProvenanceBackedAgentAnswer {
        let question = draft.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard question.isEmpty == false else {
            throw AgentAnswerValidationError.emptyQuestion
        }
        guard draft.claims.isEmpty == false else {
            throw AgentAnswerValidationError.emptyClaims
        }
        if let confidence = draft.confidence, confidence.isNaN || confidence < 0 || confidence > 1 {
            throw AgentAnswerValidationError.invalidConfidence(confidence)
        }

        var normalizedClaims: [AgentAnswerClaim] = []
        var orderedRefs: [ObjectRef] = []
        var seenRefs = Set<ObjectRef>()

        for (index, claim) in draft.claims.enumerated() {
            let text = claim.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false else {
                throw AgentAnswerValidationError.emptyClaimText(index: index)
            }
            guard claim.sourceRefs.isEmpty == false else {
                throw AgentAnswerValidationError.uncitedClaim(index: index)
            }

            var normalizedClaimRefs: [ObjectRef] = []
            var seenClaimRefs = Set<ObjectRef>()
            for sourceRef in claim.sourceRefs {
                guard groundingSet.sourceRefs.contains(sourceRef) else {
                    throw AgentAnswerValidationError.unknownCitation(index: index, sourceRef: sourceRef)
                }
                if seenClaimRefs.insert(sourceRef).inserted {
                    normalizedClaimRefs.append(sourceRef)
                }
                if seenRefs.insert(sourceRef).inserted {
                    orderedRefs.append(sourceRef)
                }
            }

            normalizedClaims.append(AgentAnswerClaim(
                text: text,
                kind: claim.kind,
                sourceRefs: normalizedClaimRefs
            ))
        }

        let unresolvedQuestions = try draft.unresolvedQuestions.enumerated().map { index, question in
            let normalized = question.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.isEmpty == false else {
                throw AgentAnswerValidationError.emptyUnresolvedQuestion(index: index)
            }
            return normalized
        }

        return ProvenanceBackedAgentAnswer(
            question: question,
            claims: normalizedClaims,
            sourceRefs: orderedRefs,
            confidence: draft.confidence,
            unresolvedQuestions: unresolvedQuestions,
            createdAt: createdAt
        )
    }
}
