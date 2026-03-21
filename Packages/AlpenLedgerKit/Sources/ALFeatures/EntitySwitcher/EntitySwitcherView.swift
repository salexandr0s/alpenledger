import SwiftUI
import ALDesignSystem
import ALDomain

public struct EntitySwitcherView: View {
    let snapshot: EntitySwitcherSnapshot
    let onSwitch: (EntityWorkspaceID) -> Void
    let onManageEntities: () -> Void

    public init(
        snapshot: EntitySwitcherSnapshot,
        onSwitch: @escaping (EntityWorkspaceID) -> Void,
        onManageEntities: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.onSwitch = onSwitch
        self.onManageEntities = onManageEntities
    }

    public var body: some View {
        Menu {
            ForEach(snapshot.entities) { entity in
                Button {
                    onSwitch(entity.id)
                } label: {
                    HStack {
                        Text(entity.displayName)
                        if entity.isActive {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(entity.isActive)
            }

            Divider()

            Button("Manage Entities\u{2026}") {
                onManageEntities()
            }
        } label: {
            HStack(spacing: AppTheme.spacingXS) {
                Image(systemName: "person.crop.rectangle.stack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(snapshot.activeEntityName)
                    .font(AppTheme.sidebarSectionHeaderFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, AppTheme.spacingS)
            .padding(.vertical, AppTheme.spacingXXS)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityIdentifier("sidebar.entitySwitcher")
    }
}
