import ALDesignSystem
import ALDomain
import ALFeatures

extension WorkspaceAppModel {

    // MARK: - Forwarding properties

    var workspaceName: String {
        session?.storage.manifest.workspace.name ?? "AlpenLedger"
    }

    var hasWorkspace: Bool { session != nil }
    var transactionCount: Int { transactions.count }
    var documentCount: Int { documents.count }
    var openIssueCount: Int { issues.count(where: { $0.status == .open }) }
    var pendingProposalCount: Int { agentProposals.count(where: { $0.status == .pending }) }
    var canImportCSV: Bool { hasWorkspace && (selectedAccountId != nil || financialAccounts.isEmpty == false) }
    var canImportDocument: Bool { hasWorkspace }
    var canImportSampleData: Bool { hasWorkspace }
    var currentSectionSubtitle: String { selectedSection.subtitle }
    var visibleTransactions: [Transaction] { transactions.filter { ledgerTransactionScope.matches($0) } }
    var visibleDocuments: [Document] {
        documents.filter { documentFilterScope.matches($0) && documentMatchesSearch($0) }
    }
    var ledgerInspectorButtonTitle: String { isLedgerInspectorVisible ? "Hide Inspector" : "Show Inspector" }
    var documentsInspectorButtonTitle: String { isDocumentsInspectorVisible ? "Hide Inspector" : "Show Inspector" }
    var activeInspectorToggleTitle: String {
        switch selectedSection {
        case .ledger:
            return ledgerInspectorButtonTitle
        case .documents:
            return documentsInspectorButtonTitle
        case .overview, .inbox, .taxStudio, .settings:
            return "Toggle Inspector"
        }
    }
    var selectedAccountTitle: String? { selectedAccountName }
    var selectedDocumentName: String? {
        documents.first(where: { $0.id == selectedDocumentId })?.originalFilename
    }
    var canToggleActiveInspector: Bool {
        hasWorkspace && (selectedSection == .ledger || selectedSection == .documents)
    }
    var canLinkSelectedDocument: Bool {
        selectedSection == .ledger && selectedTransactionId != nil
    }
    var canLinkSelectedTransaction: Bool {
        selectedSection == .documents && selectedDocumentId != nil
    }

    // MARK: - Snapshot computed properties

    var shellToolbarConfiguration: ShellToolbarConfiguration {
        switch selectedSection {
        case .ledger:
            return ShellToolbarConfiguration(
                title: workspaceName,
                subtitle: currentSectionSubtitle,
                inspectorControl: .init(
                    title: ledgerInspectorButtonTitle,
                    accessibilityIdentifier: "toolbar.ledger.toggleInspector"
                )
            )
        case .documents:
            return ShellToolbarConfiguration(
                title: workspaceName,
                subtitle: currentSectionSubtitle,
                inspectorControl: .init(
                    title: documentsInspectorButtonTitle,
                    accessibilityIdentifier: "toolbar.documents.toggleInspector"
                )
            )
        case .overview, .inbox, .taxStudio, .settings:
            return ShellToolbarConfiguration(
                title: workspaceName,
                subtitle: currentSectionSubtitle,
                inspectorControl: nil
            )
        }
    }

    var workspaceChooserSnapshot: WorkspaceChooserSnapshot {
        WorkspaceChooserSnapshot(
            title: "AlpenLedger",
            tagline: "Local-first bookkeeping and tax readiness for Swiss sole proprietors and natural persons.",
            trustLine: "Encrypted. Local. Yours.",
            recentWorkspaces: recentWorkspaces.map { reference in
                WorkspaceChooserSnapshot.RecentWorkspace(
                    reference: reference,
                    title: reference.name,
                    lastOpenedText: relativeDateString(for: reference.lastOpenedAt)
                )
            }
        )
    }

    var overviewSnapshot: OverviewSnapshot {
        OverviewSnapshot(
            workspaceName: workspaceName,
            workspaceSubtitle: workspaceSummarySubtitle,
            metrics: overviewMetrics,
            priorityAction: overviewPriorityAction,
            secondaryActions: overviewSecondaryActions,
            attentionItems: overviewAttentionItems,
            recentActivityItems: overviewRecentActivityItems,
            recentActivityEmptyTitle: "No recent imports",
            recentActivityActionTitle: "Import",
            recentActivityAction: canImportDocument ? .importDocument : nil
        )
    }

