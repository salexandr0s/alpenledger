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

        let workspaceChooser = element("workspace.chooser")
        XCTAssertTrue(workspaceChooser.waitForExistence(timeout: 10))

        let workspaceNameField = element("workspace.nameField")
        XCTAssertTrue(workspaceNameField.waitForExistence(timeout: 5))
        workspaceNameField.click()
        workspaceNameField.typeText("Acceptance Workspace")

        let createWorkspaceButton = element("workspace.createButton")
        XCTAssertTrue(createWorkspaceButton.waitForExistence(timeout: 5))
        createWorkspaceButton.click()

        let overviewImportCSVButton = element("overview.importSampleCSV")
        XCTAssertTrue(overviewImportCSVButton.waitForExistence(timeout: 10))
        XCTAssertFalse(workspaceChooser.exists)

        overviewImportCSVButton.click()
        element("overview.importSamplePDF").click()
        element("overview.openInbox").click()

        waitForLabel("inbox.count.importJobs", equals: "2 import jobs")
        waitForLabel("inbox.count.proposals", equals: "1 pending proposals")
        waitForLabel("inbox.count.issues", equals: "3 open issues")

        let ledgerNavigation = element("nav.ledger")
        XCTAssertTrue(ledgerNavigation.waitForExistence(timeout: 5))
        ledgerNavigation.click()

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

        let documentsNavigation = element("nav.documents")
        XCTAssertTrue(documentsNavigation.waitForExistence(timeout: 5))
        documentsNavigation.click()

        let receiptDocument = element("documents.document.sample-receipt-pdf")
        XCTAssertTrue(receiptDocument.waitForExistence(timeout: 5))
        receiptDocument.click()
        XCTAssertTrue(app.staticTexts["Coffee Bar Zurich"].waitForExistence(timeout: 5))

        let inboxNavigation = element("nav.inbox")
        XCTAssertTrue(inboxNavigation.waitForExistence(timeout: 5))
        inboxNavigation.click()

        waitForLabel("inbox.count.proposals", equals: "0 pending proposals")
        waitForLabel("inbox.count.issues", equals: "2 open issues")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForLabel(_ identifier: String, equals expectedLabel: String, timeout: TimeInterval = 5) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout))
        let predicate = NSPredicate(format: "label == %@ OR value == %@", expectedLabel, expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }
}
