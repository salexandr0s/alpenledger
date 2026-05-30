import Foundation
import Testing
@testable import ALDomain
@testable import ALTaxCH
@testable import ALTaxCore

@Test
func swissVATDeclarationExportGeneratesExpectedECH0217XML() throws {
    let report = try fixtureVATReport()
    let metadata = try fixtureMetadata()
    let export = try SwissVATDeclarationExportService()
        .generateEffectiveReportingMethodExport(report: report, metadata: metadata)
    let expectedXML = try String(contentsOf: fixtureURL("Fixtures/VAT/eCH-0217-effective-reporting-2026.xml"), encoding: .utf8)

    #expect(export.format == "eCH-0217")
    #expect(export.schemaVersion == "2.0.0")
    #expect(export.validationIssues.isEmpty)
    #expect(export.xmlString == expectedXML)
    #expect(export.sourceRefs.first == ObjectRef(kind: .vatPeriod, id: report.period.id.rawValue))
    #expect(export.sourceRefs.count == report.lines.count + 1)
}

@Test
func swissVATDeclarationExportRejectsMissingUID() throws {
    let report = try fixtureVATReport()
    let metadata = try SwissVATDeclarationMetadata(
        uid: "",
        organisationName: "AlpenLedger Synthetic VAT AG",
        generationTime: date("2026-07-05T09:30:47Z"),
        businessReferenceId: "AL-VAT-2026-Q2",
        sendingApplication: SwissVATDeclarationSendingApplication(productVersion: "0.1.0")
    )

    do {
        _ = try SwissVATDeclarationExportService()
            .generateEffectiveReportingMethodExport(report: report, metadata: metadata)
        Issue.record("Expected eCH-0217 VAT export to reject a missing UID.")
    } catch let error as SwissVATDeclarationExportError {
        guard case let .validationFailed(issues) = error else {
            Issue.record("Expected validation failure, got \(error).")
            return
        }
        #expect(issues.contains { $0.code == "vat_export.invalid_uid" })
    }
}

@Test
func swissVATDeclarationExportRejectsReconciliationWarnings() throws {
    let accountId = FinancialAccountID()
    let period = VATPeriod(
        entityId: LegalEntityID(),
        periodStart: try date("2026-04-01T00:00:00Z"),
        periodEnd: try date("2026-06-30T23:59:59Z"),
        currency: .chf
    )
    let transaction = Transaction(
        accountId: accountId,
        sourceLineRef: "fixture:refund",
        bookingDate: try date("2026-05-01T00:00:00Z"),
        amountMinor: -10_810,
        currency: .chf,
        counterpartyName: "Refunded Customer AG",
        memo: "Credit note refund",
        taxCode: "CH-VAT-OUTPUT-STD"
    )
    let report = VATPeriodComputationService(codeBook: SwissVATCodeBook.current2026())
        .reconcile(period: period, transactions: [transaction])

    do {
        _ = try SwissVATDeclarationExportService()
            .generateEffectiveReportingMethodExport(report: report, metadata: try fixtureMetadata())
        Issue.record("Expected eCH-0217 VAT export to reject unreconciled warnings.")
    } catch let error as SwissVATDeclarationExportError {
        guard case let .validationFailed(issues) = error else {
            Issue.record("Expected validation failure, got \(error).")
            return
        }
        #expect(issues.contains { $0.code == "vat_export.reconciliation_warnings" })
    }
}

@Test
func swissVATDeclarationValidatorRejectsMalformedPayload() {
    let issues = SwissVATDeclarationExportService()
        .validate(xmlString: "<VATDeclaration><payableTax>7.85</payableTax>")

    #expect(issues.contains { $0.code == "vat_export.xml_not_well_formed" })
}

private struct ExportVATFixture: Decodable {
    let jurisdiction: String
    let rulesetVersion: String
    let period: ExportVATFixturePeriod
    let transactions: [ExportVATFixtureTransaction]
}

private struct ExportVATFixturePeriod: Decodable {
    let start: String
    let end: String
    let currency: CurrencyCode

    var startDate: Date { ISO8601DateFormatter().date(from: start)! }
    var endDate: Date { ISO8601DateFormatter().date(from: end)! }
}

private struct ExportVATFixtureTransaction: Decodable {
    let id: UUID
    let bookingDate: String
    let amountMinor: Int64
    let currency: CurrencyCode
    let counterpartyName: String
    let memo: String
    let taxCode: String?

    func transaction(accountId: FinancialAccountID) -> Transaction {
        Transaction(
            id: TransactionID(rawValue: id),
            accountId: accountId,
            sourceLineRef: "vat-fixture:\(id.uuidString.lowercased())",
            bookingDate: ISO8601DateFormatter().date(from: bookingDate)!,
            amountMinor: amountMinor,
            currency: currency,
            counterpartyName: counterpartyName,
            memo: memo,
            taxCode: taxCode,
            reviewState: .reviewed
        )
    }
}

private func fixtureVATReport() throws -> VATReconciliationReport {
    let fixture = try loadExportVATFixture()
    let period = VATPeriod(
        id: VATPeriodID(rawValue: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!),
        entityId: LegalEntityID(),
        periodStart: fixture.period.startDate,
        periodEnd: fixture.period.endDate,
        currency: fixture.period.currency
    )
    let transactions = fixture.transactions.map { $0.transaction(accountId: FinancialAccountID()) }
    return VATPeriodComputationService(codeBook: SwissVATCodeBook.current2026())
        .reconcile(period: period, transactions: transactions)
}

private func fixtureMetadata() throws -> SwissVATDeclarationMetadata {
    SwissVATDeclarationMetadata(
        uid: "CHE-123.456.789 MWST",
        organisationName: "AlpenLedger Synthetic VAT AG",
        generationTime: try date("2026-07-05T09:30:47Z"),
        businessReferenceId: "AL-VAT-2026-Q2",
        sendingApplication: SwissVATDeclarationSendingApplication(productVersion: "0.1.0")
    )
}

private func loadExportVATFixture() throws -> ExportVATFixture {
    let url = try fixtureURL("Fixtures/VAT/simple-quarter-2026.json")
    let data = try Data(contentsOf: url)
    return try JSONDecoder.alpenLedger.decode(ExportVATFixture.self, from: data)
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

private func date(_ rawValue: String) throws -> Date {
    try #require(ISO8601DateFormatter().date(from: rawValue))
}
