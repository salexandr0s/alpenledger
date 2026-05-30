import Foundation
import Testing
@testable import ALDomain
@testable import ALImports

@Test
func importerFixtureHarnessValidatesBankStatementImporterContracts() throws {
    let fixtures = bankStatementImporterFixtures()

    for fixture in fixtures {
        try ImporterFixtureHarness(fixture: fixture).assertImporterContract()
    }
}

@Test
func importerFixtureHarnessChecksRecognizerSpecificity() throws {
    let fixtures = bankStatementImporterFixtures()

    for fixture in fixtures {
        let importer = fixture.makeImporter()

        for candidate in fixtures {
            let candidateURL = try fixtureURL(candidate.relativePath)
            let isSameParserFixture = candidate.parserKey == fixture.parserKey

            if candidate.id == fixture.id || isSameParserFixture {
                #expect(try importer.canRecognize(candidateURL))
            } else {
                #expect(try importer.canRecognize(candidateURL) == false)
            }
        }
    }
}

private struct ImporterFixtureHarness {
    let fixture: ImporterFixture

    func assertImporterContract() throws {
        let importer = fixture.makeImporter()
        let fixtureURL = try fixtureURL(fixture.relativePath)
        let accountId = FinancialAccountID()
        let importJobId = ImportJobID()
        let sourceBlobHash = "harness-\(fixture.id)"

        #expect(try importer.canRecognize(fixtureURL))
        #expect(importer.parserKey == fixture.parserKey)
        #expect(importer.parserVersion == fixture.parserVersion)
        #expect(importer.importJobKind == fixture.importJobKind)

        let payload = try importer.parse(
            fixtureURL,
            accountId: accountId,
            importJobId: importJobId,
            sourceBlobHash: sourceBlobHash
        )

        #expect(payload.statementImport.accountId == accountId)
        #expect(payload.statementImport.importJobId == importJobId)
        #expect(payload.statementImport.sourceBlobHash == sourceBlobHash)
        #expect(payload.statementImport.sourceFormat == fixture.sourceFormat)
        #expect(payload.statementImport.parserVersion == fixture.parserVersion)
        #expect(payload.statementImport.sourceFingerprint.isEmpty == false)
        #expect(payload.statementImport.coverageStart <= payload.statementImport.coverageEnd)
        #expect(payload.statementImport.openingBalanceMinor == fixture.openingBalanceMinor)
        #expect(payload.statementImport.closingBalanceMinor == fixture.closingBalanceMinor)

        #expect(payload.parseLog.parserKey == fixture.parserKey)
        #expect(payload.parseLog.parserVersion == fixture.parserVersion)
        #expect(payload.parseLog.importedRowCount == fixture.transactionCount)
        #expect(payload.parseLog.importedRowCount == payload.transactions.count)
        #expect(payload.parseLog.warnings.count == fixture.warningCount)
        #expect(payload.parseLog.errors.isEmpty)

        #expect(payload.transactions.count == fixture.transactionCount)
        #expect(payload.transactions.allSatisfy { $0.accountId == accountId })
        #expect(payload.transactions.allSatisfy { $0.statementImportId == Optional(payload.statementImport.id) })
        #expect(payload.transactions.allSatisfy { $0.currency == .chf })
        #expect(payload.transactions.map(\.amountMinor) == fixture.amountsMinor)
        #expect(payload.transactions.map(\.reference) == fixture.references)
        #expect(payload.transactions.map(\.sourceLineRef) == fixture.sourceLineRefs)
    }
}

private struct ImporterFixture {
    let id: String
    let relativePath: String
    let makeImporter: () -> any Importer
    let importJobKind: ImportJobKind
    let parserKey: String
    let parserVersion: String
    let sourceFormat: String
    let transactionCount: Int
    let warningCount: Int
    let openingBalanceMinor: Int64?
    let closingBalanceMinor: Int64?
    let amountsMinor: [Int64]
    let references: [String?]
    let sourceLineRefs: [String]
}

