import Foundation
import ALDomain

public enum SwissVATDeclarationSubmissionType: Int, Codable, CaseIterable, Sendable {
    case initial = 1
    case correction = 2
    case annualReconciliation = 3
}

public enum SwissVATDeclarationFormOfReporting: Int, Codable, CaseIterable, Sendable {
    case agreedConsideration = 1
    case collectedConsideration = 2
}

public struct SwissVATDeclarationSendingApplication: Hashable, Codable, Sendable {
    public let manufacturer: String
    public let product: String
    public let productVersion: String

    public init(
        manufacturer: String = "AlpenLedger",
        product: String = "AlpenLedger",
        productVersion: String
    ) {
        self.manufacturer = manufacturer
        self.product = product
        self.productVersion = productVersion
    }
}

public struct SwissVATDeclarationMetadata: Hashable, Codable, Sendable {
    public let uid: String
    public let organisationName: String
    public let generationTime: Date
    public let typeOfSubmission: SwissVATDeclarationSubmissionType
    public let formOfReporting: SwissVATDeclarationFormOfReporting
    public let businessReferenceId: String
    public let sendingApplication: SwissVATDeclarationSendingApplication

    public init(
        uid: String,
        organisationName: String,
        generationTime: Date,
        typeOfSubmission: SwissVATDeclarationSubmissionType = .initial,
        formOfReporting: SwissVATDeclarationFormOfReporting = .agreedConsideration,
        businessReferenceId: String,
        sendingApplication: SwissVATDeclarationSendingApplication
    ) {
        self.uid = uid
        self.organisationName = organisationName
        self.generationTime = generationTime
        self.typeOfSubmission = typeOfSubmission
        self.formOfReporting = formOfReporting
        self.businessReferenceId = businessReferenceId
        self.sendingApplication = sendingApplication
    }
}

public struct SwissVATDeclarationValidationIssue: Hashable, Codable, Sendable {
    public let severity: VATReconciliationIssueSeverity
    public let code: String
    public let message: String
    public let sourceRef: ObjectRef?

    public init(
        severity: VATReconciliationIssueSeverity,
        code: String,
        message: String,
        sourceRef: ObjectRef? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.sourceRef = sourceRef
    }
}

public struct SwissVATDeclarationExport: Hashable, Sendable {
    public let format: String
    public let schemaVersion: String
    public let xmlString: String
    public let validationIssues: [SwissVATDeclarationValidationIssue]
    public let sourceRefs: [ObjectRef]

    public init(
        format: String = SwissVATDeclarationExportService.exportFormat,
        schemaVersion: String = SwissVATDeclarationExportService.schemaVersion,
        xmlString: String,
        validationIssues: [SwissVATDeclarationValidationIssue],
        sourceRefs: [ObjectRef]
    ) {
        self.format = format
        self.schemaVersion = schemaVersion
        self.xmlString = xmlString
        self.validationIssues = validationIssues
        self.sourceRefs = sourceRefs
    }
}

public enum SwissVATDeclarationExportError: Error, Hashable, Sendable {
    case validationFailed([SwissVATDeclarationValidationIssue])
}

public final class SwissVATDeclarationExportService: Sendable {
    public static let exportFormat = "eCH-0217"
    public static let schemaVersion = "2.0.0"
    public static let namespaceURI = "http://www.ech.ch/xmlns/eCH-0217/2"

    private let codeBook: VATCodeBook

    public init(codeBook: VATCodeBook = SwissVATCodeBook.current2026()) {
        self.codeBook = codeBook
    }

    public func generateEffectiveReportingMethodExport(
        report: VATReconciliationReport,
        metadata: SwissVATDeclarationMetadata
    ) throws -> SwissVATDeclarationExport {
        let reportIssues = validate(report: report, metadata: metadata)
        guard reportIssues.contains(where: { $0.severity == .blocker }) == false else {
            throw SwissVATDeclarationExportError.validationFailed(reportIssues)
        }

        let xmlString = buildEffectiveReportingMethodXML(report: report, metadata: metadata)
        let xmlIssues = validate(xmlString: xmlString, expectedReport: report, metadata: metadata)
        guard xmlIssues.contains(where: { $0.severity == .blocker }) == false else {
            throw SwissVATDeclarationExportError.validationFailed(xmlIssues)
        }

        return SwissVATDeclarationExport(
            xmlString: xmlString,
            validationIssues: reportIssues + xmlIssues,
            sourceRefs: sourceRefs(for: report)
        )
    }

