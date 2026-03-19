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
