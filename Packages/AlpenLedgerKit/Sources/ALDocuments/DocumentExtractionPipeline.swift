import Foundation
import PDFKit
import UniformTypeIdentifiers
import ALDomain

public struct QRBillAddress: Hashable, Sendable {
    public let name: String
    public let street: String?
    public let buildingNumber: String?
    public let postalCode: String?
    public let town: String?
    public let countryCode: String?

    public init(
        name: String,
        street: String? = nil,
        buildingNumber: String? = nil,
        postalCode: String? = nil,
        town: String? = nil,
        countryCode: String? = nil
    ) {
        self.name = name
        self.street = street
        self.buildingNumber = buildingNumber
        self.postalCode = postalCode
        self.town = town
        self.countryCode = countryCode
    }
}

public struct QRBillExtraction: Hashable, Sendable {
    public let creditorAccount: String?
    public let creditor: QRBillAddress?
    public let debtor: QRBillAddress?
    public let amount: Money?
    public let referenceType: String?
    public let reference: String?
    public let additionalInformation: String?

    public init(
        creditorAccount: String? = nil,
        creditor: QRBillAddress? = nil,
        debtor: QRBillAddress? = nil,
        amount: Money? = nil,
        referenceType: String? = nil,
        reference: String? = nil,
        additionalInformation: String? = nil
    ) {
        self.creditorAccount = creditorAccount
        self.creditor = creditor
        self.debtor = debtor
        self.amount = amount
        self.referenceType = referenceType
        self.reference = reference
        self.additionalInformation = additionalInformation
    }
}

public enum DocumentExtractionConfidence: String, Hashable, Sendable {
    case high
    case low
}

public struct DocumentMetadataDetection: Hashable, Sendable {
    public let documentType: DocumentType
    public let confidence: DocumentExtractionConfidence
    public let reason: String

    public var metadataStatus: MetadataStatus {
        confidence == .high ? .confirmed : .proposed
    }

    public init(
        documentType: DocumentType,
        confidence: DocumentExtractionConfidence,
        reason: String
    ) {
        self.documentType = documentType
        self.confidence = confidence
        self.reason = reason
    }
}

public final class DocumentExtractionPipeline: Sendable {
    public init() {}

    public func extractText(from url: URL, mediaType: String) -> String? {
        if mediaType == UTType.pdf.preferredMIMEType || url.pathExtension.lowercased() == "pdf" {
            return normalizedExtractedText(PDFDocument(url: url)?.string)
        }
        if mediaType.hasPrefix("text/")
            || mediaType == "application/xml"
            || mediaType == "text/xml"
            || url.pathExtension.lowercased() == "txt"
            || url.pathExtension.lowercased() == "xml" {
            return normalizedExtractedText(try? String(contentsOf: url, encoding: .utf8))
        }
        return nil
    }

    public func detectDocumentType(filename: String, extractedText: String?) -> DocumentType {
        detectMetadata(filename: filename, extractedText: extractedText).documentType
    }

    public func detectMetadata(filename: String, extractedText: String?) -> DocumentMetadataDetection {
        let normalizedText = extractedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasExtractedText = normalizedText?.isEmpty == false
        let lowerFilename = filename.lowercased()
        let lowerText = normalizedText?.lowercased() ?? ""
        let haystack = "\(lowerFilename) \(lowerText)"

        if looksLikeSwissQRBill(filename: filename, extractedText: extractedText) {
            return DocumentMetadataDetection(
                documentType: .qrBill,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "Swiss QR-bill payload detected." : "QR-bill inferred from filename only."
            )
        }
        if haystack.contains("ech-0196") || haystack.contains("e-steuerauszug") || haystack.contains("electronic tax statement") {
            return DocumentMetadataDetection(
                documentType: .eCH0196TaxStatement,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "eCH-0196 tax-statement marker detected." : "eCH-0196 inferred from filename only."
            )
        }
        if haystack.contains("ech-0248") || haystack.contains("pensioncontributioncertificate") || haystack.contains("vorsorgebeiträge") {
            return DocumentMetadataDetection(
                documentType: .eCH0248PensionCertificate,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "eCH-0248 pension-certificate marker detected." : "eCH-0248 inferred from filename only."
            )
        }
        if haystack.contains("ech-0275") || haystack.contains("healthinsurancetaxcertificate") || haystack.contains("steuerbescheinigung der krankenkassen") {
            return DocumentMetadataDetection(
                documentType: .eCH0275HealthInsuranceCertificate,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "eCH-0275 health-insurance marker detected." : "eCH-0275 inferred from filename only."
            )
        }
        if haystack.contains("salary certificate") || haystack.contains("lohnausweis") {
            return DocumentMetadataDetection(
                documentType: .salaryCertificate,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "Salary-certificate marker detected." : "Salary certificate inferred from filename only."
            )
        }
        if haystack.contains("health insurance") || haystack.contains("krankenkasse") || haystack.contains("steuerbescheinigung") {
            return DocumentMetadataDetection(
                documentType: .healthInsuranceCertificate,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "Health-insurance certificate marker detected." : "Health-insurance certificate inferred from filename only."
            )
        }
        if haystack.contains("pillar 3a") || haystack.contains("säule 3a") || haystack.contains("saeule 3a") {
            return DocumentMetadataDetection(
                documentType: .pillar3aCertificate,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "Pillar 3a marker detected." : "Pillar 3a certificate inferred from filename only."
            )
        }
        if haystack.contains("receipt") || haystack.contains("quittance") {
            return DocumentMetadataDetection(
                documentType: .receipt,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "Receipt marker detected." : "Receipt inferred from filename only."
            )
        }
        if haystack.contains("invoice") || haystack.contains("rechnung") {
            return DocumentMetadataDetection(
                documentType: .invoice,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "Invoice marker detected." : "Invoice inferred from filename only."
            )
        }
        if haystack.contains("statement") || haystack.contains("kontoauszug") {
            return DocumentMetadataDetection(
                documentType: .bankStatement,
                confidence: hasExtractedText ? .high : .low,
                reason: hasExtractedText ? "Bank-statement marker detected." : "Bank statement inferred from filename only."
            )
        }
        return DocumentMetadataDetection(
            documentType: .unknown,
            confidence: .low,
            reason: hasExtractedText ? "No supported document type marker detected." : "No extracted text was available."
        )
    }