    var inboxSnapshot: InboxSnapshot {
        InboxSnapshot(
            tabs: [
                InboxTabSummary(tab: .issues, count: issues.count),
                InboxTabSummary(tab: .proposals, count: pendingProposalCount),
                InboxTabSummary(tab: .imports, count: importJobs.count),
            ],
            rows: inboxRows,
            inspector: inboxInspector
        )
    }

    var ledgerAccountSummaries: [LedgerAccountSummary] {
        financialAccounts.map { account in
            let balanceText: String
            let tone: StatusBadge.Tone
            if let balance = accountBalanceById[account.id] {
                balanceText = amountString(balance, currency: account.currency)
                tone = balance < 0 ? .warning : .neutral
            } else {
                balanceText = "Balance unavailable"
                tone = .neutral
            }

            return LedgerAccountSummary(
                id: account.id,
                title: account.displayName,
                subtitle: account.institutionName,
                accountTypeLabel: accountTypeLabel(account.accountType),
                balanceText: balanceText,
                statusText: account.closedAt == nil ? "Active" : "Closed",
                tone: tone,
                systemImage: symbol(for: account.accountType)
            )
        }
    }

    var documentBrowserItems: [DocumentBrowserItem] {
        visibleDocuments.map { document in
            DocumentBrowserItem(
                id: document.id,
                title: document.originalFilename,
                subtitle: documentTypeLabel(document.documentType),
                typeLabel: documentTypeLabel(document.documentType),
                dateLabel: formattedDate(document.issueDate),
                statusText: metadataLabel(document.metadataStatus),
                tone: document.metadataStatus == .confirmed ? .success : .warning,
                systemImage: documentSymbol(document.documentType),
                issueDate: document.issueDate,
                mediaType: document.mediaType
            )
        }
    }

    var taxStudioSnapshot: TaxStudioSnapshot {
        TaxStudioSnapshot(
            readinessTitle: readinessTitle(taxReadinessSummary.state),
            readinessSummary: "\(taxReadinessSummary.openIssueCount) open issues • \(taxReadinessSummary.pendingRequirementCount) pending requirements",
            readinessTone: readinessTone(taxReadinessSummary.state),
            checklistItems: taxChecklistItems,
            factCategories: taxFactCategories,
            inspector: taxInspector
        )
    }

    var settingsSnapshot: SettingsSnapshot {
        SettingsSnapshot(
            workspace: SettingsSnapshot.WorkspaceDetails(
                name: workspaceName,
                type: "Local encrypted workspace",
                location: session?.storage.paths.rootURL.path ?? "Not available",
                encryptionStatus: "Encrypted locally",
                createdAt: formattedDate(session?.storage.manifest.workspace.createdAt)
            ),
            entities: entities.map { entity in
                let deletionCheck = entityDeletionChecks[entity.id]
                return EntityRowModel(
                    id: entity.id,
                    name: entity.displayName,
                    kindLabel: entityKindLabel(entity.kind),
                    detail: entity.canton.map { "Canton \($0)" } ?? "Switzerland",
                    canRemove: deletionCheck?.canDelete ?? true,
                    removalHint: deletionRemovalHint(deletionCheck)
                )
            }
        )
    }

    // MARK: - Sidebar badge

    func sidebarBadgeText(for section: AppSection) -> String? {
        switch section {
        case .inbox:
            let total = openIssueCount + pendingProposalCount
            return total > 0 ? total.formatted() : nil
        case .ledger:
            return visibleTransactions.isEmpty ? nil : visibleTransactions.count.formatted()
        case .documents:
            return visibleDocuments.isEmpty ? nil : visibleDocuments.count.formatted()
        case .taxStudio:
            let total = taxReadinessSummary.openIssueCount + taxReadinessSummary.pendingRequirementCount
            return total > 0 ? total.formatted() : nil
        case .overview, .settings:
            return nil
        }
    }

    // MARK: - Supporting computed properties

