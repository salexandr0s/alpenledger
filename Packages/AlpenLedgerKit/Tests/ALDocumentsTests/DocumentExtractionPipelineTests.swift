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
