import Foundation
import PDFKit
import UniformTypeIdentifiers
import ALDomain

public final class DocumentExtractionPipeline: @unchecked Sendable {
    public init() {}

    public func extractText(from url: URL, mediaType: String) -> String? {
        if mediaType == UTType.pdf.preferredMIMEType || url.pathExtension.lowercased() == "pdf" {
            return PDFDocument(url: url)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    public func detectDocumentType(filename: String, extractedText: String?) -> DocumentType {
        let haystack = "\(filename.lowercased()) \(extractedText?.lowercased() ?? "")"
        if haystack.contains("receipt") || haystack.contains("quittance") {
            return .receipt
        }
        if haystack.contains("invoice") || haystack.contains("rechnung") {
            return .invoice
        }
        if haystack.contains("statement") || haystack.contains("kontoauszug") {
            return .bankStatement
        }
        return .unknown
    }
}
