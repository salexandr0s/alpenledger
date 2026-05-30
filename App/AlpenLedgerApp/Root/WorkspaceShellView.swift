import SwiftUI
import ALDesignSystem
import ALDomain
import ALFeatures
import ALStorage

struct WorkspaceShellView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: WorkspaceAppModel

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            DetailView(model: model)
        }
        .toolbar(content: shellToolbar)
        .animation(AppTheme.panelAnimation(reduceMotion: reduceMotion), value: model.selectedSection)
    }

    @ToolbarContentBuilder
    private func shellToolbar() -> some ToolbarContent {
        ToolbarItem {
            Button {
                model.presentGlobalSearch()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel("Search Workspace")
            .accessibilityIdentifier("toolbar.globalSearch")
            .disabled(model.canUseGlobalSearch == false)
            .popover(isPresented: $model.isShowingGlobalSearch, arrowEdge: .bottom) {
                GlobalSearchPopoverView(model: model)
            }
        }

        ToolbarItem {
            Menu("Import", systemImage: "tray.and.arrow.down") {
                Button("Bank Statement CSV…", action: model.importCSVFromPanel)
                    .disabled(model.canImportCSV == false)

                Button("Document…", action: model.importDocumentFromPanel)
                    .disabled(model.canImportDocument == false)

                Divider()

                Menu("Samples", systemImage: "sparkles.rectangle.stack") {
                    Button("Import Sample CSV", action: model.importSampleCSV)
                        .disabled(model.canImportSampleData == false)

                    Button("Import Sample PDF", action: model.importSampleDocument)
                        .disabled(model.canImportSampleData == false)

                    Button("Import Sample Data", action: model.importSampleData)
                        .disabled(model.canImportSampleData == false)
                }
            }
            .accessibilityIdentifier("toolbar.importMenu")
        }

        if let inspectorControl = model.shellToolbarConfiguration.inspectorControl {
            ToolbarItem {
                Button(inspectorControl.title, systemImage: "sidebar.right") {
                    model.performShellToolbarInspectorAction()
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel(inspectorControl.title)
                .accessibilityIdentifier(inspectorControl.accessibilityIdentifier)
            }
        }
    }
}

private struct GlobalSearchPopoverView: View {
    @Bindable var model: WorkspaceAppModel
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack(spacing: AppTheme.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.subduedForegroundColor)

                TextField("Search workspace", text: $model.globalSearchQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFieldFocused)
                    .onSubmit(model.refreshGlobalSearchResults)
                    .accessibilityIdentifier("globalSearch.queryField")

                if model.globalSearchQuery.isEmpty == false {
                    Button {
                        model.clearGlobalSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.subduedForegroundColor)
                    .accessibilityLabel("Clear Search")
                    .accessibilityIdentifier("globalSearch.clearButton")
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.vertical, AppTheme.spacingS)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

            Divider()

            resultsContent
                .frame(minHeight: 240, maxHeight: 360)
        }
        .padding(AppTheme.contentPadding)
        .frame(width: 460)
        .onAppear {
            isSearchFieldFocused = true
            model.refreshGlobalSearchResults()
        }
        .onChange(of: model.globalSearchQuery) { _, _ in
            model.refreshGlobalSearchResults()
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        let trimmedQuery = model.globalSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            ContentUnavailableView {
                Label("Search workspace", systemImage: "magnifyingglass")
            } description: {
                Text("Find documents, transactions, counterparties, and issues.")
            }
            .accessibilityIdentifier("globalSearch.emptyPrompt")
        } else if model.globalSearchResults.isEmpty {
            ContentUnavailableView {
                Label("No matches", systemImage: "magnifyingglass")
            } description: {
                Text("Try another vendor, document name, issue, or transaction reference.")
            }
            .accessibilityIdentifier("globalSearch.noResults")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.spacingXS) {
                    ForEach(model.globalSearchResults) { hit in
                        Button {
                            model.openGlobalSearchHit(hit)
                        } label: {
                            GlobalSearchResultRow(hit: hit)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("globalSearch.result.\(hit.objectKind.rawValue).\(hit.objectRef.id)")
                    }
                }
            }
            .accessibilityIdentifier("globalSearch.results")
        }
    }
}

private struct GlobalSearchResultRow: View {
    let hit: GlobalSearchHit

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingS) {
            Image(systemName: hit.objectKind.globalSearchSystemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppTheme.spacingS) {
                    Text(hit.title)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    Text(hit.objectKind.globalSearchLabel)
                        .font(AppTheme.metaFont)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                        .lineLimit(1)
                }

                if let subtitle = hit.subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(AppTheme.metaFont)
                        .foregroundStyle(AppTheme.subduedForegroundColor)
                        .lineLimit(1)
                }

                Text(hit.snippet)
                    .font(AppTheme.metaFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: AppTheme.spacingS)
        }
        .padding(AppTheme.spacingS)
        .contentShape(Rectangle())
    }
}

private extension ObjectKind {
    var globalSearchLabel: String {
        switch self {
        case .document:
            return "Document"
        case .transaction:
            return "Transaction"
        case .counterparty:
            return "Counterparty"
        case .issue:
            return "Issue"
        default:
            return rawValue
        }
    }

    var globalSearchSystemImage: String {
        switch self {
        case .document:
            return "doc.text"
        case .transaction:
            return "list.bullet.rectangle"
        case .counterparty:
            return "building.2"
        case .issue:
            return "exclamationmark.triangle"
        default:
            return "magnifyingglass"
        }
    }
}
