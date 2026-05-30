import Foundation
import Testing
@testable import ALDocuments
@testable import ALDomain

@Test
func documentTypeDetectionFindsReceiptKeyword() {
    let pipeline = DocumentExtractionPipeline()
    let type = pipeline.detectDocumentType(filename: "sample-receipt.pdf", extractedText: "Receipt Coffee Bar Zurich")

    #expect(type == .receipt)
}

@Test
func documentMetadataDetectionMarksFilenameOnlySignalsAsLowConfidence() {
    let pipeline = DocumentExtractionPipeline()
    let detection = pipeline.detectMetadata(filename: "sample-receipt.pdf", extractedText: nil)

    #expect(detection.documentType == .receipt)
    #expect(detection.confidence == .low)
    #expect(detection.metadataStatus == .proposed)
    #expect(detection.reason.contains("filename only"))
}

@Test
func documentMetadataDetectionConfirmsTextBackedSignals() {
    let pipeline = DocumentExtractionPipeline()
    let detection = pipeline.detectMetadata(
        filename: "upload.bin",
        extractedText: "Receipt Coffee Bar Zurich"
    )

    #expect(detection.documentType == .receipt)
    #expect(detection.confidence == .high)
    #expect(detection.metadataStatus == .confirmed)
}

@Test
func documentTypeDetectionFindsSwissQRBillPayload() {
    let pipeline = DocumentExtractionPipeline()
    let type = pipeline.detectDocumentType(
        filename: "payment.txt",
        extractedText: """
        SPC
        0200
        1
        SYNTHETIC-QR-ACCOUNT
        """
    )

    #expect(type == .qrBill)
}

@Test
func documentTypeDetectionFindsSalaryCertificateKeywords() {
    let pipeline = DocumentExtractionPipeline()
    let type = pipeline.detectDocumentType(
        filename: "salary-certificate.txt",
        extractedText: "Salary Certificate 2026"
    )

    #expect(type == .salaryCertificate)
}

@Test
func documentTypeDetectionFindsHealthInsuranceKeywords() {
    let pipeline = DocumentExtractionPipeline()
    let type = pipeline.detectDocumentType(
        filename: "insurance.txt",
        extractedText: "Krankenkasse Steuerbescheinigung 2026"
    )

    #expect(type == .healthInsuranceCertificate)
}

@Test
func documentTypeDetectionFindsPillar3AKeywords() {
    let pipeline = DocumentExtractionPipeline()
    let type = pipeline.detectDocumentType(
        filename: "pillar3a.txt",
        extractedText: "Saeule 3a contribution confirmation"
    )

    #expect(type == .pillar3aCertificate)
}

@Test
func documentPipelineRecognizesECHTaxCertificateFixtures() throws {
    let pipeline = DocumentExtractionPipeline()
    let cases: [(String, DocumentType)] = [
        ("Fixtures/Tax/eCH/eCH-0196-tax-statement-2026.xml", .eCH0196TaxStatement),
        ("Fixtures/Tax/eCH/eCH-0248-pension-contributions-2026.xml", .eCH0248PensionCertificate),
        ("Fixtures/Tax/eCH/eCH-0275-health-insurance-2026.xml", .eCH0275HealthInsuranceCertificate),
    ]

    for (path, expectedType) in cases {
        let url = try fixtureURL(path)
        let text = try #require(pipeline.extractText(from: url, mediaType: "application/xml"))
        let type = pipeline.detectDocumentType(filename: url.lastPathComponent, extractedText: text)
        let issueDate = try #require(pipeline.inferredIssueDate(from: text))
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: issueDate)

        #expect(type == expectedType)
        #expect(components.year == 2026)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }
}

@Test
func qrBillExtractionParsesStructuredPaymentFields() throws {
    let pipeline = DocumentExtractionPipeline()
    let text = try String(contentsOf: fixtureURL("Fixtures/Documents/sample-qr-bill.txt"), encoding: .utf8)
    let extraction = try #require(pipeline.extractQRBillFields(from: text))

    #expect(extraction.creditorAccount == "SYNTHETIC-QR-ACCOUNT")
    #expect(extraction.creditor?.name == "Alpine Utilities AG")
    #expect(extraction.creditor?.street == "Ledgerstrasse")
    #expect(extraction.creditor?.buildingNumber == "8")
    #expect(extraction.creditor?.postalCode == "8000")
    #expect(extraction.creditor?.town == "Zurich")
    #expect(extraction.creditor?.countryCode == "CH")
    #expect(extraction.debtor?.name == "Sample Customer")
    #expect(extraction.debtor?.street == "Balanceweg")
    #expect(extraction.debtor?.buildingNumber == "4")
    #expect(extraction.debtor?.postalCode == "3000")
    #expect(extraction.debtor?.town == "Bern")
    #expect(extraction.debtor?.countryCode == "CH")
    #expect(extraction.amount == Money(minorUnits: 194_975, currency: .chf))
    #expect(extraction.referenceType == "QRR")
    #expect(extraction.reference == "210000000003139471430009017")
    #expect(extraction.additionalInformation == "Synthetic invoice QR-2026-001")
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