    var workspaceSummarySubtitle: String {
        let entityLabel = "\(entities.count) \(entities.count == 1 ? "entity" : "entities")"
        let accountLabel = "\(financialAccounts.count) \(financialAccounts.count == 1 ? "account" : "accounts")"
        let documentLabel = "\(documents.count) \(documents.count == 1 ? "document" : "documents")"
        return [entityLabel, accountLabel, documentLabel].joined(separator: " • ")
    }

    var overviewMetrics: [OverviewSnapshot.MetricItem] {
        [
            OverviewSnapshot.MetricItem(
                id: "issues",
                title: "Open Issues",
                value: openIssueCount.formatted(),
                subtitle: openIssueCount == 0 ? "All clear" : "Need attention",
                tone: openIssueCount == 0 ? .success : .critical,
                systemImage: "exclamationmark.bubble"
            ),
            OverviewSnapshot.MetricItem(
                id: "requirements",
                title: "Pending Requirements",
                value: taxReadinessSummary.pendingRequirementCount.formatted(),
                subtitle: taxReadinessSummary.pendingRequirementCount == 0 ? "Complete" : "Still missing",
                tone: taxReadinessSummary.pendingRequirementCount == 0 ? .success : .warning,
                systemImage: "list.bullet.clipboard"
            ),
            OverviewSnapshot.MetricItem(
                id: "documents",
                title: "Documents",
                value: documentCount.formatted(),
                subtitle: latestImportSummary ?? "No imports yet",
                tone: documentCount == 0 ? .neutral : .info,
                systemImage: "doc.on.doc"
            ),
            OverviewSnapshot.MetricItem(
                id: "tax",
                title: "Tax Readiness",
                value: readinessTitle(taxReadinessSummary.state),
                subtitle: "\(taxReadinessSummary.currentFactCount) current facts",
                tone: readinessTone(taxReadinessSummary.state),
                systemImage: "checkmark.shield"
            ),
        ]
    }

