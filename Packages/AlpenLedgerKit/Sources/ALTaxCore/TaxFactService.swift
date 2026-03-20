import Foundation
import ALDomain
import ALStorage

public final class TaxFactService: Sendable {
    private let repository: any TaxFactRepository

    public init(storage: WorkspaceStorage) {
        self.repository = storage.taxFactRepository
    }

    public func listTaxFacts(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        currentOnly: Bool = true
    ) throws -> [TaxFact] {
        try repository.fetchTaxFacts(entityId: entityId, taxYearId: taxYearId, currentOnly: currentOnly)
    }

    @discardableResult
    public func syncFacts(
        _ computedFacts: [ComputedTaxFact],
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        jurisdictionCode: String,
        rulesetVersion: String,
        now: Date
    ) throws -> [TaxFact] {
        let desiredFactsByFingerprint = Dictionary(
            computedFacts.map { computed in
                (
                    Self.fingerprint(
                        entityId: entityId,
                        taxYearId: taxYearId,
                        jurisdictionCode: jurisdictionCode,
                        conceptCode: computed.conceptCode
                    ),
                    computed
                )
            },
            uniquingKeysWith: { _, latest in latest }
        )

        var existingCurrentFacts = Dictionary(
            uniqueKeysWithValues: try repository
                .fetchTaxFacts(entityId: entityId, taxYearId: taxYearId, currentOnly: true)
                .map { ($0.fingerprint, $0) }
        )

        var currentFacts: [TaxFact] = []
        for fingerprint in desiredFactsByFingerprint.keys.sorted() {
            guard let computed = desiredFactsByFingerprint[fingerprint] else {
                continue
            }

            if let existing = existingCurrentFacts.removeValue(forKey: fingerprint) {
                if Self.matches(existing: existing, computed: computed, jurisdictionCode: jurisdictionCode, rulesetVersion: rulesetVersion) {
                    currentFacts.append(existing)
                    continue
                }

                var superseded = existing
                superseded.isCurrent = false
                superseded.updatedAt = now
                try repository.saveTaxFact(superseded)

                let replacement = TaxFact(
                    fingerprint: fingerprint,
                    entityId: entityId,
                    taxYearId: taxYearId,
                    jurisdictionCode: jurisdictionCode,
                    conceptCode: computed.conceptCode,
                    valueType: computed.valueType,
                    moneyMinor: computed.moneyMinor,
                    textValue: computed.textValue,
                    boolValue: computed.boolValue,
                    dateValue: computed.dateValue,
                    currency: computed.currency,
                    status: computed.status,
                    rulesetVersion: rulesetVersion,
                    provenanceRefs: computed.provenanceRefs,
                    confidence: computed.confidence,
                    supersedesFactId: existing.id,
                    isCurrent: true,
                    createdAt: now,
                    updatedAt: now
                )
                try repository.saveTaxFact(replacement)
                currentFacts.append(replacement)
            } else {
                let fact = TaxFact(
                    fingerprint: fingerprint,
                    entityId: entityId,
                    taxYearId: taxYearId,
                    jurisdictionCode: jurisdictionCode,
                    conceptCode: computed.conceptCode,
                    valueType: computed.valueType,
                    moneyMinor: computed.moneyMinor,
                    textValue: computed.textValue,
                    boolValue: computed.boolValue,
                    dateValue: computed.dateValue,
                    currency: computed.currency,
                    status: computed.status,
                    rulesetVersion: rulesetVersion,
                    provenanceRefs: computed.provenanceRefs,
                    confidence: computed.confidence,
                    createdAt: now,
                    updatedAt: now
                )
                try repository.saveTaxFact(fact)
                currentFacts.append(fact)
            }
        }

        for obsolete in existingCurrentFacts.values {
            var retired = obsolete
            retired.isCurrent = false
            retired.updatedAt = now
            try repository.saveTaxFact(retired)
        }

        return currentFacts.sorted { $0.conceptCode < $1.conceptCode }
    }

    public static func fingerprint(
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        jurisdictionCode: String,
        conceptCode: String
    ) -> String {
        [
            jurisdictionCode,
            entityId.description,
            taxYearId.description,
            conceptCode,
        ].joined(separator: "|")
    }

    private static func matches(
        existing: TaxFact,
        computed: ComputedTaxFact,
        jurisdictionCode: String,
        rulesetVersion: String
    ) -> Bool {
        existing.jurisdictionCode == jurisdictionCode &&
            existing.conceptCode == computed.conceptCode &&
            existing.valueType == computed.valueType &&
            existing.moneyMinor == computed.moneyMinor &&
            existing.textValue == computed.textValue &&
            existing.boolValue == computed.boolValue &&
            existing.dateValue == computed.dateValue &&
            existing.currency == computed.currency &&
            existing.status == computed.status &&
            existing.rulesetVersion == rulesetVersion &&
            existing.provenanceRefs == computed.provenanceRefs &&
            existing.confidence == computed.confidence &&
            existing.isCurrent
    }
}
