import SwiftUI
import ALDesignSystem
import ALDomain
import ALFeatures

struct SidebarView: View {
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        List(selection: $model.selectedSection) {
            if model.entitySwitcherSnapshot.entities.count > 1 {
                Section {
                    EntitySwitcherView(
                        snapshot: model.entitySwitcherSnapshot,
                        onSwitch: { model.switchEntity(to: $0) },
                        onManageEntities: { model.navigate(to: .settings) }
                    )
                }
            }
            ForEach(AppSection.Group.allCases) { group in
                Section(group.title) {
                    ForEach(group.sections) { section in
                        NavigationLink(value: section) {
                            Label(section.title, systemImage: section.systemImage)
                        }
                        .badge(model.sidebarBadgeText(for: section).flatMap { Text($0) })
                        .accessibilityIdentifier("nav.\(section.rawValue)")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(model.workspaceName)
        .navigationSplitViewColumnWidth(min: 210, ideal: AppTheme.sidebarIdealWidth, max: 280)
    }
}
