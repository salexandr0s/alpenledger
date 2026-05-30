import Foundation
import ALDomain

public enum RulePackValidationSeverity: String, Codable, CaseIterable, Sendable {
    case warning
    case blocker
}

public struct RulePackValidationIssue: Hashable, Codable, Sendable {
    public let severity: RulePackValidationSeverity
    public let code: String
    public let rulePackKey: String
    public let sampleLabel: String?
    public let message: String

    public init(
        severity: RulePackValidationSeverity,
        code: String,
        rulePackKey: String,
        sampleLabel: String? = nil,
        message: String
    ) {
        self.severity = severity
        self.code = code
        self.rulePackKey = rulePackKey
        self.sampleLabel = sampleLabel
        self.message = message
    }
}

public struct RulePackValidationReport: Hashable, Codable, Sendable {
    public let checkedRulePackCount: Int
    public let checkedSampleCount: Int
    public let issues: [RulePackValidationIssue]

    public var isValid: Bool {
        issues.contains { $0.severity == .blocker } == false
    }

    public init(
        checkedRulePackCount: Int,
        checkedSampleCount: Int,
        issues: [RulePackValidationIssue]
    ) {
        self.checkedRulePackCount = checkedRulePackCount
        self.checkedSampleCount = checkedSampleCount
        self.issues = issues
    }
}

public struct PersonalRulePackValidationSample: Sendable {
    public let label: String
    public let context: TaxComputationContext
    public let expectedComputedConceptCodes: Set<String>?

    public init(
        label: String,
        context: TaxComputationContext,
        expectedComputedConceptCodes: Set<String>? = nil
    ) {
        self.label = label
        self.context = context
        self.expectedComputedConceptCodes = expectedComputedConceptCodes
    }
}

public final class RulePackValidationService: Sendable {
    private let registry: RulePackRegistry

    public init(registry: RulePackRegistry) {
        self.registry = registry
    }

    public func validateRegisteredPersonalRulePacks(
        samples: [PersonalRulePackValidationSample]
    ) -> RulePackValidationReport {
        let rulePacks = registry.registeredPersonalTaxRulePacks()
        var issues: [RulePackValidationIssue] = []
        var checkedSampleCount = 0

        for rulePack in rulePacks {
            let key = Self.rulePackKey(rulePack)
            validateMetadata(rulePack, key: key, issues: &issues)

            let matchingSamples = samples.filter { sample in
                let jurisdictionCode = TaxComputationService.jurisdictionCode(
                    entity: sample.context.entity,
                    taxYear: sample.context.taxYear
                )
                return jurisdictionCode == rulePack.jurisdictionCode &&
                    sample.context.taxYear.rulesetVersion == rulePack.rulesetVersion
            }

            if matchingSamples.isEmpty {
                issues.append(RulePackValidationIssue(
                    severity: .blocker,
                    code: "rulepack.sample.missing",
                    rulePackKey: key,
                    message: "Registered rule pack has no validation sample."
                ))
            }

            for sample in matchingSamples {
                checkedSampleCount += 1
                validateSample(sample, rulePack: rulePack, key: key, issues: &issues)
            }
        }

        return RulePackValidationReport(
            checkedRulePackCount: rulePacks.count,
            checkedSampleCount: checkedSampleCount,
            issues: issues
        )
    }