    public func validate(
        report: VATReconciliationReport,
        metadata: SwissVATDeclarationMetadata
    ) -> [SwissVATDeclarationValidationIssue] {
        var issues: [SwissVATDeclarationValidationIssue] = []

        if report.jurisdictionCode != "CH" {
            issues.append(blocker(
                "vat_export.unsupported_jurisdiction",
                "eCH-0217 VAT export only supports Swiss VAT reports.",
                sourceRef: ObjectRef(kind: .vatPeriod, id: report.period.id.rawValue)
            ))
        }
        if report.rulesetVersion != codeBook.rulesetVersion || report.jurisdictionCode != codeBook.jurisdictionCode {
            issues.append(blocker(
                "vat_export.ruleset_mismatch",
                "VAT reconciliation ruleset does not match the export code book.",
                sourceRef: ObjectRef(kind: .vatPeriod, id: report.period.id.rawValue)
            ))
        }
        if report.period.currency != .chf {
            issues.append(blocker(
                "vat_export.currency_not_supported",
                "eCH-0217 export currently supports CHF VAT periods only.",
                sourceRef: ObjectRef(kind: .vatPeriod, id: report.period.id.rawValue)
            ))
        }
        if report.period.periodStart > report.period.periodEnd {
            issues.append(blocker(
                "vat_export.invalid_period",
                "VAT reporting period start must be on or before the end date.",
                sourceRef: ObjectRef(kind: .vatPeriod, id: report.period.id.rawValue)
            ))
        }
        if report.blockerCount > 0 {
            issues.append(blocker(
                "vat_export.reconciliation_blockers",
                "VAT export cannot be generated while blocking reconciliation issues remain.",
                sourceRef: ObjectRef(kind: .vatPeriod, id: report.period.id.rawValue)
            ))
        }
        let warnings = report.issues.filter { $0.severity == .warning }
        if warnings.isEmpty == false {
            issues.append(blocker(
                "vat_export.reconciliation_warnings",
                "VAT export requires all reconciliation warnings to be reviewed before package generation.",
                sourceRef: warnings.first?.sourceRef ?? ObjectRef(kind: .vatPeriod, id: report.period.id.rawValue)
            ))
        }

        if normalizedUID(metadata.uid) == nil {
            issues.append(blocker(
                "vat_export.invalid_uid",
                "Swiss UID must normalize to CHE plus nine digits for eCH-0217 export."
            ))
        }
        if metadata.organisationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(blocker(
                "vat_export.missing_organisation_name",
                "Organisation name is required for eCH-0217 export."
            ))
        }
        if metadata.businessReferenceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(blocker(
                "vat_export.missing_business_reference",
                "Business reference ID is required for eCH-0217 export."
            ))
        }
        if metadata.sendingApplication.product.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            metadata.sendingApplication.productVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            metadata.sendingApplication.manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(blocker(
                "vat_export.missing_application_metadata",
                "Sending application manufacturer, product, and version are required."
            ))
        }

        for line in report.lines {
            guard let vatCode = codeBook.code(line.taxCode, on: report.period.periodStart) else {
                issues.append(blocker(
                    "vat_export.unknown_line_tax_code",
                    "VAT line tax code \(line.taxCode) is not available in the export code book.",
                    sourceRef: ObjectRef(kind: .transaction, id: line.transactionId.rawValue)
                ))
                continue
            }
            if vatCode.treatment != line.treatment {
                issues.append(blocker(
                    "vat_export.line_treatment_mismatch",
                    "VAT line treatment does not match the export code book.",
                    sourceRef: ObjectRef(kind: .transaction, id: line.transactionId.rawValue)
                ))
            }
            if line.currency != report.period.currency {
                issues.append(blocker(
                    "vat_export.line_currency_mismatch",
                    "VAT line currency does not match the reporting period.",
                    sourceRef: ObjectRef(kind: .transaction, id: line.transactionId.rawValue)
                ))
            }
        }

        return issues
    }

    public func validate(
        xmlString: String,
        expectedReport: VATReconciliationReport? = nil,
        metadata: SwissVATDeclarationMetadata? = nil
    ) -> [SwissVATDeclarationValidationIssue] {
        guard let data = xmlString.data(using: .utf8) else {
            return [blocker("vat_export.xml_not_utf8", "VAT declaration XML must be UTF-8 encodable.")]
        }

        let document: XMLDocument
        do {
            document = try XMLDocument(data: data)
        } catch {
            return [blocker("vat_export.xml_not_well_formed", "VAT declaration XML is not well formed.")]
        }

        guard let root = document.rootElement() else {
            return [blocker("vat_export.xml_missing_root", "VAT declaration XML has no root element.")]
        }

        var issues: [SwissVATDeclarationValidationIssue] = []
        if root.localName != "VATDeclaration" || root.uri != Self.namespaceURI {
            issues.append(blocker(
                "vat_export.xml_root_mismatch",
                "VAT declaration root must be eCH-0217:VATDeclaration in namespace \(Self.namespaceURI)."
            ))
        }

        let childNames = root.children?
            .compactMap { $0 as? XMLElement }
            .map(\.localName) ?? []
        let requiredOrder = [
            "generalInformation",
            "turnoverComputation",
            "effectiveReportingMethod",
            "payableTax",
        ]
        var searchStart = childNames.startIndex
        for requiredName in requiredOrder {
            guard let index = childNames[searchStart...].firstIndex(of: requiredName) else {
                issues.append(blocker(
                    "vat_export.xml_missing_element",
                    "VAT declaration XML is missing required element \(requiredName)."
                ))
                continue
            }
            searchStart = childNames.index(after: index)
        }

        guard let generalInformation = firstElement(named: "generalInformation", in: root) else {
            return issues
        }
        guard let turnoverComputation = firstElement(named: "turnoverComputation", in: root) else {
            return issues
        }
        guard let effectiveReportingMethod = firstElement(named: "effectiveReportingMethod", in: root) else {
            return issues
        }

        let uid = textValue("uid", in: generalInformation)
        if uid.flatMap(normalizedUID) == nil {
            issues.append(blocker("vat_export.xml_invalid_uid", "VAT declaration XML UID is invalid."))
        }
        if let metadata, uid != normalizedUID(metadata.uid) {
            issues.append(blocker("vat_export.xml_uid_mismatch", "VAT declaration XML UID does not match metadata."))
        }
        if textValue("organisationName", in: generalInformation)?.isEmpty != false {
            issues.append(blocker("vat_export.xml_missing_organisation_name", "VAT declaration XML is missing organisation name."))
        }
        if textValue("generationTime", in: generalInformation).flatMap(Self.dateTime(from:)) == nil {
            issues.append(blocker("vat_export.xml_invalid_generation_time", "VAT declaration XML generation time is invalid."))
        }
        if textValue("reportingPeriodFrom", in: generalInformation).flatMap(Self.date(from:)) == nil ||
            textValue("reportingPeriodTill", in: generalInformation).flatMap(Self.date(from:)) == nil {
            issues.append(blocker("vat_export.xml_invalid_reporting_period", "VAT declaration XML reporting period dates are invalid."))
        }
        if textValue("typeOfSubmission", in: generalInformation).flatMap(Int.init).flatMap(SwissVATDeclarationSubmissionType.init(rawValue:)) == nil {
            issues.append(blocker("vat_export.xml_invalid_submission_type", "VAT declaration XML typeOfSubmission is invalid."))
        }
        if textValue("formOfReporting", in: generalInformation).flatMap(Int.init).flatMap(SwissVATDeclarationFormOfReporting.init(rawValue:)) == nil {
            issues.append(blocker("vat_export.xml_invalid_reporting_form", "VAT declaration XML formOfReporting is invalid."))
        }

        if textValue("totalConsideration", in: turnoverComputation).flatMap(Self.parseAmount) == nil {
            issues.append(blocker("vat_export.xml_invalid_total_consideration", "VAT declaration XML totalConsideration is invalid."))
        }
        if textValue("grossOrNet", in: effectiveReportingMethod) != "1" {
            issues.append(blocker("vat_export.xml_invalid_gross_or_net", "VAT declaration XML must use net effective reporting method."))
        }
        guard let payableTax = textValue("payableTax", in: root).flatMap(Self.parseAmount) else {
            issues.append(blocker("vat_export.xml_invalid_payable_tax", "VAT declaration XML payableTax is invalid."))
            return issues
        }

        if let expectedReport {
            if textValue("reportingPeriodFrom", in: generalInformation) != Self.dateString(expectedReport.period.periodStart) ||
                textValue("reportingPeriodTill", in: generalInformation) != Self.dateString(expectedReport.period.periodEnd) {
                issues.append(blocker("vat_export.xml_period_mismatch", "VAT declaration XML period does not match the reconciliation report."))
            }
            if payableTax != expectedReport.netTaxPayableMinor {
                issues.append(blocker("vat_export.xml_payable_tax_mismatch", "VAT declaration XML payableTax does not match the reconciliation report."))
            }
        }

        return issues
    }

    private func buildEffectiveReportingMethodXML(
        report: VATReconciliationReport,
        metadata: SwissVATDeclarationMetadata
    ) -> String {
        let summary = declarationSummary(for: report)
        let uid = normalizedUID(metadata.uid) ?? metadata.uid
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <eCH-0217:VATDeclaration xmlns:eCH-0058="http://www.ech.ch/xmlns/eCH-0058/5" xmlns:eCH-0108="http://www.ech.ch/xmlns/eCH-0108/7" xmlns:eCH-0217="\(Self.namespaceURI)" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <eCH-0217:generalInformation>
            <eCH-0217:uid>\(escapeXML(uid))</eCH-0217:uid>
            <eCH-0217:organisationName>\(escapeXML(metadata.organisationName))</eCH-0217:organisationName>
            <eCH-0217:generationTime>\(Self.dateTimeString(metadata.generationTime))</eCH-0217:generationTime>
            <eCH-0217:reportingPeriodFrom>\(Self.dateString(report.period.periodStart))</eCH-0217:reportingPeriodFrom>
            <eCH-0217:reportingPeriodTill>\(Self.dateString(report.period.periodEnd))</eCH-0217:reportingPeriodTill>
            <eCH-0217:typeOfSubmission>\(metadata.typeOfSubmission.rawValue)</eCH-0217:typeOfSubmission>
            <eCH-0217:formOfReporting>\(metadata.formOfReporting.rawValue)</eCH-0217:formOfReporting>
            <eCH-0217:businessReferenceId>\(escapeXML(metadata.businessReferenceId))</eCH-0217:businessReferenceId>
            <eCH-0217:sendingApplication>
              <eCH-0058:manufacturer>\(escapeXML(metadata.sendingApplication.manufacturer))</eCH-0058:manufacturer>
              <eCH-0058:product>\(escapeXML(metadata.sendingApplication.product))</eCH-0058:product>
              <eCH-0058:productVersion>\(escapeXML(metadata.sendingApplication.productVersion))</eCH-0058:productVersion>
            </eCH-0217:sendingApplication>
          </eCH-0217:generalInformation>
          <eCH-0217:turnoverComputation>
            <eCH-0217:totalConsideration>\(Self.amountString(summary.totalConsiderationMinor))</eCH-0217:totalConsideration>
        """

        if summary.exemptTurnoverMinor != 0 {
            xml += "\n    <eCH-0217:suppliesExemptFromTax>\(Self.amountString(summary.exemptTurnoverMinor))</eCH-0217:suppliesExemptFromTax>"
        }

        xml += """

          </eCH-0217:turnoverComputation>
          <eCH-0217:effectiveReportingMethod>
            <eCH-0217:grossOrNet>1</eCH-0217:grossOrNet>
        """

        for turnover in summary.outputTurnoverByRate {
            xml += """

            <eCH-0217:suppliesPerTaxRate>
              <eCH-0217:taxRate>\(Self.percentString(turnover.rateBasisPoints))</eCH-0217:taxRate>
              <eCH-0217:turnover>\(Self.amountString(turnover.turnoverMinor))</eCH-0217:turnover>
            </eCH-0217:suppliesPerTaxRate>
        """
        }

        if report.inputTaxMinor != 0 {
            xml += "\n    <eCH-0217:inputTaxMaterialAndServices>\(Self.amountString(report.inputTaxMinor))</eCH-0217:inputTaxMaterialAndServices>"
        }

        xml += """

          </eCH-0217:effectiveReportingMethod>
          <eCH-0217:payableTax>\(Self.amountString(report.netTaxPayableMinor))</eCH-0217:payableTax>
        </eCH-0217:VATDeclaration>
        """
        return xml + "\n"
    }

    private func declarationSummary(for report: VATReconciliationReport) -> DeclarationSummary {
        var totalConsiderationMinor: Int64 = 0
        var exemptTurnoverMinor: Int64 = 0
        var outputByRate: [Int: Int64] = [:]

        for line in report.lines {
            let signedSourceAmount = line.sourceAmountMinor
            switch line.treatment {
            case .outputTax:
                totalConsiderationMinor += signedSourceAmount
                guard let vatCode = codeBook.code(line.taxCode, on: report.period.periodStart) else { continue }
                outputByRate[vatCode.rateBasisPoints, default: 0] += line.taxableBaseMinor
            case .exempt:
                totalConsiderationMinor += signedSourceAmount
                exemptTurnoverMinor += line.taxableBaseMinor
            case .inputTax, .outsideScope:
                break
            }
        }

        let outputTurnoverByRate = outputByRate
            .map { OutputTurnover(rateBasisPoints: $0.key, turnoverMinor: $0.value) }
            .sorted { lhs, rhs in
                if lhs.rateBasisPoints == rhs.rateBasisPoints {
                    lhs.turnoverMinor < rhs.turnoverMinor
                } else {
                    lhs.rateBasisPoints < rhs.rateBasisPoints
                }
            }

        return DeclarationSummary(
            totalConsiderationMinor: totalConsiderationMinor,
            exemptTurnoverMinor: exemptTurnoverMinor,
            outputTurnoverByRate: outputTurnoverByRate
        )
    }

    private func sourceRefs(for report: VATReconciliationReport) -> [ObjectRef] {
        [ObjectRef(kind: .vatPeriod, id: report.period.id.rawValue)] +
            report.lines.map { ObjectRef(kind: .transaction, id: $0.transactionId.rawValue) }
    }

    private func normalizedUID(_ rawValue: String) -> String? {
        let uppercased = rawValue.uppercased()
        guard let cheRange = uppercased.range(of: "CHE") else { return nil }
        let digits = uppercased[cheRange.upperBound...].filter(\.isNumber)
        guard digits.count == 9, digits.allSatisfy(\.isNumber) else { return nil }
        return "CHE\(digits)"
    }

    private func blocker(
        _ code: String,
        _ message: String,
        sourceRef: ObjectRef? = nil
    ) -> SwissVATDeclarationValidationIssue {
        SwissVATDeclarationValidationIssue(
            severity: .blocker,
            code: code,
            message: message,
            sourceRef: sourceRef
        )
    }

    private func firstElement(named localName: String, in element: XMLElement) -> XMLElement? {
        element.children?
            .compactMap { $0 as? XMLElement }
            .first { $0.localName == localName }
    }

    private func textValue(_ localName: String, in element: XMLElement) -> String? {
        firstElement(named: localName, in: element)?.stringValue
    }

    private func escapeXML(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func amountString(_ minorUnits: Int64) -> String {
        let sign = minorUnits < 0 ? "-" : ""
        let absolute = abs(minorUnits)
        return "\(sign)\(absolute / 100).\(String(format: "%02d", absolute % 100))"
    }

    private static func percentString(_ basisPoints: Int) -> String {
        "\(basisPoints / 100).\(String(format: "%02d", basisPoints % 100))"
    }

    private static func parseAmount(_ rawValue: String) -> Int64? {
        let parts = rawValue.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].count == 2 else { return nil }
        let major = String(parts[0])
        let minor = String(parts[1])
        guard let majorValue = Int64(major), let minorValue = Int64(minor) else { return nil }
        let sign: Int64 = majorValue < 0 ? -1 : 1
        return (abs(majorValue) * 100 + minorValue) * sign
    }

    private static func dateString(_ date: Date) -> String {
        dateFormatter().string(from: date)
    }

    private static func date(from rawValue: String) -> Date? {
        dateFormatter().date(from: rawValue)
    }

    private static func dateTimeString(_ date: Date) -> String {
        dateTimeFormatter().string(from: date)
    }

    private static func dateTime(from rawValue: String) -> Date? {
        dateTimeFormatter().date(from: rawValue)
    }

    private static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func dateTimeFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}

private struct DeclarationSummary: Hashable, Sendable {
    let totalConsiderationMinor: Int64
    let exemptTurnoverMinor: Int64
    let outputTurnoverByRate: [OutputTurnover]
}

private struct OutputTurnover: Hashable, Sendable {
    let rateBasisPoints: Int
    let turnoverMinor: Int64
}
