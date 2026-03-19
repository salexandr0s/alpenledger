import XCTest

final class AlpenLedgerAppUITests: XCTestCase {
    private var app: XCUIApplication!
    private var harnessRoot: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false

        harnessRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AlpenLedgerUITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: harnessRoot, withIntermediateDirectories: true)

        let workspaceRoot = harnessRoot.appendingPathComponent("workspaces", isDirectory: true)
        let secretRoot = harnessRoot.appendingPathComponent("secrets", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secretRoot, withIntermediateDirectories: true)

        app = XCUIApplication()
        app.launchEnvironment["ALPENLEDGER_WORKSPACES_ROOT"] = workspaceRoot.path
        app.launchEnvironment["ALPENLEDGER_SECRET_STORE_ROOT"] = secretRoot.path
        app.launchEnvironment["ALPENLEDGER_DEFAULTS_SUITE"] = "AlpenLedgerUITests.\(UUID().uuidString)"
        app.launchEnvironment["ALPENLEDGER_FIXED_NOW"] = "2026-03-19T12:00:00Z"
        app.launchArguments += ["-ApplePersistenceIgnoreState", "YES"]
    }

    override func tearDownWithError() throws {
        app = nil
        if let harnessRoot {
            try? FileManager.default.removeItem(at: harnessRoot)
        }
        harnessRoot = nil
    }

    func testAcceptanceFlow() throws {
        app.launch()

        createWorkspace(named: "Acceptance Workspace")
        importSampleDataFromOverview()
        element("overview.openInbox").click()

        waitForLabel("inbox.count.importJobs", equals: "2 import jobs")
        waitForLabel("inbox.count.proposals", equals: "1 pending proposals")
        waitForLabel("inbox.count.issues", equals: "3 open issues")

        navigate(to: "nav.ledger")
        waitForLabel("toolbar.ledger.scope", equals: "All")
        XCTAssertTrue(element("toolbar.ledger.importCSV").waitForExistence(timeout: 5))
        let ledgerInspectorToggle = element("toolbar.ledger.toggleInspector")
        XCTAssertTrue(ledgerInspectorToggle.waitForExistence(timeout: 5))
        ledgerInspectorToggle.click()
        ledgerInspectorToggle.click()

        let coffeeTransaction = element("ledger.transaction.coffee-bar-zurich")
        XCTAssertTrue(coffeeTransaction.waitForExistence(timeout: 5))
        coffeeTransaction.click()

        let linkDocumentButton = element("ledger.linkDocument")
        XCTAssertTrue(linkDocumentButton.waitForExistence(timeout: 5))
        linkDocumentButton.click()

        let sampleReceiptButton = element("sheet.document.sample-receipt-pdf")
        XCTAssertTrue(sampleReceiptButton.waitForExistence(timeout: 5))
        sampleReceiptButton.click()
        XCTAssertTrue(app.staticTexts["sample-receipt.pdf"].waitForExistence(timeout: 5))

        navigate(to: "nav.documents")
        XCTAssertTrue(element("toolbar.documents.import").waitForExistence(timeout: 5))
        let documentsInspectorToggle = element("toolbar.documents.toggleInspector")
        XCTAssertTrue(documentsInspectorToggle.waitForExistence(timeout: 5))
        documentsInspectorToggle.click()
        documentsInspectorToggle.click()

        let receiptDocument = element("documents.document.sample-receipt-pdf")
        XCTAssertTrue(receiptDocument.waitForExistence(timeout: 5))
        receiptDocument.click()
        XCTAssertTrue(app.staticTexts["Coffee Bar Zurich"].waitForExistence(timeout: 5))

        navigate(to: "nav.inbox")

        waitForLabel("inbox.count.proposals", equals: "0 pending proposals")
        waitForLabel("inbox.count.issues", equals: "2 open issues")
    }

    func testInspectorVisibilityPersistsAcrossRelaunch() throws {
        app.launch()

        createWorkspace(named: "Persistence Workspace")
        importSampleDataFromOverview()

        navigate(to: "nav.ledger")
        let ledgerInspectorToggle = element("toolbar.ledger.toggleInspector")
        XCTAssertTrue(ledgerInspectorToggle.waitForExistence(timeout: 5))
        ledgerInspectorToggle.click()
        waitForLabel("toolbar.ledger.toggleInspector", equals: "Show Inspector")

        navigate(to: "nav.documents")
        let documentsInspectorToggle = element("toolbar.documents.toggleInspector")
        XCTAssertTrue(documentsInspectorToggle.waitForExistence(timeout: 5))
        documentsInspectorToggle.click()
        waitForLabel("toolbar.documents.toggleInspector", equals: "Show Inspector")

        app.terminate()
        app.launch()

        let recentWorkspace = element("workspace.recent.persistence-workspace")
        XCTAssertTrue(recentWorkspace.waitForExistence(timeout: 10))
        recentWorkspace.click()

        navigate(to: "nav.ledger")
        waitForLabel("toolbar.ledger.toggleInspector", equals: "Show Inspector")

        navigate(to: "nav.documents")
        waitForLabel("toolbar.documents.toggleInspector", equals: "Show Inspector")
    }

    func testKeyboardSelectionUpdatesLedgerAndDocuments() throws {
        app.launch()

        createWorkspace(named: "Keyboard Workspace")
        importSampleDataFromOverview()
        importQAValidationFixturesFromMenu()

        navigate(to: "nav.ledger")
        let ledgerInspector = element("ledger.inspector.counterparty")
        XCTAssertTrue(ledgerInspector.waitForExistence(timeout: 5))
        let initialCounterparty = ledgerInspector.label
        app.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        waitForLabelChange("ledger.inspector.counterparty", from: initialCounterparty)

        navigate(to: "nav.documents")
        let previewTitle = element("documents.preview.title")
        XCTAssertTrue(previewTitle.waitForExistence(timeout: 5))
        let initialTitle = previewTitle.label
        app.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        waitForLabelChange("documents.preview.title", from: initialTitle)
    }

    func testDocumentSearchScopesShowDeterministicFilteredEmptyStates() throws {
        app.launch()

        createWorkspace(named: "Search Scope Workspace")
        importSampleDataFromOverview()
        importQAValidationFixturesFromMenu()

        navigate(to: "nav.documents")

        let searchField = app.searchFields["Search documents"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        let certificatesScope = element("documents.scope.certificates")
        XCTAssertTrue(certificatesScope.waitForExistence(timeout: 5))
        certificatesScope.click()

        searchField.typeText("zzzxqvnotfound\n")

        XCTAssertTrue(element("documents.clearSearchButton").waitForExistence(timeout: 5))
        XCTAssertTrue(element("documents.showAllTypesButton").waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func createWorkspace(named name: String) {
        let workspaceChooser = element("workspace.chooser")
        XCTAssertTrue(workspaceChooser.waitForExistence(timeout: 10))

        let workspaceNameField = element("workspace.nameField")
        XCTAssertTrue(workspaceNameField.waitForExistence(timeout: 5))
        workspaceNameField.click()
        workspaceNameField.typeText(name)

        let createWorkspaceButton = element("workspace.createButton")
        XCTAssertTrue(createWorkspaceButton.waitForExistence(timeout: 5))
        createWorkspaceButton.click()

        XCTAssertTrue(element("overview.importSampleCSV").waitForExistence(timeout: 10))
        XCTAssertFalse(workspaceChooser.exists)
    }

    private func importSampleDataFromOverview() {
        let overviewImportCSVButton = element("overview.importSampleCSV")
        XCTAssertTrue(overviewImportCSVButton.waitForExistence(timeout: 5))
        overviewImportCSVButton.click()
        element("overview.importSamplePDF").click()
    }

    private func navigate(to identifier: String) {
        let navigation = element(identifier)
        XCTAssertTrue(navigation.waitForExistence(timeout: 5))
        navigation.click()
    }

    private func importQAValidationFixturesFromMenu() {
        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 5))
        fileMenu.click()

        let qaMenuItem = app.menuItems["Import QA Validation Fixtures"]
        XCTAssertTrue(qaMenuItem.waitForExistence(timeout: 5))
        qaMenuItem.click()
    }

    private func waitForLabel(_ identifier: String, equals expectedLabel: String, timeout: TimeInterval = 5) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout))
        let predicate = NSPredicate(format: "label == %@ OR value == %@", expectedLabel, expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }

    private func waitForLabelChange(_ identifier: String, from previousValue: String, timeout: TimeInterval = 5) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout))
        let predicate = NSPredicate(format: "label != %@ OR value != %@", previousValue, previousValue)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }
}
