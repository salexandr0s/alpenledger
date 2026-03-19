import SwiftUI
import ALDesignSystem
import ALDomain
import ALTaxCore

@MainActor
public struct TaxStudioFeatureView: View {
    @Binding private var selectedEntityId: LegalEntityID?
    @Binding private var selectedTaxYearId: TaxYearID?
    @Binding private var selectedTaxFactId: TaxFactID?

    private let entities: [LegalEntity]
    private let taxYears: [TaxYear]
    private let taxFacts: [TaxFact]
    private let issues: [Issue]
    private let requirements: [Requirement]
    private let readinessSummary: TaxReadinessSummary

    public init(
        selectedEntityId: Binding<LegalEntityID?>,
        selectedTaxYearId: Binding<TaxYearID?>,
        selectedTaxFactId: Binding<TaxFactID?>,
        entities: [LegalEntity],
        taxYears: [TaxYear],
        taxFacts: [TaxFact],
        issues: [Issue],
        requirements: [Requirement],
        readinessSummary: TaxReadinessSummary
    ) {
        _selectedEntityId = selectedEntityId
        _selectedTaxYearId = selectedTaxYearId
        _selectedTaxFactId = selectedTaxFactId
        self.entities = entities
        self.taxYears = taxYears
        self.taxFacts = taxFacts
        self.issues = issues
        self.requirements = requirements
        self.readinessSummary = readinessSummary
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            PaneHeader("Tax Studio", subtitle: "Inspect filing readiness, missing requirements, and current tax facts.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

            HStack(spacing: AppTheme.spacingM) {
                Picker("Entity", selection: $selectedEntityId) {
                    ForEach(entities, id: \.id) { entity in
                        Text(entity.displayName)
                            .tag(Optional(entity.id))
                    }
                }
                .accessibilityIdentifier("taxStudio.entityPicker")
                .frame(maxWidth: 280)

                Picker("Tax Year", selection: $selectedTaxYearId) {
                    ForEach(taxYears, id: \.id) { taxYear in
                        Text(String(taxYear.year))
                            .tag(Optional(taxYear.id))
                    }
                }
                .accessibilityIdentifier("taxStudio.taxYearPicker")
                .frame(maxWidth: 160)

                Spacer()
            }
            .padding(.horizontal, AppTheme.contentPadding)

            HStack(spacing: AppTheme.spacingM) {
                SummaryTile(
                    "Readiness",
                    value: readinessTitle(readinessSummary.state),
                    subtitle: "Current state",
                    tone: readinessTone(readinessSummary.state),
                    systemImage: "checkmark.shield",
                    accessibilityIdentifier: "taxStudio.readiness",
                    accessibilityLabel: readinessSummary.state.rawValue
                )
                SummaryTile(
                    "Open Issues",
                    value: readinessSummary.openIssueCount.formatted(),
                    subtitle: "Need attention",
                    tone: .critical,
                    systemImage: "exclamationmark.bubble",
                    accessibilityIdentifier: "taxStudio.issueCount"
                )
                SummaryTile(
                    "Pending Requirements",
                    value: readinessSummary.pendingRequirementCount.formatted(),
                    subtitle: "Still missing",
                    tone: .warning,
                    systemImage: "list.bullet.clipboard",
                    accessibilityIdentifier: "taxStudio.requirementCount"
                )
                SummaryTile(
                    "Current Facts",
                    value: readinessSummary.currentFactCount.formatted(),
                    subtitle: "In scope",
                    tone: .info,
                    systemImage: "text.document",
                    accessibilityIdentifier: "taxStudio.factCount"
                )
            }
            .padding(.horizontal, AppTheme.contentPadding)

            HSplitView {
                List(selection: $selectedTaxFactId) {
                    factSection("Personal Income", facts: facts(withPrefix: "personal.income."))
                    factSection("Deductions", facts: facts(withPrefix: "personal.deduction."))
                    factSection("Self-Employment", facts: facts(withPrefix: "personal.self_employment."))
                }
                .accessibilityIdentifier("taxStudio.facts")
                .frame(minWidth: 420)

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    PaneHeader("Blockers & Requirements", subtitle: "Open issues, pending requirements, and missing fact concepts.")

                    if issues.isEmpty && requirements.isEmpty {
                        ContentUnavailableView("No Open Blockers", systemImage: "checkmark.seal")
                    } else {
                        List {
                            if issues.isEmpty == false {
                                Section("Issues") {
                                    ForEach(issues, id: \.id) { issue in
                                        SourceListRow(
                                            title: issue.summary,
                                            subtitle: issue.severity.rawValue.capitalized,
                                            systemImage: issue.severity == .blocking ? "exclamationmark.octagon" : "exclamationmark.triangle"
                                        )
                                        .accessibilityIdentifier("taxStudio.issue.\(accessibilitySlug(issue.summary))")
                                    }
                                }
                            }
                            if requirements.isEmpty == false {
                                Section("Requirements") {
                                    ForEach(requirements, id: \.id) { requirement in
                                        SourceListRow(
                                            title: requirement.summary,
                                            subtitle: requirement.status.rawValue.capitalized,
                                            systemImage: "list.bullet.clipboard"
                                        )
                                        .accessibilityIdentifier("taxStudio.requirement.\(accessibilitySlug(requirement.summary))")
                                    }
                                }
                            }
                            if readinessSummary.missingConceptCodes.isEmpty == false {
                                Section("Missing Facts") {
                                    ForEach(readinessSummary.missingConceptCodes, id: \.self) { conceptCode in
                                        SourceListRow(
                                            title: conceptCode,
                                            systemImage: "questionmark.circle"
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(AppTheme.spacingM)
                .frame(minWidth: 320)

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    PaneHeader("Inspector", subtitle: "Provenance and details for the selected tax fact.")

                    if let selectedFact {
                        InspectorPane("Tax Fact") {
                            StatusBadge(selectedFact.status.rawValue.capitalized, tone: statusTone(selectedFact.status))
                            InspectorSectionRow("Concept", value: selectedFact.conceptCode)
                            InspectorSectionRow("Value", value: valueString(for: selectedFact))
                            InspectorSectionRow("Ruleset", value: selectedFact.rulesetVersion)

                            if selectedFact.provenanceRefs.isEmpty {
                                Text("No provenance refs")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(selectedFact.provenanceRefs, id: \.stringValue) { ref in
                                    Text(ref.stringValue)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("taxStudio.inspector")
                    } else {
                        ContentUnavailableView("No Tax Fact Selected", systemImage: "checkerboard.rectangle")
                    }

                    Spacer()
                }
                .padding(AppTheme.spacingM)
                .frame(minWidth: 320)
            }
        }
    }

    private var selectedFact: TaxFact? {
        guard let selectedTaxFactId else {
            return taxFacts.first
        }
        return taxFacts.first(where: { $0.id == selectedTaxFactId })
    }

    private func facts(withPrefix prefix: String) -> [TaxFact] {
        taxFacts.filter { $0.conceptCode.hasPrefix(prefix) }
    }

    @ViewBuilder
    private func factSection(_ title: String, facts: [TaxFact]) -> some View {
        Section(title) {
            if facts.isEmpty {
                Text("No facts")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(facts, id: \.id) { fact in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(factLabel(for: fact))
                        Text(valueString(for: fact))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(Optional(fact.id))
                    .accessibilityIdentifier("taxStudio.fact.\(accessibilitySlug(fact.conceptCode))")
                }
            }
        }
    }

    private func factLabel(for fact: TaxFact) -> String {
        switch fact.conceptCode {
        case "personal.income.salary_gross":
            return "Salary Gross"
        case "personal.deduction.health_insurance_premiums":
            return "Health Insurance Premiums"
        case "personal.deduction.pillar3a_contributions":
            return "Pillar 3a Contributions"
        case "personal.self_employment.revenue_gross":
            return "Revenue Gross"
        case "personal.self_employment.expense_total":
            return "Expense Total"
        case "personal.self_employment.net_profit":
            return "Net Profit"
        default:
            return fact.conceptCode
        }
    }

    private func valueString(for fact: TaxFact) -> String {
        switch fact.valueType {
        case .money:
            let amount = Decimal(fact.moneyMinor ?? 0) / 100
            let number = NSDecimalNumber(decimal: amount).stringValue
            return "\(number) \(fact.currency ?? "CHF")"
        case .text:
            return fact.textValue ?? "n/a"
        case .bool:
            return (fact.boolValue ?? false) ? "Yes" : "No"
        case .date:
            guard let dateValue = fact.dateValue else {
                return "n/a"
            }
            return DateFormatter.localizedString(from: dateValue, dateStyle: .medium, timeStyle: .none)
        }
    }

    private func readinessTone(_ state: TaxReadinessState) -> StatusBadge.Tone {
        switch state {
        case .notStarted:
            return .neutral
        case .needsAttention:
            return .warning
        case .readyForReview:
            return .success
        }
    }

    private func statusTone(_ status: TaxFactStatus) -> StatusBadge.Tone {
        switch status {
        case .observed:
            return .info
        case .derived:
            return .success
        case .overridden:
            return .warning
        }
    }

    private func readinessTitle(_ state: TaxReadinessState) -> String {
        switch state {
        case .notStarted:
            return "Not Started"
        case .needsAttention:
            return "Needs Attention"
        case .readyForReview:
            return "Ready for Review"
        }
    }
}
