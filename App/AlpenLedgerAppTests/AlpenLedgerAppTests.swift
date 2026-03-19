import XCTest
import ALDomain
@testable import AlpenLedgerApp

final class AlpenLedgerAppTests: XCTestCase {
    func testSmoke() {
        XCTAssertTrue(true)
    }

    func testWorkspaceUIPreferencesStoreDefaultsToVisible() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = WorkspaceUIPreferencesStore(defaults: defaults)
        let workspaceId = WorkspaceID()

        XCTAssertTrue(store.inspectorVisible(workspaceId: workspaceId, section: .ledger))
        XCTAssertTrue(store.inspectorVisible(workspaceId: workspaceId, section: .documents))
    }

    func testWorkspaceUIPreferencesStorePersistsPerWorkspaceAndSection() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = WorkspaceUIPreferencesStore(defaults: defaults)
        let firstWorkspace = WorkspaceID()
        let secondWorkspace = WorkspaceID()

        store.setInspectorVisible(false, workspaceId: firstWorkspace, section: .ledger)
        store.setInspectorVisible(true, workspaceId: firstWorkspace, section: .documents)
        store.setInspectorVisible(false, workspaceId: secondWorkspace, section: .documents)

        XCTAssertFalse(store.inspectorVisible(workspaceId: firstWorkspace, section: .ledger))
        XCTAssertTrue(store.inspectorVisible(workspaceId: firstWorkspace, section: .documents))
        XCTAssertTrue(store.inspectorVisible(workspaceId: secondWorkspace, section: .ledger))
        XCTAssertFalse(store.inspectorVisible(workspaceId: secondWorkspace, section: .documents))
    }

    @MainActor
    func testSelectionCommandsFollowActiveSection() {
        let model = WorkspaceAppModel(container: DependencyContainer())

        XCTAssertFalse(model.canLinkSelectedDocument)
        XCTAssertFalse(model.canLinkSelectedTransaction)
        XCTAssertFalse(model.canToggleActiveInspector)

        model.selectedSection = .ledger
        model.selectedTransactionId = TransactionID()

        XCTAssertTrue(model.canLinkSelectedDocument)
        XCTAssertFalse(model.canLinkSelectedTransaction)
        XCTAssertFalse(model.canToggleActiveInspector)

        model.selectedSection = .documents
        model.selectedDocumentId = DocumentID()

        XCTAssertFalse(model.canLinkSelectedDocument)
        XCTAssertTrue(model.canLinkSelectedTransaction)
        XCTAssertFalse(model.canToggleActiveInspector)
    }

    @MainActor
    func testToggleInspectorForActiveSectionRoutesToVisibleSectionOnly() {
        let model = WorkspaceAppModel(container: DependencyContainer())
        model.isLedgerInspectorVisible = true
        model.isDocumentsInspectorVisible = true

        model.selectedSection = .ledger
        model.toggleInspectorForActiveSection()
        XCTAssertFalse(model.isLedgerInspectorVisible)
        XCTAssertTrue(model.isDocumentsInspectorVisible)

        model.selectedSection = .documents
        model.toggleInspectorForActiveSection()
        XCTAssertFalse(model.isDocumentsInspectorVisible)

        model.selectedSection = .overview
        model.toggleInspectorForActiveSection()
        XCTAssertFalse(model.isLedgerInspectorVisible)
        XCTAssertFalse(model.isDocumentsInspectorVisible)
    }
}
