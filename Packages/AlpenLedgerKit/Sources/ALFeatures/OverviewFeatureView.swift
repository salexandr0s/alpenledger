import SwiftUI
import ALDesignSystem

public struct OverviewFeatureView: View {
    private let workspaceName: String
    private let entityCount: Int
    private let accountCount: Int
    private let transactionCount: Int
    private let documentCount: Int
    private let onImportSampleCSV: () -> Void
    private let onImportSampleDocument: () -> Void

    public init(
        workspaceName: String,
        entityCount: Int,
        accountCount: Int,
        transactionCount: Int,
        documentCount: Int,
        onImportSampleCSV: @escaping () -> Void,
        onImportSampleDocument: @escaping () -> Void
    ) {
        self.workspaceName = workspaceName
        self.entityCount = entityCount
        self.accountCount = accountCount
        self.transactionCount = transactionCount
        self.documentCount = documentCount
        self.onImportSampleCSV = onImportSampleCSV
        self.onImportSampleDocument = onImportSampleDocument
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                Text(workspaceName)
                    .font(.largeTitle.weight(.bold))
                Text("Vertical proof slice")
                    .foregroundStyle(.secondary)

                HStack(spacing: AppTheme.spacingM) {
                    metricCard("Entities", value: entityCount, tint: .blue)
                    metricCard("Accounts", value: accountCount, tint: .teal)
                    metricCard("Transactions", value: transactionCount, tint: .green)
                    metricCard("Documents", value: documentCount, tint: .orange)
                }

                InspectorPane("Quick Actions") {
                    HStack {
                        Button("Import Sample CSV", action: onImportSampleCSV)
                            .buttonStyle(.borderedProminent)
                        Button("Import Sample PDF", action: onImportSampleDocument)
                            .buttonStyle(.bordered)
                    }
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func metricCard(_ title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            StatusBadge(title, tint: tint)
            Text(value.formatted())
                .font(.title.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.spacingM)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}