    private func validateMetadata(
        _ rulePack: any PersonalTaxRulePack,
        key: String,
        issues: inout [RulePackValidationIssue]
    ) {
        if rulePack.jurisdictionCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.jurisdiction.empty",
                rulePackKey: key,
                message: "Rule pack jurisdiction code is empty."
            ))
        }
        if rulePack.rulesetVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.version.empty",
                rulePackKey: key,
                message: "Rule pack version is empty."
            ))
        }
    }

    private func validateSample(
        _ sample: PersonalRulePackValidationSample,
        rulePack: any PersonalTaxRulePack,
        key: String,
        issues: inout [RulePackValidationIssue]
    ) {
        if sample.context.entity.id != sample.context.taxYear.entityId {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.sample.entity_mismatch",
                rulePackKey: key,
                sampleLabel: sample.label,
                message: "Sample tax year does not belong to the sample entity."
            ))
        }

        let expectedConcepts = rulePack.expectedConceptCodes(for: sample.context.entity)
        validateConceptCodes(
            expectedConcepts,
            key: key,
            sampleLabel: sample.label,
            codePrefix: "rulepack.expected_concept",
            issues: &issues
        )

        let computedFacts: [ComputedTaxFact]
        do {
            computedFacts = try rulePack.computeFacts(context: sample.context)
        } catch {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.compute.failed",
                rulePackKey: key,
                sampleLabel: sample.label,
                message: error.localizedDescription
            ))
            return
        }

        var seenFactConcepts: Set<String> = []
        var duplicateConcepts: Set<String> = []
        for fact in computedFacts {
            if seenFactConcepts.insert(fact.conceptCode).inserted == false {
                duplicateConcepts.insert(fact.conceptCode)
            }
            validateFact(fact, key: key, sampleLabel: sample.label, issues: &issues)
        }

        for duplicateConcept in duplicateConcepts.sorted() {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.computed_concept.duplicate",
                rulePackKey: key,
                sampleLabel: sample.label,
                message: "Computed concept appears more than once: \(duplicateConcept)."
            ))
        }

        let computedConcepts = Set(computedFacts.map(\.conceptCode))
        for unexpectedConcept in computedConcepts.subtracting(expectedConcepts).sorted() {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.computed_concept.unexpected",
                rulePackKey: key,
                sampleLabel: sample.label,
                message: "Computed concept is not declared as expected: \(unexpectedConcept)."
            ))
        }

        if let expectedComputedConceptCodes = sample.expectedComputedConceptCodes {
            validateConceptCodes(
                expectedComputedConceptCodes,
                key: key,
                sampleLabel: sample.label,
                codePrefix: "rulepack.sample_expected_concept",
                issues: &issues
            )

            for missingConcept in expectedComputedConceptCodes.subtracting(computedConcepts).sorted() {
                issues.append(RulePackValidationIssue(
                    severity: .blocker,
                    code: "rulepack.computed_concept.missing",
                    rulePackKey: key,
                    sampleLabel: sample.label,
                    message: "Validation sample did not compute expected concept: \(missingConcept)."
                ))
            }
            for extraConcept in computedConcepts.subtracting(expectedComputedConceptCodes).sorted() {
                issues.append(RulePackValidationIssue(
                    severity: .blocker,
                    code: "rulepack.computed_concept.extra",
                    rulePackKey: key,
                    sampleLabel: sample.label,
                    message: "Validation sample computed an extra concept: \(extraConcept)."
                ))
            }
        }
    }

    private func validateFact(
        _ fact: ComputedTaxFact,
        key: String,
        sampleLabel: String,
        issues: inout [RulePackValidationIssue]
    ) {
        validateConceptCodes(
            Set([fact.conceptCode]),
            key: key,
            sampleLabel: sampleLabel,
            codePrefix: "rulepack.computed_concept",
            issues: &issues
        )

        if fact.confidence.isNaN || fact.confidence < 0 || fact.confidence > 1 {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.fact.confidence_invalid",
                rulePackKey: key,
                sampleLabel: sampleLabel,
                message: "Computed fact \(fact.conceptCode) has confidence outside 0...1."
            ))
        }

        if fact.status == .overridden {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.fact.override_emitted",
                rulePackKey: key,
                sampleLabel: sampleLabel,
                message: "Rule packs must not emit overridden facts: \(fact.conceptCode)."
            ))
        }

        if fact.provenanceRefs.isEmpty {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.fact.provenance_missing",
                rulePackKey: key,
                sampleLabel: sampleLabel,
                message: "Computed fact \(fact.conceptCode) has no source refs."
            ))
        }

        switch fact.valueType {
        case .money:
            requirePresent(fact.moneyMinor, field: "moneyMinor", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requirePresent(fact.currency, field: "currency", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.textValue, field: "textValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.boolValue, field: "boolValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.dateValue, field: "dateValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
        case .text:
            requirePresent(fact.textValue, field: "textValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.moneyMinor, field: "moneyMinor", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.currency, field: "currency", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.boolValue, field: "boolValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.dateValue, field: "dateValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
        case .bool:
            requirePresent(fact.boolValue, field: "boolValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.moneyMinor, field: "moneyMinor", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.currency, field: "currency", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.textValue, field: "textValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.dateValue, field: "dateValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
        case .date:
            requirePresent(fact.dateValue, field: "dateValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.moneyMinor, field: "moneyMinor", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.currency, field: "currency", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.textValue, field: "textValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
            requireAbsent(fact.boolValue, field: "boolValue", fact: fact, key: key, sampleLabel: sampleLabel, issues: &issues)
        }
    }

    private func validateConceptCodes(
        _ conceptCodes: Set<String>,
        key: String,
        sampleLabel: String?,
        codePrefix: String,
        issues: inout [RulePackValidationIssue]
    ) {
        for conceptCode in conceptCodes where Self.isValidConceptCode(conceptCode) == false {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "\(codePrefix).invalid",
                rulePackKey: key,
                sampleLabel: sampleLabel,
                message: "Invalid concept code: \(conceptCode)."
            ))
        }
    }

    private func requirePresent<T>(
        _ value: T?,
        field: String,
        fact: ComputedTaxFact,
        key: String,
        sampleLabel: String,
        issues: inout [RulePackValidationIssue]
    ) {
        if value == nil {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.fact.field_missing",
                rulePackKey: key,
                sampleLabel: sampleLabel,
                message: "Computed \(fact.valueType.rawValue) fact \(fact.conceptCode) is missing \(field)."
            ))
        }
    }

    private func requireAbsent<T>(
        _ value: T?,
        field: String,
        fact: ComputedTaxFact,
        key: String,
        sampleLabel: String,
        issues: inout [RulePackValidationIssue]
    ) {
        if value != nil {
            issues.append(RulePackValidationIssue(
                severity: .blocker,
                code: "rulepack.fact.field_unexpected",
                rulePackKey: key,
                sampleLabel: sampleLabel,
                message: "Computed \(fact.valueType.rawValue) fact \(fact.conceptCode) should not set \(field)."
            ))
        }
    }

    private static func isValidConceptCode(_ conceptCode: String) -> Bool {
        let parts = conceptCode.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.isEmpty == false else { return false }

        for part in parts {
            guard part.isEmpty == false else { return false }
            for scalar in part.unicodeScalars {
                let value = scalar.value
                let isLowercaseASCII = (97...122).contains(value)
                let isDigit = (48...57).contains(value)
                let isUnderscore = value == 95
                if isLowercaseASCII == false && isDigit == false && isUnderscore == false {
                    return false
                }
            }
        }

        return true
    }

    private static func rulePackKey(_ rulePack: any PersonalTaxRulePack) -> String {
        "\(rulePack.jurisdictionCode):\(rulePack.rulesetVersion)"
    }
}
