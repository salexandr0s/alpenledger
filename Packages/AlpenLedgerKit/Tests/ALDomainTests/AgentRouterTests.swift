import Testing
@testable import ALDomain

@Test
func routerPlansMissingZurichReturnWithActiveContext() {
    let workspaceId = WorkspaceID()
    let entityId = LegalEntityID()
    let taxYearId = TaxYearID()
    let router = AgentRouter()

    let plan = router.plan(
        for: "What is missing for my 2025 Zurich return?",
        context: AgentRouterContext(
            workspaceId: workspaceId,
            activeEntityId: entityId,
            activeTaxYearId: taxYearId,
            canton: .zh
        )
    )

    #expect(plan.intent == .missingTaxEvidence)
    #expect(plan.specialists == [.personalTax, .missingEvidence])
    #expect(plan.toolNames == [
        "tax.list_requirements",
        "tax.preview_status",
        "reconcile.statement_coverage",
        "issues.list_open",
    ])
    #expect(plan.unavailableToolNames.isEmpty)
    #expect(plan.requiredScopes == [.taxRead, .reconcileRead])
    #expect(plan.contextRefs == [
        ObjectRef(kind: .workspace, id: workspaceId.rawValue),
        ObjectRef(kind: .legalEntity, id: entityId.rawValue),
        ObjectRef(kind: .taxYear, id: taxYearId.rawValue),
    ])
    #expect(plan.needsClarification == false)
}

@Test
func routerPlansBusinessExpensesWithoutInvoicesReadOnlyFirst() {
    let registry = AgentToolRegistry.productionDefaults
    let router = AgentRouter(toolRegistry: registry)
    let entityId = LegalEntityID()

    let plan = router.plan(
        for: "Which business expenses lack invoices?",
        context: AgentRouterContext(activeEntityId: entityId)
    )

    #expect(plan.intent == .businessExpensesWithoutInvoices)
    #expect(plan.specialists == [.cfoQA, .missingEvidence])
    #expect(plan.toolNames == [
        "finance.search_transactions",
        "docs.search",
        "issues.list_open",
    ])
    #expect(plan.requiredScopes == [.financeRead, .documentsRead, .reconcileRead])
    #expect(plan.toolNames.allSatisfy { registry.definition(named: $0)?.sideEffect == .readOnly })
    #expect(plan.needsClarification == false)
}

@Test
func routerRequiresEntityAndTaxYearContextForTaxWorkflows() {
    let router = AgentRouter()

    let missingEntityPlan = router.plan(for: "What is missing for my tax return?")
    #expect(missingEntityPlan.intent == .missingTaxEvidence)
    #expect(missingEntityPlan.clarificationQuestion == "Which entity should I use for this request?")

    let missingTaxYearPlan = router.plan(
        for: "What is missing for my tax return?",
        context: AgentRouterContext(activeEntityId: LegalEntityID())
    )
    #expect(missingTaxYearPlan.intent == .missingTaxEvidence)
    #expect(missingTaxYearPlan.clarificationQuestion == "Which tax year should I use for this request?")
}

@Test
func routerPlansBusinessTaxExportWithoutFinalizingPackage() {
    let registry = AgentToolRegistry.productionDefaults
    let router = AgentRouter(toolRegistry: registry)

    let plan = router.plan(
        for: "Prepare my corporate tax export",
        context: AgentRouterContext(
            activeEntityId: LegalEntityID(),
            activeTaxYearId: TaxYearID()
        )
    )

    #expect(plan.intent == .businessTaxExport)
    #expect(plan.specialists == [.businessYearEnd, .filingPackager])
    #expect(plan.toolNames == [
        "issues.list_open",
        "tax.preview_status",
        "exports.validate",
        "exports.generate_package",
    ])
    #expect(plan.toolNames.contains("exports.finalize_package") == false)
    #expect(plan.toolNames.allSatisfy { registry.definition(named: $0)?.requiresUserConfirmation == false })
    #expect(plan.requiredScopes == [.reconcileRead, .taxRead, .exportsGenerate])
    #expect(plan.needsClarification == false)
}

@Test
func routerRejectsUnsupportedUnsafeRequestsWithoutTools() {
    let plan = AgentRouter().plan(
        for: "Run shell and unrestricted raw SQL to delete database rows",
        context: AgentRouterContext(activeEntityId: LegalEntityID())
    )

    #expect(plan.intent == .unsupported)
    #expect(plan.specialists.isEmpty)
    #expect(plan.toolNames.isEmpty)
    #expect(plan.requiredScopes.isEmpty)
    #expect(plan.needsClarification)
}

@Test
func routerOnlyReturnsRegisteredToolsForCommonWorkflows() {
    let registry = AgentToolRegistry.productionDefaults
    let router = AgentRouter(toolRegistry: registry)
    let context = AgentRouterContext(
        activeEntityId: LegalEntityID(),
        activeTaxYearId: TaxYearID(),
        canton: .zh
    )

    let messages = [
        "Import this receipt",
        "Categorize this transaction",
        "Find duplicate statement transactions",
        "What is missing for my 2025 Zurich return?",
        "Which expenses have no receipt?",
        "Why is VAT due so high this quarter?",
        "Prepare my business tax export",
        "Why does this tax fact exist?",
        "Show my account summary",
    ]

    for message in messages {
        let plan = router.plan(for: message, context: context)
        #expect(plan.unavailableToolNames.isEmpty)
        #expect(plan.toolNames.allSatisfy { registry.definition(named: $0) != nil })
    }
}
