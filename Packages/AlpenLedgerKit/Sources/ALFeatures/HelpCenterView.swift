import SwiftUI
import ALDesignSystem

public struct HelpCenterView: View {
    private let snapshot: HelpCenterSnapshot
    private let onDismiss: () -> Void

    public init(snapshot: HelpCenterSnapshot, onDismiss: @escaping () -> Void) {
        self.snapshot = snapshot
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                    header
                    privacyNotice
                    sections
                }
                .padding(AppTheme.contentPadding)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .navigationTitle(snapshot.title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("help.doneButton")
                }
            }
        }
        .frame(minWidth: 720, minHeight: 620)
        .accessibilityIdentifier("help.center")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            Text(snapshot.title)
                .font(.system(size: 30, weight: .semibold))

            Text(snapshot.subtitle)
                .font(AppTheme.pageSubtitleFont)
                .foregroundStyle(AppTheme.subduedForegroundColor)
        }
        .accessibilityIdentifier("help.header")
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingS) {
            Image(systemName: "lock.shield")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            Text(snapshot.privacyNotice)
                .font(AppTheme.metaFont)
                .foregroundStyle(.secondary)
        }
        .padding(AppTheme.spacingM)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("help.privacyNotice")
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            ForEach(snapshot.sections) { section in
                GroupBox {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        ForEach(section.items) { item in
                            VStack(alignment: .leading, spacing: AppTheme.spacingXXS) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.detail)
                                    .font(AppTheme.metaFont)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityIdentifier("help.item.\(item.id)")
                        }
                    }
                    .padding(.top, AppTheme.spacingXXS)
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                }
                .accessibilityIdentifier("help.section.\(section.id)")
            }
        }
    }
}
