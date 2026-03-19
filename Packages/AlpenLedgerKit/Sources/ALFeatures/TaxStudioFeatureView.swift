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
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingM)

            HStack(spacing: AppTheme.spacingM) {
                summaryCard(
                    "Readiness",
                    label: readinessSummary.state.rawValue,
                    tint: readinessTint(readinessSummary.state),
                    identifier: "taxStudio.readiness"
                )
                summaryCard(
                    "Open Issues",
                    label: readinessSummary.openIssueCount.formatted(),
                    tint: .red,
                    identifier: "taxStudio.issueCount"
                )
                summaryCard(
                    "Pending Requirements",
                    label: readinessSummary.pendingRequirementCount.formatted(),
                    tint: .orange,
                    identifier: "taxStudio.requirementCount"
                )
                summaryCard(
                    "Current Facts",
                    label: readinessSummary.currentFactCount.formatted(),
                    tint: .blue,
                    identifier: "taxStudio.factCount"
                )
            }
            .padding(.horizontal, AppTheme.spacingM)

            HSplitView {
                List(selection: $selectedTaxFactId) {
                    factSection("Personal Income", facts: facts(withPrefix: "personal.income."))
                    factSection("Deductions", facts: facts(withPrefix: "personal.deduction."))
                    factSection("Self-Employment", facts: facts(withPrefix: "personal.self_employment."))
                }
                .accessibilityIdentifier("taxStudio.facts")
                .frame(minWidth: 420)

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Text("Blockers & Requirements")
                        .font(.title3.weight(.semibold))

                    if issues.isEmpty && requirements.isEmpty {
                        ContentUnavailableView("No Open Blockers", systemImage: "checkmark.seal")
                    } else {
                        List {
                            if issues.isEmpty == false {
                                Section("Issues") {
                                    ForEach(issues, id: \.id) { issue in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(issue.summary)
                                            Text(issue.severity.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .accessibilityIdentifier("taxStudio.issue.\(accessibilitySlug(issue.summary))")
                                    }
                                }
                            }
                            if requirements.isEmpty == false {
                                Section("Requirements") {
                                    ForEach(requirements, id: \.id) { requirement in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(requirement.summary)
                                            Text(requirement.status.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .accessibilityIdentifier("taxStudio.requirement.\(accessibilitySlug(requirement.summary))")
                                    }
                                }
                            }
                            if readinessSummary.missingConceptCodes.isEmpty == false {
                                Section("Missing Facts") {
                                    ForEach(readinessSummary.missingConceptCodes, id: \.self) { conceptCode in
                                        Text(conceptCode)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(AppTheme.spacingM)
                .frame(minWidth: 320)

                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Text("Inspector")
                        .font(.title3.weight(.semibold))

                    if let selectedFact {
                        InspectorPane("Tax Fact") {
                            StatusBadge(selectedFact.status.rawValue.capitalized, tint: statusTint(selectedFact.status))
                            Text(selectedFact.conceptCode)
                                .font(.body.monospaced())
                            Text(valueString(for: selectedFact))
                            Text("Ruleset: \(selectedFact.rulesetVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if selectedFact.provenanceRefs.isEmpty {
                                Text("No provenance refs")
                                    .font(.caption)
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

    @ViewBuilder
    private func summaryCard(_ title: String, label: String, tint: Color, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusBadge(title, tint: tint)
            Text(label)
                .font(.title3.weight(.semibold))
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacingM)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func readinessTint(_ state: TaxReadinessState) -> Color {
        switch state {
        case .notStarted:
            return .gray
        case .needsAttention:
            return .orange
        case .readyForReview:
            return .green
        }
    }

    private func statusTint(_ status: TaxFactStatus) -> Color {
        switch status {
        case .observed:
            return .blue
        case .derived:
            return .green
        case .overridden:
            return .orange
        }
    }
}
