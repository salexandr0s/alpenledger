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

    func testWelcomeUsesSheetBasedCreationAndRecentWorkspaceLauncher() throws {
        app.launch()

        createWorkspace(named: "Recent Workspace")
        app.terminate()
        app.launch()

        let recentWorkspace = waitForElement(
            "workspace.recent.recent-workspace",
            fallbackLabel: "Recent Workspace",
            timeout: 10
        )
        recentWorkspace.click()

        XCTAssertTrue(element("toolbar.importMenu").waitForExistence(timeout: 10))
    }

    func testOverviewActionLinksIntoInboxAndDocumentLinkFlow() throws {
        app.launch()

        createWorkspace(named: "Acceptance Workspace")
        importSampleDataFromMenu()

        let overviewPrimaryAction = element("overview.primaryAction")
        XCTAssertTrue(overviewPrimaryAction.waitForExistence(timeout: 5))
        overviewPrimaryAction.click()

        XCTAssertTrue(element("inbox.list").waitForExistence(timeout: 5))
        XCTAssertTrue(element("inbox.inspector.issue").waitForExistence(timeout: 5))
        let expenseIssue = element("inbox.issue.expense-evidence-missing")
        XCTAssertTrue(expenseIssue.waitForExistence(timeout: 5))
        clickElement(expenseIssue)

        navigate(to: "nav.documents")
        let receiptDocument = element("documents.document.sample-receipt-pdf")
        XCTAssertTrue(receiptDocument.waitForExistence(timeout: 5))
        receiptDocument.click()

        XCTAssertTrue(element("documents.previewPane").waitForExistence(timeout: 5))
    }

    func testLedgerAndDocumentsRequireSelectionBeforeShowingSecondaryContent() throws {
        app.launch()

        createWorkspace(named: "Selection Workspace")
        importSampleDataFromMenu()

        navigate(to: "nav.ledger")
        XCTAssertFalse(element("ledger.inspector.counterparty").exists)

        let ledgerAccount = element("ledger.account.personal-bank")
        XCTAssertTrue(ledgerAccount.waitForExistence(timeout: 5))
        clickElement(ledgerAccount)
        XCTAssertFalse(element("ledger.inspector.counterparty").exists)

        navigate(to: "nav.inbox")
        let expenseIssue = element("inbox.issue.expense-evidence-missing")
        XCTAssertTrue(expenseIssue.waitForExistence(timeout: 5))
        clickElement(expenseIssue)

        let linkDocumentButton = app.buttons["Link Document…"]
        XCTAssertTrue(linkDocumentButton.waitForExistence(timeout: 5))
        linkDocumentButton.click()

        let cancelLinkSheet = element("sheet.document.cancel")
        XCTAssertTrue(cancelLinkSheet.waitForExistence(timeout: 5))
        cancelLinkSheet.click()

        XCTAssertTrue(element("ledger.inspector.counterparty").waitForExistence(timeout: 5))

        navigate(to: "nav.documents")
        XCTAssertTrue(element("documents.selectionPrompt").waitForExistence(timeout: 5))

        let receiptDocument = element("documents.document.sample-receipt-pdf")
        XCTAssertTrue(receiptDocument.waitForExistence(timeout: 5))
        receiptDocument.click()
        XCTAssertTrue(element("documents.previewPane").waitForExistence(timeout: 5))
    }

    func testInspectorVisibilityPersistsAcrossRelaunch() throws {
        app.launch()

        createWorkspace(named: "Persistence Workspace")
        importSampleDataFromMenu()

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

        let recentWorkspace = waitForElement(
            "workspace.recent.persistence-workspace",
            fallbackLabel: "Persistence Workspace",
            timeout: 10
        )
        recentWorkspace.click()

        navigate(to: "nav.ledger")
        waitForLabel("toolbar.ledger.toggleInspector", equals: "Show Inspector")

        navigate(to: "nav.documents")
        waitForLabel("toolbar.documents.toggleInspector", equals: "Show Inspector")
    }

    func testDocumentSearchShowsFilteredEmptyStates() throws {
        app.launch()

        createWorkspace(named: "Search Scope Workspace")
        importSampleDataFromMenu()
        importQAValidationFixturesFromMenu()

        navigate(to: "nav.documents")

        let scopeMenu = element("documents.scopeMenu")
        XCTAssertTrue(scopeMenu.waitForExistence(timeout: 5))
        scopeMenu.click()

        let certificatesMenuItem = app.menuItems["Certificates"]
        XCTAssertTrue(certificatesMenuItem.waitForExistence(timeout: 5))
        certificatesMenuItem.click()

        let searchField = app.searchFields["Search documents"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        replaceText(in: searchField, with: "zzzxqvnotfound")
        searchField.typeText("\n")

        XCTAssertTrue(element("documents.clearSearchButton").waitForExistence(timeout: 5))
        XCTAssertTrue(element("documents.showAllTypesButton").waitForExistence(timeout: 5))
    }

    func testSettingsAllowsRenameAndEntityAddRemove() throws {
        app.launch()

        createWorkspace(named: "Settings Workspace")
        navigate(to: "nav.settings")

        let workspaceNameField = element("settings.workspaceNameField")
        XCTAssertTrue(workspaceNameField.waitForExistence(timeout: 5))
        replaceText(in: workspaceNameField, with: "Renamed Workspace")

        let renameButton = element("settings.renameWorkspaceButton")
        XCTAssertTrue(renameButton.waitForExistence(timeout: 5))
        renameButton.click()
        XCTAssertEqual(workspaceNameField.value as? String, "Renamed Workspace")

        let solePropField = element("settings.solePropNameField")
        XCTAssertTrue(solePropField.waitForExistence(timeout: 5))
        replaceText(in: solePropField, with: "Advisory Studio")

        let addButton = element("settings.addSolePropButton")
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.click()

        let removeButton = element("settings.entity.remove.advisory-studio")
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5))
        removeButton.click()
        waitForNonExistence("settings.entity.remove.advisory-studio")
    }

    func testEntitySwitcherScopesDataByEntity() throws {
        app.launch()

        createWorkspace(named: "Entity Switching Workspace")
        importSampleDataFromMenu()

        // Create a sole proprietor entity via Settings
        navigate(to: "nav.settings")
        createSoleProprietor(named: "Advisory Studio")

        // Entity switcher should appear now that 2+ entities exist
        let entitySwitcher = element("sidebar.entitySwitcher")
        XCTAssertTrue(entitySwitcher.waitForExistence(timeout: 5))

        // Navigate to Ledger — verify accounts visible for the natural person
        navigate(to: "nav.ledger")
        let personalAccount = element("ledger.account.personal-bank")
        XCTAssertTrue(personalAccount.waitForExistence(timeout: 5))

        // Switch to sole proprietor via entity switcher
        entitySwitcher.click()
        let solePropMenuItem = app.menuItems["Advisory Studio"]
        XCTAssertTrue(solePropMenuItem.waitForExistence(timeout: 5))
        solePropMenuItem.click()

        // Verify ledger shows different accounts for sole proprietor
        let businessAccount = element("ledger.account.business-bank")
        XCTAssertTrue(businessAccount.waitForExistence(timeout: 5))

        // Navigate to Documents — verify scoped filtering
        navigate(to: "nav.documents")
        let documentsList = element("documents.list")
        XCTAssertTrue(documentsList.waitForExistence(timeout: 5))

        // Switch back to natural person
        entitySwitcher.click()
        let personalMenuItem = app.menuItems["Personal"]
        XCTAssertTrue(personalMenuItem.waitForExistence(timeout: 5))
        personalMenuItem.click()

        // Verify original documents reappear
        navigate(to: "nav.documents")
        let receiptDocument = element("documents.document.sample-receipt-pdf")
        XCTAssertTrue(receiptDocument.waitForExistence(timeout: 5))
    }

    private func createSoleProprietor(named name: String) {
        let solePropField = element("settings.solePropNameField")
        XCTAssertTrue(solePropField.waitForExistence(timeout: 5))
        replaceText(in: solePropField, with: name)

        let addButton = element("settings.addSolePropButton")
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.click()

        let removeButton = element("settings.entity.remove.\(accessibilitySlug(name))")
        XCTAssertTrue(removeButton.waitForExistence(timeout: 5))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForElement(
        _ identifier: String,
        fallbackLabel: String? = nil,
        type: XCUIElement.ElementType = .any,
        timeout: TimeInterval = 5
    ) -> XCUIElement {
        let identified = app.descendants(matching: type).matching(identifier: identifier).firstMatch
        if identified.waitForExistence(timeout: timeout) {
            return identified
        }

        guard let fallbackLabel else {
            XCTFail("Expected element \(identifier) to exist")
            return identified
        }

        let fallback = app.descendants(matching: type)
            .matching(NSPredicate(format: "label == %@", fallbackLabel))
            .firstMatch
        XCTAssertTrue(
            fallback.waitForExistence(timeout: timeout),
            "Expected element \(identifier) or fallback label \(fallbackLabel) to exist"
        )
        return fallback
    }

    private func clickElement(_ element: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))

        if element.isHittable {
            element.click()
            return
        }

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"),
            object: element
        )
        if XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed {
            element.click()
            return
        }

        XCTAssertFalse(element.frame.isEmpty, "Expected \(element) to have a non-empty frame for coordinate click")
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
    }

    private func selectLedgerTransaction(matching query: String) {
        let searchField = app.textFields["Search transactions"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        replaceText(in: searchField, with: query)
        searchField.typeText("\n")

        let transactionRowIdentifier = "ledger.transaction.\(accessibilitySlug(query))"
        let transactionRow = waitForElement(
            transactionRowIdentifier,
            fallbackLabel: query,
            timeout: 5
        )
        let transactionsList = element("ledger.transactions")
        XCTAssertTrue(transactionsList.waitForExistence(timeout: 5))
        if transactionRow.frame.isEmpty == false {
            clickElement(transactionRow)
        } else {
            let firstVisibleRow = transactionsList.children(matching: .tableRow).firstMatch
            if firstVisibleRow.waitForExistence(timeout: 2), firstVisibleRow.frame.isEmpty == false {
                clickElement(firstVisibleRow)
            } else {
                let rowLabel = app.staticTexts[query].firstMatch
                if rowLabel.waitForExistence(timeout: 2), rowLabel.frame.isEmpty == false {
                    clickElement(rowLabel)
                } else {
                    clickElement(transactionsList)
                    app.typeKey(XCUIKeyboardKey.downArrow.rawValue, modifierFlags: [])
                }
            }
        }
    }

    private func createWorkspace(named name: String) {
        let workspaceChooser = element("workspace.chooser")
        XCTAssertTrue(workspaceChooser.waitForExistence(timeout: 10))

        let createNewButton = waitForElement(
            "workspace.createNewButton",
            fallbackLabel: "Create New Workspace"
        )
        createNewButton.click()

        let workspaceNameField = element("workspace.nameField")
        XCTAssertTrue(workspaceNameField.waitForExistence(timeout: 5))
        replaceText(in: workspaceNameField, with: name)

        let createWorkspaceButton = waitForElement(
            "workspace.createButton",
            fallbackLabel: "Create Workspace"
        )
        createWorkspaceButton.click()

        XCTAssertTrue(element("toolbar.importMenu").waitForExistence(timeout: 10))
        XCTAssertFalse(workspaceChooser.exists)
    }

    private func importSampleDataFromMenu() {
        selectFileMenuItem("Import Sample Data")
    }

    private func importQAValidationFixturesFromMenu() {
        selectFileMenuItem("Import QA Validation Fixtures")
    }

    private func navigate(to identifier: String) {
        let navigation = element(identifier)
        XCTAssertTrue(navigation.waitForExistence(timeout: 5))
        navigation.click()
    }

    private func selectFileMenuItem(_ title: String) {
        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 5))
        fileMenu.click()

        let menuItem = app.menuItems[title]
        XCTAssertTrue(menuItem.waitForExistence(timeout: 5))
        menuItem.click()
    }

    private func replaceText(in element: XCUIElement, with newValue: String) {
        element.click()
        app.typeKey("a", modifierFlags: .command)
        app.typeText(newValue)
    }

    private func waitForLabel(_ identifier: String, equals expectedLabel: String, timeout: TimeInterval = 5) {
        let target = element(identifier)
        XCTAssertTrue(target.waitForExistence(timeout: timeout))
        let predicate = NSPredicate(format: "label == %@ OR value == %@", expectedLabel, expectedLabel)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }

    private func waitForNonExistence(_ identifier: String, timeout: TimeInterval = 5) {
        let target = element(identifier)
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: target)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: timeout), .completed)
    }

    private func accessibilitySlug(_ value: String) -> String {
        let lowered = value.lowercased()
        let allowed = CharacterSet.alphanumerics
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(String(scalar)) : "-"
        }
        let collapsed = String(scalars)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "item" : collapsed
    }
}
