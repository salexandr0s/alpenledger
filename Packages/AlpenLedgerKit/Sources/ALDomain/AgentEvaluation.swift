import Foundation

public struct AgentEvaluationSuite: Hashable, Codable, Sendable {
    public let schemaVersion: Int
    public let routingCases: [AgentRoutingEvaluationCase]

    public init(schemaVersion: Int, routingCases: [AgentRoutingEvaluationCase]) {
        self.schemaVersion = schemaVersion
        self.routingCases = routingCases
    }
}

public struct AgentRoutingEvaluationContext: Hashable, Codable, Sendable {
    public let hasWorkspace: Bool
    public let hasEntity: Bool
    public let hasTaxYear: Bool
    public let cantonCode: String?

    public init(
        hasWorkspace: Bool = false,
        hasEntity: Bool = false,
        hasTaxYear: Bool = false,
        cantonCode: String? = nil
    ) {
        self.hasWorkspace = hasWorkspace
        self.hasEntity = hasEntity
        self.hasTaxYear = hasTaxYear
        self.cantonCode = cantonCode
    }

    public func routerContext() -> AgentRouterContext {
        AgentRouterContext(
            workspaceId: hasWorkspace ? Self.fixtureWorkspaceId : nil,
            activeEntityId: hasEntity ? Self.fixtureEntityId : nil,
            activeTaxYearId: hasTaxYear ? Self.fixtureTaxYearId : nil,
            canton: cantonCode.flatMap(CantonCode.init(rawValue:))
        )
    }

    public static let fixtureWorkspaceId = WorkspaceID(rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
    public static let fixtureEntityId = LegalEntityID(rawValue: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
    public static let fixtureTaxYearId = TaxYearID(rawValue: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!)
}

public struct AgentRoutingEvaluationCase: Hashable, Codable, Sendable {
    public let id: String
    public let message: String
    public let context: AgentRoutingEvaluationContext
    public let expectedIntent: AgentIntent
    public let expectedSpecialists: [AgentSpecialist]
    public let expectedToolNames: [String]
    public let forbiddenToolNames: [String]
    public let expectedClarificationQuestion: String?

    public init(
        id: String,
        message: String,
        context: AgentRoutingEvaluationContext = AgentRoutingEvaluationContext(),
        expectedIntent: AgentIntent,
        expectedSpecialists: [AgentSpecialist],
        expectedToolNames: [String],
        forbiddenToolNames: [String] = [],
        expectedClarificationQuestion: String? = nil
    ) {
        self.id = id
        self.message = message
        self.context = context
        self.expectedIntent = expectedIntent
        self.expectedSpecialists = expectedSpecialists
        self.expectedToolNames = expectedToolNames
        self.forbiddenToolNames = forbiddenToolNames
        self.expectedClarificationQuestion = expectedClarificationQuestion
    }
}

public enum AgentEvaluationFailure: Hashable, Sendable {
    case emptyCaseID
    case emptyMessage(caseID: String)
    case invalidCanton(caseID: String, cantonCode: String)
    case intentMismatch(caseID: String, expected: AgentIntent, actual: AgentIntent)
    case specialistsMismatch(caseID: String, expected: [AgentSpecialist], actual: [AgentSpecialist])
    case toolPlanMismatch(caseID: String, expected: [String], actual: [String])
    case forbiddenToolPlanned(caseID: String, toolName: String)
    case unavailableTools(caseID: String, toolNames: [String])
    case clarificationMismatch(caseID: String, expected: String?, actual: String?)
}

public struct AgentEvaluationCaseResult: Hashable, Sendable {
    public let caseID: String
    public let plan: AgentExecutionPlan?
    public let failures: [AgentEvaluationFailure]

    public init(
        caseID: String,
        plan: AgentExecutionPlan?,
        failures: [AgentEvaluationFailure]
    ) {
        self.caseID = caseID
        self.plan = plan
        self.failures = failures
    }

    public var passed: Bool {
        failures.isEmpty
    }
}

public struct AgentEvaluationReport: Hashable, Sendable {
    public let caseResults: [AgentEvaluationCaseResult]

    public init(caseResults: [AgentEvaluationCaseResult]) {
        self.caseResults = caseResults
    }

    public var passed: Bool {
        failures.isEmpty
    }

    public var failures: [AgentEvaluationFailure] {
        caseResults.flatMap(\.failures)
    }

    public var passedCaseIDs: [String] {
        caseResults.filter(\.passed).map(\.caseID)
    }
}

public struct AgentEvaluationHarness: Sendable {
    private let router: AgentRouter

    public init(router: AgentRouter = AgentRouter()) {
        self.router = router
    }

    public func evaluate(_ suite: AgentEvaluationSuite) -> AgentEvaluationReport {
        evaluateRoutingCases(suite.routingCases)
    }

    public func evaluateRoutingCases(_ cases: [AgentRoutingEvaluationCase]) -> AgentEvaluationReport {
        AgentEvaluationReport(caseResults: cases.map(evaluateRoutingCase))
    }

    private func evaluateRoutingCase(_ evaluationCase: AgentRoutingEvaluationCase) -> AgentEvaluationCaseResult {
        var failures: [AgentEvaluationFailure] = []

        if evaluationCase.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyCaseID)
        }
        if evaluationCase.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            failures.append(.emptyMessage(caseID: evaluationCase.id))
        }
        if let cantonCode = evaluationCase.context.cantonCode,
           CantonCode(rawValue: cantonCode) == nil {
            failures.append(.invalidCanton(caseID: evaluationCase.id, cantonCode: cantonCode))
        }

        let plan = router.plan(
            for: evaluationCase.message,
            context: evaluationCase.context.routerContext()
        )

        if plan.intent != evaluationCase.expectedIntent {
            failures.append(.intentMismatch(
                caseID: evaluationCase.id,
                expected: evaluationCase.expectedIntent,
                actual: plan.intent
            ))
        }
        if plan.specialists != evaluationCase.expectedSpecialists {
            failures.append(.specialistsMismatch(
                caseID: evaluationCase.id,
                expected: evaluationCase.expectedSpecialists,
                actual: plan.specialists
            ))
        }
        if plan.toolNames != evaluationCase.expectedToolNames {
            failures.append(.toolPlanMismatch(
                caseID: evaluationCase.id,
                expected: evaluationCase.expectedToolNames,
                actual: plan.toolNames
            ))
        }
        for forbiddenToolName in evaluationCase.forbiddenToolNames where plan.toolNames.contains(forbiddenToolName) {
            failures.append(.forbiddenToolPlanned(caseID: evaluationCase.id, toolName: forbiddenToolName))
        }
        if plan.unavailableToolNames.isEmpty == false {
            failures.append(.unavailableTools(caseID: evaluationCase.id, toolNames: plan.unavailableToolNames))
        }
        if plan.clarificationQuestion != evaluationCase.expectedClarificationQuestion {
            failures.append(.clarificationMismatch(
                caseID: evaluationCase.id,
                expected: evaluationCase.expectedClarificationQuestion,
                actual: plan.clarificationQuestion
            ))
        }

        return AgentEvaluationCaseResult(
            caseID: evaluationCase.id,
            plan: plan,
            failures: failures
        )
    }
}
