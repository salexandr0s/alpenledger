import Foundation
import Testing
@testable import ALDomain

@Test
func agentEvaluationCatalogPassesRouterHarness() throws {
    let suite = try loadAgentEvaluationSuite()
    let report = AgentEvaluationHarness().evaluate(suite)

    #expect(suite.schemaVersion == 1)
    #expect(suite.routingCases.isEmpty == false)
    #expect(report.failures.isEmpty)
    #expect(report.passedCaseIDs == suite.routingCases.map(\.id))
}

@Test
func agentEvaluationHarnessReportsRoutingRegressions() {
    let caseID = "regression-probe"
    let report = AgentEvaluationHarness().evaluateRoutingCases([
        AgentRoutingEvaluationCase(
            id: caseID,
            message: "What is missing for my 2025 Zurich return?",
            context: AgentRoutingEvaluationContext(hasWorkspace: true, hasEntity: true, hasTaxYear: true, cantonCode: "ZH"),
            expectedIntent: .generalFinanceQuestion,
            expectedSpecialists: [.cfoQA],
            expectedToolNames: ["finance.account_summary"],
            forbiddenToolNames: ["tax.preview_status"],
            expectedClarificationQuestion: "Wrong question"
        ),
    ])

    #expect(report.passed == false)
    #expect(report.failures.contains(.intentMismatch(
        caseID: caseID,
        expected: .generalFinanceQuestion,
        actual: .missingTaxEvidence
    )))
    #expect(report.failures.contains(.specialistsMismatch(
        caseID: caseID,
        expected: [.cfoQA],
        actual: [.personalTax, .missingEvidence]
    )))
    #expect(report.failures.contains(.toolPlanMismatch(
        caseID: caseID,
        expected: ["finance.account_summary"],
        actual: [
            "tax.list_requirements",
            "tax.preview_status",
            "reconcile.statement_coverage",
            "issues.list_open",
        ]
    )))
    #expect(report.failures.contains(.forbiddenToolPlanned(caseID: caseID, toolName: "tax.preview_status")))
    #expect(report.failures.contains(.clarificationMismatch(
        caseID: caseID,
        expected: "Wrong question",
        actual: nil
    )))
}

@Test
func agentEvaluationHarnessFlagsInvalidCaseMetadata() {
    let report = AgentEvaluationHarness().evaluateRoutingCases([
        AgentRoutingEvaluationCase(
            id: " ",
            message: " ",
            context: AgentRoutingEvaluationContext(cantonCode: "XX"),
            expectedIntent: .unsupported,
            expectedSpecialists: [],
            expectedToolNames: []
        ),
    ])

    #expect(report.passed == false)
    #expect(report.failures.contains(.emptyCaseID))
    #expect(report.failures.contains(.emptyMessage(caseID: " ")))
    #expect(report.failures.contains(.invalidCanton(caseID: " ", cantonCode: "XX")))
}

private func loadAgentEvaluationSuite() throws -> AgentEvaluationSuite {
    let data = try Data(contentsOf: try fixtureURL("config/agent-evaluations.json"))
    return try JSONDecoder().decode(AgentEvaluationSuite.self, from: data)
}

private func fixtureURL(_ relativePath: String) throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return packageRoot.appendingPathComponent(relativePath)
}
