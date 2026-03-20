import Foundation
import ALDomain
import ALTaxCore

public protocol PersonalTaxAdapter: PersonalTaxRulePack {}
public protocol VATAdapter: Sendable {}
public protocol BusinessTaxAdapter: Sendable {}

public struct ZurichPersonalTaxAdapter2026: PersonalTaxAdapter {
    public let jurisdictionCode = "CH-ZH"
    public let rulesetVersion = "zh-personal-2026-v1"

    public init() {}

    public func computeFacts(context: TaxComputationContext) throws -> [ComputedTaxFact] {
        switch context.entity.kind {
        case .naturalPerson:
            return documentFacts(context: context)
        case .soleProprietor:
            return selfEmploymentFacts(context: context)
        case .corporation:
            return []
        }
    }

    public func expectedConceptCodes(for entity: LegalEntity) -> Set<String> {
        switch entity.kind {
        case .naturalPerson:
            return [
                "personal.income.salary_gross",
                "personal.deduction.health_insurance_premiums",
                "personal.deduction.pillar3a_contributions",
                "personal.readiness.has_salary_certificate",
                "personal.readiness.has_health_insurance_certificate",
                "personal.readiness.has_pillar3a_certificate",
            ]
        case .soleProprietor:
            return [
                "personal.self_employment.revenue_gross",
                "personal.self_employment.expense_total",
                "personal.self_employment.net_profit",
            ]
        case .corporation:
            return []
        }
    }

    private func documentFacts(context: TaxComputationContext) -> [ComputedTaxFact] {
        let matchingDocuments = context.documents.filter { document in
            matches(entity: context.entity, taxYear: context.taxYear, document: document)
        }

        let factsByConcept = matchingDocuments.reduce(into: [String: ComputedTaxFact]()) { result, document in
            guard let payload = parseDocument(document) else {
                return
            }

            let documentRef = ObjectRef(kind: .document, id: document.id.rawValue)
            result[payload.moneyConceptCode] = ComputedTaxFact(
                conceptCode: payload.moneyConceptCode,
                valueType: .money,
                moneyMinor: payload.moneyMinor,
                currency: payload.currency,
                status: .observed,
                provenanceRefs: [documentRef]
            )
            result[payload.readinessConceptCode] = ComputedTaxFact(
                conceptCode: payload.readinessConceptCode,
                valueType: .bool,
                boolValue: true,
                status: .observed,
                provenanceRefs: [documentRef]
            )
        }

        return factsByConcept.values.sorted { $0.conceptCode < $1.conceptCode }
    }

    private func selfEmploymentFacts(context: TaxComputationContext) -> [ComputedTaxFact] {
        let includedTransactions = context.transactions
            .filter { transaction in
                transaction.originKind == .imported &&
                    context.taxYear.periodStart <= transaction.bookingDate &&
                    transaction.bookingDate <= context.taxYear.periodEnd
            }

        guard includedTransactions.isEmpty == false else {
            return []
        }

        let revenueMinor = includedTransactions
            .filter { $0.amountMinor > 0 }
            .reduce(into: Int64.zero) { partialResult, transaction in
                partialResult += transaction.amountMinor
            }
        let expenseMinor = includedTransactions
            .filter { $0.amountMinor < 0 }
            .reduce(into: Int64.zero) { partialResult, transaction in
                partialResult += abs(transaction.amountMinor)
            }
        let netProfitMinor = revenueMinor - expenseMinor
        let provenanceRefs = includedTransactions.map { ObjectRef(kind: .transaction, id: $0.id.rawValue) }
        let currency = includedTransactions.first?.currency ?? .chf

        return [
            ComputedTaxFact(
                conceptCode: "personal.self_employment.expense_total",
                valueType: .money,
                moneyMinor: expenseMinor,
                currency: currency,
                status: .derived,
                provenanceRefs: provenanceRefs
            ),
            ComputedTaxFact(
                conceptCode: "personal.self_employment.net_profit",
                valueType: .money,
                moneyMinor: netProfitMinor,
                currency: currency,
                status: .derived,
                provenanceRefs: provenanceRefs
            ),
            ComputedTaxFact(
                conceptCode: "personal.self_employment.revenue_gross",
                valueType: .money,
                moneyMinor: revenueMinor,
                currency: currency,
                status: .derived,
                provenanceRefs: provenanceRefs
            ),
        ]
    }

    private func matches(entity: LegalEntity, taxYear: TaxYear, document: Document) -> Bool {
        guard supportedDocumentTypes.contains(document.documentType) else {
            return false
        }
        if let detectedEntityId = document.detectedEntityId, detectedEntityId != entity.id {
            return false
        }
        if let detectedTaxYearId = document.detectedTaxYearId {
            return detectedTaxYearId == taxYear.id
        }
        if let issueDate = document.issueDate {
            return taxYear.periodStart <= issueDate && issueDate <= taxYear.periodEnd
        }
        return false
    }

    private func parseDocument(_ document: Document) -> ParsedTaxDocument? {
        guard let extractedText = document.extractedText else {
            return nil
        }
        let values = Dictionary(
            extractedText
                .components(separatedBy: .newlines)
                .compactMap { line -> (String, String)? in
                    let components = line.split(separator: ":", maxSplits: 1).map(String.init)
                    guard components.count == 2 else {
                        return nil
                    }
                    return (
                        components[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                        components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                },
            uniquingKeysWith: { current, _ in current }
        )

        switch document.documentType {
        case .salaryCertificate:
            guard
                let moneyMinor = values["salary_gross_minor"].flatMap(Int64.init),
                let currency = values["currency"].flatMap({ CurrencyCode(rawValue: $0) })
            else {
                return nil
            }
            return ParsedTaxDocument(
                moneyConceptCode: "personal.income.salary_gross",
                readinessConceptCode: "personal.readiness.has_salary_certificate",
                moneyMinor: moneyMinor,
                currency: currency
            )
        case .healthInsuranceCertificate:
            guard
                let moneyMinor = values["health_insurance_premiums_minor"].flatMap(Int64.init),
                let currency = values["currency"].flatMap({ CurrencyCode(rawValue: $0) })
            else {
                return nil
            }
            return ParsedTaxDocument(
                moneyConceptCode: "personal.deduction.health_insurance_premiums",
                readinessConceptCode: "personal.readiness.has_health_insurance_certificate",
                moneyMinor: moneyMinor,
                currency: currency
            )
        case .pillar3aCertificate:
            guard
                let moneyMinor = values["pillar3a_contributions_minor"].flatMap(Int64.init),
                let currency = values["currency"].flatMap({ CurrencyCode(rawValue: $0) })
            else {
                return nil
            }
            return ParsedTaxDocument(
                moneyConceptCode: "personal.deduction.pillar3a_contributions",
                readinessConceptCode: "personal.readiness.has_pillar3a_certificate",
                moneyMinor: moneyMinor,
                currency: currency
            )
        default:
            return nil
        }
    }

    private var supportedDocumentTypes: Set<DocumentType> {
        [
            .salaryCertificate,
            .healthInsuranceCertificate,
            .pillar3aCertificate,
        ]
    }
}

private struct ParsedTaxDocument {
    let moneyConceptCode: String
    let readinessConceptCode: String
    let moneyMinor: Int64
    let currency: CurrencyCode
}
