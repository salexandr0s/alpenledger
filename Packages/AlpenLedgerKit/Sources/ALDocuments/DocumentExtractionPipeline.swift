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
        if mediaType.hasPrefix("text/") || url.pathExtension.lowercased() == "txt" {
            return try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    public func detectDocumentType(filename: String, extractedText: String?) -> DocumentType {
        let haystack = "\(filename.lowercased()) \(extractedText?.lowercased() ?? "")"
        if haystack.contains("salary certificate") || haystack.contains("lohnausweis") {
            return .salaryCertificate
        }
        if haystack.contains("health insurance") || haystack.contains("krankenkasse") || haystack.contains("steuerbescheinigung") {
            return .healthInsuranceCertificate
        }
        if haystack.contains("pillar 3a") || haystack.contains("säule 3a") || haystack.contains("saeule 3a") {
            return .pillar3aCertificate
        }
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

    public func inferredIssueDate(from extractedText: String?) -> Date? {
        guard let extractedText,
              let taxYearLine = extractedText
                .components(separatedBy: .newlines)
                .first(where: { $0.lowercased().hasPrefix("tax_year:") })
        else {
            return nil
        }

        let yearString = taxYearLine.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let yearString, let year = Int(yearString) else {
            return nil
        }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 1, day: 1))
    }
}