    var overviewActionItems: [OverviewSnapshot.ActionItem] {
        var items: [OverviewSnapshot.ActionItem] = []

        if let issueSelection = firstOpenIssueSelection, openIssueCount > 0 {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "issues",
                    title: "Resolve open issues",
                    subtitle: "\(openIssueCount) issue\(openIssueCount == 1 ? "" : "s") are still blocking confidence in this workspace.",
                    buttonTitle: "Open Inbox",
                    systemImage: "tray.full",
                    action: .openInbox(selection: issueSelection)
                )
            )
        }

        if let proposalSelection = firstPendingProposalSelection, pendingProposalCount > 0 {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "proposals",
                    title: "Review pending proposals",
                    subtitle: "\(pendingProposalCount) suggestion\(pendingProposalCount == 1 ? "" : "s") still need a decision.",
                    buttonTitle: "Review Proposals",
                    systemImage: "wand.and.stars",
                    action: .openInbox(selection: proposalSelection)
                )
            )
        }

        if taxReadinessSummary.state != .readyForReview {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "tax",
                    title: "Check tax readiness",
                    subtitle: "\(taxReadinessSummary.pendingRequirementCount) pending requirements and \(taxReadinessSummary.missingConceptCodes.count) missing facts remain.",
                    buttonTitle: "Open Tax Studio",
                    systemImage: "checklist.checked",
                    action: .openTaxStudio(
                        entityId: selectedTaxEntityId,
                        taxYearId: selectedTaxYearId,
                        factId: nil
                    )
                )
            )
        }

        if let latestDocument = documents.first {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "documents",
                    title: "Review imported documents",
                    subtitle: "Inspect the latest evidence in the document vault.",
                    buttonTitle: "Open Documents",
                    systemImage: "doc.text.image",
                    action: .openDocuments(documentId: latestDocument.id)
                )
            )
        } else if let latestTransaction = visibleTransactions.first ?? transactions.first {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "ledger",
                    title: "Review imported transactions",
                    subtitle: "Classify and link transactions in the ledger.",
                    buttonTitle: "Open Ledger",
                    systemImage: "list.bullet.rectangle.portrait",
                    action: .openLedger(
                        accountId: latestTransaction.accountId,
                        transactionId: latestTransaction.id
                    )
                )
            )
        }

        if items.isEmpty {
            items.append(
                OverviewSnapshot.ActionItem(
                    id: "ready",
                    title: "Workspace looks healthy",
                    subtitle: "Use the sidebar to inspect details or import more data.",
                    buttonTitle: "Open Documents",
                    systemImage: "checkmark.circle",
                    action: .openDocuments(documentId: nil)
                )
            )
        }

        return items
    }

    var overviewPriorityAction: OverviewSnapshot.ActionItem? {
        overviewActionItems.first
    }

    var overviewSecondaryActions: [OverviewSnapshot.ActionItem] {
        Array(overviewActionItems.dropFirst().prefix(2))
    }

    var overviewAttentionItems: [OverviewSnapshot.AttentionItem] {
        let issueItems = issues
            .sorted { lhs, rhs in
                issuePriority(lhs.severity) > issuePriority(rhs.severity)
            }
            .prefix(3)
            .map { issue in
                OverviewSnapshot.AttentionItem(
                    id: issue.id.rawValue.uuidString,
                    title: shortIssueTitle(issue),
                    subtitle: entityName(for: issue.entityId) ?? "Workspace",
                    statusText: issue.severity == .blocking ? "Blocking" : "Pending",
                    tone: issue.severity == .blocking ? .critical : .warning,
                    systemImage: issue.severity == .blocking ? "exclamationmark.octagon" : "exclamationmark.triangle",
                    action: .openInbox(selection: .issue(issue.id))
                )
            }

        let proposalItems = agentProposals
            .filter { $0.status == .pending }
            .prefix(2)
            .map { proposal in
                OverviewSnapshot.AttentionItem(
                    id: proposal.id.rawValue.uuidString,
                    title: proposal.summary,
                    subtitle: proposal.rationale,
                    statusText: "Proposal",
                    tone: .info,
                    systemImage: "wand.and.stars",
                    action: .openInbox(selection: .proposal(proposal.id))
                )
            }

        let requirementItems = taxRequirements
            .prefix(2)
            .map { requirement in
                OverviewSnapshot.AttentionItem(
                    id: requirement.id.rawValue.uuidString,
                    title: shortRequirementTitle(requirement),
                    subtitle: entityName(for: requirement.entityId) ?? "Tax Studio",
                    statusText: "Missing",
                    tone: .warning,
                    systemImage: "list.bullet.clipboard",
                    action: .openTaxStudio(
                        entityId: requirement.entityId,
                        taxYearId: requirement.taxYearId,
                        factId: nil
                    )
                )
            }

        return Array((issueItems + proposalItems + requirementItems).prefix(4))
    }

    var overviewRecentActivityItems: [OverviewSnapshot.RecentActivityItem] {
        importJobs
            .sorted(by: importSortOrder)
            .prefix(4)
            .map { job in
                OverviewSnapshot.RecentActivityItem(
                    id: job.id.rawValue.uuidString,
                    title: job.source,
                    subtitle: "\(importKindLabel(job.kind)) • \(importTimestampLabel(job))",
                    statusText: importStatusLabel(job.status),
                    tone: tone(for: job.status)
                )
            }
    }

    var inboxRows: [InboxRowModel] {
        let issueRows = issues.map { issue in
            InboxRowModel(
                id: issue.id.rawValue.uuidString,
                selection: .issue(issue.id),
                tab: .issues,
                groupTitle: entityName(for: issue.entityId) ?? "Workspace",
                title: shortIssueTitle(issue),
                subtitle: issue.summary,
                meta: relativeDateString(for: issue.lastDetectedAt),
                statusText: issue.severity == .blocking ? "Blocking" : "Pending",
                tone: issue.severity == .blocking ? .critical : .warning,
                systemImage: issue.severity == .blocking ? "exclamationmark.octagon" : "exclamationmark.triangle",
                searchText: [issue.summary, entityName(for: issue.entityId) ?? "", issue.issueCode.rawValue].joined(separator: "\n")
            )
        }

        let proposalRows = agentProposals
            .filter { $0.status == .pending }
            .map { proposal in
                InboxRowModel(
                    id: proposal.id.rawValue.uuidString,
                    selection: .proposal(proposal.id),
                    tab: .proposals,
                    groupTitle: "Proposals",
                    title: proposal.summary,
                    subtitle: proposal.rationale,
                    meta: relativeDateString(for: proposal.createdAt),
                    statusText: "\(Int(proposal.confidence * 100))%",
                    tone: .info,
                    systemImage: "wand.and.stars",
                    searchText: [proposal.summary, proposal.rationale, proposal.targetRef.stringValue].joined(separator: "\n")
                )
            }

        let importRows = importJobs.map { job in
            InboxRowModel(
                id: job.id.rawValue.uuidString,
                selection: .importJob(job.id),
                tab: .imports,
                groupTitle: importKindLabel(job.kind),
                title: job.source,
                subtitle: importKindLabel(job.kind),
                meta: importTimestampLabel(job),
                statusText: importStatusLabel(job.status),
                tone: tone(for: job.status),
                systemImage: "tray.full",
                searchText: [job.source, importKindLabel(job.kind), importStatusLabel(job.status)].joined(separator: "\n")
            )
        }

        return issueRows + proposalRows + importRows
    }

    var inboxInspector: InboxInspectorModel? {
        guard let selection = selectedInboxSelection else { return nil }

        switch selection {
        case let .issue(issueId):
            guard let issue = issues.first(where: { $0.id == issueId }) else { return nil }
            return InboxInspectorModel(
                title: shortIssueTitle(issue),
                subtitle: entityName(for: issue.entityId) ?? "Workspace issue",
                statusText: issue.severity == .blocking ? "Blocking" : "Pending",
                tone: issue.severity == .blocking ? .critical : .warning,
                description: issue.summary,
                details: issueInspectorDetails(issue),
                actions: issueInspectorActions(issue)
            )
        case let .proposal(proposalId):
            guard let proposal = agentProposals.first(where: { $0.id == proposalId }) else { return nil }
            return InboxInspectorModel(
                title: proposal.summary,
                subtitle: "Proposal",
                statusText: "Pending",
                tone: .info,
                description: proposal.rationale,
                details: [
                    InboxInspectorDetail(id: "confidence", label: "Confidence", value: "\(Int(proposal.confidence * 100))%"),
                    InboxInspectorDetail(id: "target", label: "Target", value: proposal.targetRef.stringValue),
                ],
                actions: proposalInspectorActions(proposal)
            )
        case let .importJob(importJobId):
            guard let job = importJobs.first(where: { $0.id == importJobId }) else { return nil }
            return InboxInspectorModel(
                title: job.source,
                subtitle: importKindLabel(job.kind),
                statusText: importStatusLabel(job.status),
                tone: tone(for: job.status),
                description: "Import jobs are read-only. Use the document or ledger views to continue review.",
                details: [
                    InboxInspectorDetail(id: "kind", label: "Kind", value: importKindLabel(job.kind)),
                    InboxInspectorDetail(id: "parser", label: "Parser", value: "\(job.parserKey) \(job.parserVersion)"),
                    InboxInspectorDetail(id: "warnings", label: "Warnings", value: job.warningCount.formatted()),
                ],
                actions: []
            )
        }
    }

    var taxChecklistItems: [TaxChecklistItem] {
        let issueItems = taxIssues.map { issue in
            TaxChecklistItem(
                id: "issue-\(issue.id.rawValue.uuidString)",
                selection: .issue(issue.id),
                title: shortIssueTitle(issue),
                subtitle: issue.summary,
                statusText: issue.severity == .blocking ? "Blocking" : "Pending",
                tone: issue.severity == .blocking ? .critical : .warning,
                systemImage: issue.severity == .blocking ? "exclamationmark.octagon" : "exclamationmark.triangle"
            )
        }

        let requirementItems = taxRequirements.map { requirement in
            TaxChecklistItem(
                id: "requirement-\(requirement.id.rawValue.uuidString)",
                selection: .requirement(requirement.id),
                title: shortRequirementTitle(requirement),
                subtitle: requirement.summary,
                statusText: "Missing",
                tone: .warning,
                systemImage: "list.bullet.clipboard"
            )
        }

        let missingFactItems = taxReadinessSummary.missingConceptCodes.map { conceptCode in
            TaxChecklistItem(
                id: "concept-\(conceptCode)",
                selection: .missingConcept(conceptCode),
                title: factLabel(for: conceptCode),
                subtitle: "Add this fact to advance readiness.",
                statusText: "Missing fact",
                tone: .warning,
                systemImage: "questionmark.circle"
            )
        }

        return issueItems + requirementItems + missingFactItems
    }

    var taxFactCategories: [TaxFactCategoryModel] {
        [
            makeTaxFactCategory(
                id: "personal-income",
                title: "Personal Income",
                prefix: "personal.income."
            ),
            makeTaxFactCategory(
                id: "deductions",
                title: "Deductions",
                prefix: "personal.deduction."
            ),
            makeTaxFactCategory(
                id: "self-employment",
                title: "Self-Employment",
                prefix: "personal.self_employment."
            ),
        ]
    }

    var taxInspector: TaxInspectorModel? {
        guard let selection = selectedTaxStudioSelection ?? selectedTaxFactId.map(TaxStudioSelection.fact) else {
            return nil
        }

        switch selection {
        case let .fact(factId):
            guard let fact = taxFacts.first(where: { $0.id == factId }) else { return nil }
            return TaxInspectorModel(
                title: factLabel(for: fact.conceptCode),
                subtitle: "Tax fact",
                statusText: fact.status.rawValue.capitalized,
                tone: statusTone(fact.status),
                details: [
                    TaxInspectorDetail(id: "value", label: "Value", value: valueString(for: fact)),
                    TaxInspectorDetail(id: "concept", label: "Concept", value: fact.conceptCode),
                    TaxInspectorDetail(id: "ruleset", label: "Ruleset", value: fact.rulesetVersion),
                ],
                evidence: fact.provenanceRefs.map { ref in
                    DocumentReferenceRowModel(
                        id: ref.stringValue,
                        title: provenanceTitle(for: ref),
                        subtitle: ref.stringValue,
                        systemImage: provenanceSymbol(for: ref)
                    )
                }
            )
        case let .issue(issueId):
            guard let issue = taxIssues.first(where: { $0.id == issueId }) else { return nil }
            return TaxInspectorModel(
                title: shortIssueTitle(issue),
                subtitle: "Tax issue",
                statusText: issue.status.rawValue.capitalized,
                tone: issue.severity == .blocking ? .critical : .warning,
                details: issueInspectorDetails(issue).map { TaxInspectorDetail(id: $0.id, label: $0.label, value: $0.value) },
                evidence: issue.relatedRef.map {
                    [DocumentReferenceRowModel(id: $0.stringValue, title: "Related object", subtitle: $0.stringValue, systemImage: "link")]
                } ?? []
            )
        case let .requirement(requirementId):
            guard let requirement = taxRequirements.first(where: { $0.id == requirementId }) else { return nil }
            return TaxInspectorModel(
                title: shortRequirementTitle(requirement),
                subtitle: "Requirement",
                statusText: requirement.status.rawValue.capitalized,
                tone: .warning,
                details: [
                    TaxInspectorDetail(id: "subject", label: "Subject", value: requirement.subjectRef.stringValue),
                    TaxInspectorDetail(id: "coverage", label: "Coverage", value: coverageLabel(start: requirement.coverageStart, end: requirement.coverageEnd)),
                ],
                evidence: requirement.satisfiedByRef.map {
                    [DocumentReferenceRowModel(id: $0.stringValue, title: "Satisfied by", subtitle: $0.stringValue, systemImage: "checkmark.circle")]
                } ?? []
            )
        case let .missingConcept(conceptCode):
            return TaxInspectorModel(
                title: factLabel(for: conceptCode),
                subtitle: "Missing fact",
                statusText: "Not provided",
                tone: .warning,
                details: [
                    TaxInspectorDetail(id: "concept", label: "Concept", value: conceptCode),
                    TaxInspectorDetail(id: "guidance", label: "Guidance", value: "Add evidence or fact data to continue."),
                ],
                evidence: []
            )
        }
    }

    var latestImportSummary: String? {
        guard let latest = importJobs.sorted(by: importSortOrder).first else {
            return nil
        }
        return importTimestampLabel(latest)
    }

    var selectedAccountName: String? {
        financialAccounts.first(where: { $0.id == selectedAccountId })?.displayName
    }

    var firstOpenIssueSelection: InboxSelection? {
        issues
            .sorted { lhs, rhs in
                issuePriority(lhs.severity) > issuePriority(rhs.severity)
            }
            .first
            .map { .issue($0.id) }
    }

    var firstPendingProposalSelection: InboxSelection? {
        agentProposals
            .filter { $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
            .first
            .map { .proposal($0.id) }
    }

    // MARK: - Supporting methods

    func issueInspectorDetails(_ issue: Issue) -> [InboxInspectorDetail] {
        var details = [
            InboxInspectorDetail(id: "status", label: "Status", value: issue.status.rawValue.capitalized),
            InboxInspectorDetail(id: "object", label: "Object", value: issue.objectRef.stringValue),
        ]
        if let relatedRef = issue.relatedRef {
            details.append(InboxInspectorDetail(id: "related", label: "Related", value: relatedRef.stringValue))
        }
        return details
    }

    func issueInspectorActions(_ issue: Issue) -> [InboxInspectorAction] {
        var actions = [
            InboxInspectorAction(
                id: "resolve-\(issue.id.rawValue.uuidString)",
                title: "Resolve",
                role: .primary,
                action: .resolveIssue(issue.id)
            ),
            InboxInspectorAction(
                id: "dismiss-\(issue.id.rawValue.uuidString)",
                title: "Dismiss",
                role: .destructive,
                action: .dismissIssue(issue.id)
            ),
        ]

        switch issue.issueCode {
        case .missingStatementCoverage:
            let accountId = financialAccountId(from: issue.objectRef)
            actions.append(
                InboxInspectorAction(
                    id: "import-\(issue.id.rawValue.uuidString)",
                    title: "Import Statement…",
                    role: .secondary,
                    action: .importStatement(accountId)
                )
            )
        case .missingExpenseEvidence:
            if let transactionId = transactionId(from: issue.objectRef) {
                actions.append(
                    InboxInspectorAction(
                        id: "link-\(issue.id.rawValue.uuidString)",
                        title: "Link Document…",
                        role: .secondary,
                        action: .linkDocument(transactionId)
                    )
                )
            }
        }

        return actions
    }

    func proposalInspectorActions(_ proposal: AgentProposal) -> [InboxInspectorAction] {
        var actions = [
            InboxInspectorAction(
                id: "open-\(proposal.id.rawValue.uuidString)",
                title: "Open",
                role: .primary,
                action: .openProposalTarget(proposal.targetRef)
            ),
            InboxInspectorAction(
                id: "reject-\(proposal.id.rawValue.uuidString)",
                title: "Reject",
                role: .destructive,
                action: .rejectProposal(proposal.id)
            ),
        ]

        if proposal.targetRef.kind == .document, let documentId = documentId(from: proposal.targetRef) {
            actions.insert(
                InboxInspectorAction(
                    id: "link-\(proposal.id.rawValue.uuidString)",
                    title: "Link Transaction…",
                    role: .secondary,
                    action: .linkTransaction(documentId)
                ),
                at: 1
            )
        }

        return actions
    }

    func makeTaxFactCategory(id: String, title: String, prefix: String) -> TaxFactCategoryModel {
        let items = taxFacts
            .filter { $0.conceptCode.hasPrefix(prefix) }
            .map { fact in
                TaxFactRowModel(
                    id: fact.id,
                    selection: .fact(fact.id),
                    title: factLabel(for: fact.conceptCode),
                    value: valueString(for: fact),
                    statusText: fact.status.rawValue.capitalized,
                    tone: statusTone(fact.status),
                    systemImage: symbol(for: fact.status)
                )
            }
        let completionText = items.isEmpty ? "No data yet" : "\(items.count) fact\(items.count == 1 ? "" : "s")"
        return TaxFactCategoryModel(id: id, title: title, completionText: completionText, items: items)
    }
}
