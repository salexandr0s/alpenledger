import Foundation
import Testing
@testable import ALImports
@testable import ALDomain

@Test
func csvImporterRecognizesFixtureHeader() throws {
    let importer = CSVBankStatementImporter()
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-bank-statement.csv")

    #expect(try importer.canRecognize(fixtureURL))
}

@Test
func csvImporterParsesRowsIntoTransactions() throws {
    let importer = CSVBankStatementImporter()
    let fixtureURL = try fixtureURL("Fixtures/Bank/sample-bank-statement.csv")
    let payload = try importer.parse(
        fixtureURL,
        accountId: FinancialAccountID(),
        importJobId: ImportJobID(),
        sourceBlobHash: "fixture"
    )

    #expect(payload.transactions.count == 3)
    #expect(payload.statementImport.sourceFormat == "csv")
    #expect(payload.parseLog.importedRowCount == 3)
}

private func fixtureURL(_ relativePath: String) throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let url = packageRoot.appendingPathComponent(relativePath)
    return url
}