    public func extractQRBillFields(from extractedText: String?) -> QRBillExtraction? {
        guard let extractedText else { return nil }
        let rawLines = extractedText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard rawLines.first == "SPC",
              rawLines.count >= 24
        else {
            return nil
        }

        let amount: Money?
        if let decimal = Decimal(string: rawLines[18]),
           let currency = CurrencyCode(rawValue: rawLines[19]) {
            amount = Money(majorUnits: decimal, currency: currency)
        } else {
            amount = nil
        }

        return QRBillExtraction(
            creditorAccount: optional(rawLines[3]),
            creditor: qrBillAddress(from: rawLines, nameIndex: 5, streetIndex: 6, buildingIndex: 7, postalIndex: 8, townIndex: 9, countryIndex: 10),
            debtor: qrBillAddress(from: rawLines, nameIndex: 12, streetIndex: 13, buildingIndex: 14, postalIndex: 15, townIndex: 16, countryIndex: 17),
            amount: amount,
            referenceType: optional(rawLines[20]),
            reference: optional(rawLines[21]),
            additionalInformation: optional(rawLines[22])
        )
    }

    public func inferredIssueDate(from extractedText: String?) -> Date? {
        guard let extractedText else {
            return nil
        }

        guard let year = inferredTaxYear(from: extractedText) else {
            return nil
        }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 1, day: 1))
    }

    private func looksLikeSwissQRBill(filename: String, extractedText: String?) -> Bool {
        let lowerFilename = filename.lowercased()
        if lowerFilename.contains("qr-bill") || lowerFilename.contains("qrbill") || lowerFilename.contains("qr_rechnung") {
            return true
        }

        guard let extractedText else { return false }
        let normalized = extractedText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lower = normalized.lowercased()
        if lower.contains("swiss qr-bill") || lower.contains("qr-rechnung") || lower.contains("qr-bill") {
            return true
        }

        let lines = normalized
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return lines.count > 2 && lines[0] == "SPC" && lines[1].hasPrefix("02")
    }

    private func qrBillAddress(
        from lines: [String],
        nameIndex: Int,
        streetIndex: Int,
        buildingIndex: Int,
        postalIndex: Int,
        townIndex: Int,
        countryIndex: Int
    ) -> QRBillAddress? {
        guard lines.indices.contains(nameIndex),
              let name = optional(lines[nameIndex])
        else {
            return nil
        }

        return QRBillAddress(
            name: name,
            street: optional(lines[safe: streetIndex]),
            buildingNumber: optional(lines[safe: buildingIndex]),
            postalCode: optional(lines[safe: postalIndex]),
            town: optional(lines[safe: townIndex]),
            countryCode: optional(lines[safe: countryIndex])
        )
    }

    private func optional(_ value: String?) -> String? {
        guard let value,
              value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        else {
            return nil
        }
        return value
    }

    private func normalizedExtractedText(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false
        else {
            return nil
        }
        return trimmed
    }

    private func inferredTaxYear(from extractedText: String) -> Int? {
        if let colonYear = firstCapture(
            #"(?im)^\s*tax_year\s*:\s*(\d{4})\s*$"#,
            in: extractedText
        ) {
            return Int(colonYear)
        }
        if let xmlYear = firstCapture(
            #"(?is)<(?:[A-Za-z0-9_-]+:)?taxYear>\s*(\d{4})\s*</(?:[A-Za-z0-9_-]+:)?taxYear>"#,
            in: extractedText
        ) {
            return Int(xmlYear)
        }
        return nil
    }

    private func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = expression.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange])
    }
}

private extension Array where Element == String {
    subscript(safe index: Int) -> String? {
        indices.contains(index) ? self[index] : nil
    }
}
