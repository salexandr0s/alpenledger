import XCTest

final class AlpenLedgerAppUITests: XCTestCase {
    func testLaunchShowsWorkspaceChooser() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["AlpenLedger"].waitForExistence(timeout: 5))
    }
}