private func bankStatementImporterFixtures() -> [ImporterFixture] {
    [
        ImporterFixture(
            id: "csv.sample_statement",
            relativePath: "Fixtures/Bank/sample-bank-statement.csv",
            makeImporter: { CSVBankStatementImporter() },
            importJobKind: .bankStatementCSV,
            parserKey: "csv.bankstatement",
            parserVersion: "1.2.0",
            sourceFormat: "csv",
            transactionCount: 3,
            warningCount: 0,
            openingBalanceMinor: 250_000,
            closingBalanceMinor: 233_750,
            amountsMinor: [250_000, -4_250, -12_000],
            references: ["INV-1001", "POS-444", "TRV-220"],
            sourceLineRefs: ["csv:2", "csv:3", "csv:4"]
        ),
        ImporterFixture(
            id: "camt052.single_report",
            relativePath: "Fixtures/Bank/sample-camt052-report.xml",
            makeImporter: { CAMTBankStatementImporter(format: .camt052) },
            importJobKind: .bankStatementCAMT,
            parserKey: "camt.052.bankstatement",
            parserVersion: "1.0.0",
            sourceFormat: "camt.052",
            transactionCount: 2,
            warningCount: 0,
            openingBalanceMinor: 100_000,
            closingBalanceMinor: 87_500,
            amountsMinor: [50_000, -62_500],
            references: ["HLT-2026-02", "RENT-2026-02"],
            sourceLineRefs: ["camt:1", "camt:2"]
        ),
        ImporterFixture(
            id: "camt052.multi_report",
            relativePath: "Fixtures/Bank/sample-camt052-multi-report.xml",
            makeImporter: { CAMTBankStatementImporter(format: .camt052) },
            importJobKind: .bankStatementCAMT,
            parserKey: "camt.052.bankstatement",
            parserVersion: "1.0.0",
            sourceFormat: "camt.052",
            transactionCount: 2,
            warningCount: 0,
            openingBalanceMinor: 200_000,
            closingBalanceMinor: 232_500,
            amountsMinor: [50_000, -17_500],
            references: ["WORK-2026-04", "CLOUD-2026-04"],
            sourceLineRefs: ["camt:1", "camt:2"]
        ),
        ImporterFixture(
            id: "camt053.single_statement",
            relativePath: "Fixtures/Bank/sample-camt053-statement.xml",
            makeImporter: { CAMTBankStatementImporter(format: .camt053) },
            importJobKind: .bankStatementCAMT,
            parserKey: "camt.053.bankstatement",
            parserVersion: "1.0.0",
            sourceFormat: "camt.053",
            transactionCount: 3,
            warningCount: 0,
            openingBalanceMinor: 0,
            closingBalanceMinor: 233_750,
            amountsMinor: [250_000, -4_250, -12_000],
            references: ["INV-1001", "POS-444", "TRV-220"],
            sourceLineRefs: ["camt:1", "camt:2", "camt:3"]
        ),
        ImporterFixture(
            id: "camt053.multi_statement",
            relativePath: "Fixtures/Bank/sample-camt053-multi-statement.xml",
            makeImporter: { CAMTBankStatementImporter(format: .camt053) },
            importJobKind: .bankStatementCAMT,
            parserKey: "camt.053.bankstatement",
            parserVersion: "1.0.0",
            sourceFormat: "camt.053",
            transactionCount: 2,
            warningCount: 0,
            openingBalanceMinor: 100_000,
            closingBalanceMinor: 95_000,
            amountsMinor: [10_000, -15_000],
            references: ["STUDIO-2026-05", "INS-2026-05"],
            sourceLineRefs: ["camt:1", "camt:2"]
        ),
        ImporterFixture(
            id: "camt054.single_notification",
            relativePath: "Fixtures/Bank/sample-camt054-notification.xml",
            makeImporter: { CAMTBankStatementImporter(format: .camt054) },
            importJobKind: .bankStatementCAMT,
            parserKey: "camt.054.bankstatement",
            parserVersion: "1.0.0",
            sourceFormat: "camt.054",
            transactionCount: 2,
            warningCount: 0,
            openingBalanceMinor: nil,
            closingBalanceMinor: nil,
            amountsMinor: [150_000, -3_000],
            references: ["QR-2026-03", "FEE-2026-03"],
            sourceLineRefs: ["camt:1", "camt:2"]
        ),
        ImporterFixture(
            id: "camt054.batch_notification",
            relativePath: "Fixtures/Bank/sample-camt054-batch-notification.xml",
            makeImporter: { CAMTBankStatementImporter(format: .camt054) },
            importJobKind: .bankStatementCAMT,
            parserKey: "camt.054.bankstatement",
            parserVersion: "1.0.0",
            sourceFormat: "camt.054",
            transactionCount: 3,
            warningCount: 0,
            openingBalanceMinor: nil,
            closingBalanceMinor: nil,
            amountsMinor: [45_000, 30_000, -8_000],
            references: ["BATCH-450", "BATCH-300", "TERM-2026-06"],
            sourceLineRefs: ["camt:1.1", "camt:1.2", "camt:2"]
        ),
    ]
}

private func fixtureURL(_ relativePath: String) throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return packageRoot.appendingPathComponent(relativePath)
}
