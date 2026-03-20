import SwiftUI
import ALDesignSystem
import ALDomain

@MainActor
public struct TaxStudioFeatureView: View {
    @Binding private var selectedEntityId: LegalEntityID?
    @Binding private var selectedTaxYearId: TaxYearID?
    @Binding private var selection: TaxStudioSelection?

    @State private var expandedCategoryIDs: Set<String> = ["personal-income", "deductions", "self-employment"]

    private let entities: [LegalEntity]
    private let taxYears: [TaxYear]
    private let snapshot: TaxStudioSnapshot

    public init(
        selectedEntityId: Binding<LegalEntityID?>,
        selectedTaxYearId: Binding<TaxYearID?>,
        selection: Binding<TaxStudioSelection?>,
        entities: [LegalEntity],
        taxYears: [TaxYear],
        snapshot: TaxStudioSnapshot
    ) {
        _selectedEntityId = selectedEntityId
        _selectedTaxYearId = selectedTaxYearId
        _selection = selection
        self.entities = entities
        self.taxYears = taxYears
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            PaneHeader(
                "Tax Studio",
                subtitle: "Readiness, missing facts, and grounded tax evidence.",
                style: .page
            )
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.top, AppTheme.spacingM)

            toolbarRow
                .padding(.horizontal, AppTheme.contentPadding)

            if snapshot.inspector != nil {
                HSplitView {
                    mainContent
                        .frame(minWidth: 620)

                    inspectorPane
                        .frame(minWidth: 340)
                }
            } else {
                mainContent
            }
        }
    }

    private var toolbarRow: some View {
        HStack(spacing: AppTheme.spacingM) {
            Picker("Entity", selection: $selectedEntityId) {
                ForEach(entities, id: \.id) { entity in
                    Text(entity.displayName)
                        .tag(Optional(entity.id))
                }
            }
            .frame(maxWidth: 320)
            .accessibilityIdentifier("taxStudio.entityPicker")

            Picker("Tax Year", selection: $selectedTaxYearId) {
                ForEach(taxYears, id: \.id) { taxYear in
                    Text(String(taxYear.year))
                        .tag(Optional(taxYear.id))
                }
            }
            .frame(maxWidth: 180)
            .accessibilityIdentifier("taxStudio.taxYearPicker")

            StatusBadge(snapshot.readinessTitle, tone: snapshot.readinessTone)

            Spacer()
        }
    }

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                InspectorPane("Readiness", subtitle: snapshot.readinessSummary, style: .card) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        ForEach(snapshot.checklistItems) { item in
                            Button {
                                selection = item.selection
                            } label: {
                                HStack(alignment: .top, spacing: AppTheme.spacingS) {
                                    StatusBadge(item.statusText, tone: item.tone)
                                    VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                                        Text(item.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text(item.subtitle)
                                            .font(AppTheme.metaFont)
                                            .foregroundStyle(AppTheme.subduedForegroundColor)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, AppTheme.spacingXS)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                    PaneHeader("Facts", subtitle: "Observed and derived facts for the selected entity and year.")

                    ForEach(snapshot.factCategories) { category in
                        DisclosureGroup(
                            isExpanded: expansionBinding(for: category.id)
                        ) {
                            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                if category.items.isEmpty {
                                    HStack(spacing: AppTheme.spacingS) {
                                        Text("No data yet")
                                            .font(AppTheme.metaFont)
                                            .foregroundStyle(.secondary)

                                        Button("Add") {
                                            selection = snapshot.checklistItems.first?.selection
                                        }
                                        .buttonStyle(.plain)
                                        .font(AppTheme.metaFont)
                                        .foregroundStyle(Color.accentColor)
                                    }
                                    .padding(.top, AppTheme.spacingXS)
                                } else {
                                    ForEach(category.items) { fact in
                                        Button {
                                            selection = fact.selection
                                        } label: {
                                            HStack(alignment: .top, spacing: AppTheme.spacingS) {
                                                WorkItemRow(
                                                    title: fact.title,
                                                    subtitle: fact.value,
                                                    systemImage: fact.systemImage,
                                                    statusTitle: fact.statusText,
                                                    tone: fact.tone
                                                )
                                                Spacer()
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("taxStudio.fact.\(accessibilitySlug(fact.title))")
                                    }
                                }
                            }
                            .padding(.top, AppTheme.spacingXS)
                        } label: {
                            HStack {
                                Text(category.title)
                                    .font(.headline)
                                Spacer()
                                Text(category.completionText)
                                    .font(AppTheme.metaFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(AppTheme.groupedPanelPadding)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .fill(AppTheme.subtleSurfaceColor)
                        )
                    }
                }
            }
            .padding(AppTheme.contentPadding)
        }
    }

    private var inspectorPane: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            PaneHeader("Inspector", subtitle: "Selected fact or requirement details.")
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.top, AppTheme.spacingM)

            if let inspector = snapshot.inspector {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                        InspectorPane(inspector.title, subtitle: inspector.subtitle, style: .card) {
                            StatusBadge(inspector.statusText, tone: inspector.tone)

                            ForEach(inspector.details) { detail in
                                InspectorSectionRow(detail.label, value: detail.value)
                            }
                        }

                        InspectorPane("Evidence", style: .grouped) {
                            if inspector.evidence.isEmpty {
                                Text("No linked evidence yet.")
                                    .font(AppTheme.metaFont)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                    ForEach(inspector.evidence) { item in
                                        DocumentReferenceRow(
                                            title: item.title,
                                            subtitle: item.subtitle,
                                            systemImage: item.systemImage
                                        )
                                    }
                                }
                            }
                        }
                    }
                    .padding(AppTheme.contentPadding)
                }
            }
        }
    }

    private func expansionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedCategoryIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategoryIDs.insert(id)
                } else {
                    expandedCategoryIDs.remove(id)
                }
            }
        )
    }
}
