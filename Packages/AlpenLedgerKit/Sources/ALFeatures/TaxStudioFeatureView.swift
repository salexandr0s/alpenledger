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
        mainContent
            .inspector(isPresented: inspectorPresented) {
                inspectorContent
                    .inspectorColumnWidth(min: 280, ideal: 320, max: 380)
            }
            .navigationTitle("Tax Studio")
            .navigationSubtitle("Readiness, facts, and blockers")
    }

    private var inspectorPresented: Binding<Bool> {
        Binding(
            get: { snapshot.inspector != nil },
            set: { _ in }
        )
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
                toolbarRow

                GroupBox("Readiness") {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text(snapshot.readinessSummary)
                            .font(AppTheme.metaFont)
                            .foregroundStyle(AppTheme.subduedForegroundColor)

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
                    VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                        Text("Facts")
                            .font(AppTheme.sectionTitleFont)
                            .bold()
                        Text("Observed and derived facts for the selected entity and year.")
                            .font(AppTheme.sectionSubtitleFont)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(snapshot.factCategories) { category in
                        GroupBox {
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
                        }
                    }
                }
            }
            .padding(AppTheme.contentPadding)
        }
    }

    private var inspectorContent: some View {
        Group {
            if let inspector = snapshot.inspector {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingM) {
                        GroupBox(inspector.title) {
                            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                Text(inspector.subtitle)
                                    .font(AppTheme.metaFont)
                                    .foregroundStyle(AppTheme.subduedForegroundColor)

                                StatusBadge(inspector.statusText, tone: inspector.tone)

                                ForEach(inspector.details) { detail in
                                    InspectorSectionRow(detail.label, value: detail.value)
                                }
                            }
                        }

                        GroupBox("Evidence") {
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
