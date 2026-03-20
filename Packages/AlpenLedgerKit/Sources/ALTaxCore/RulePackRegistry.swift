import Foundation
import ALDomain

public struct TaxComputationContext: Sendable {
    public let entity: LegalEntity
    public let taxYear: TaxYear
    public let documents: [Document]
    public let financialAccounts: [FinancialAccount]
    public let transactions: [Transaction]

    public init(
        entity: LegalEntity,
        taxYear: TaxYear,
        documents: [Document],
        financialAccounts: [FinancialAccount],
        transactions: [Transaction]
    ) {
        self.entity = entity
        self.taxYear = taxYear
        self.documents = documents
        self.financialAccounts = financialAccounts
        self.transactions = transactions
    }
}

public struct ComputedTaxFact: Hashable, Sendable {
    public let conceptCode: String
    public let valueType: TaxFactValueType
    public let moneyMinor: Int64?
    public let textValue: String?
    public let boolValue: Bool?
    public let dateValue: Date?
    public let currency: CurrencyCode?
    public let status: TaxFactStatus
    public let provenanceRefs: [ObjectRef]
    public let confidence: Double

    public init(
        conceptCode: String,
        valueType: TaxFactValueType,
        moneyMinor: Int64? = nil,
        textValue: String? = nil,
        boolValue: Bool? = nil,
        dateValue: Date? = nil,
        currency: CurrencyCode? = nil,
        status: TaxFactStatus,
        provenanceRefs: [ObjectRef] = [],
        confidence: Double = 1.0
    ) {
        self.conceptCode = conceptCode
        self.valueType = valueType
        self.moneyMinor = moneyMinor
        self.textValue = textValue
        self.boolValue = boolValue
        self.dateValue = dateValue
        self.currency = currency
        self.status = status
        self.provenanceRefs = provenanceRefs
        self.confidence = confidence
    }
}

public protocol PersonalTaxRulePack: Sendable {
    var jurisdictionCode: String { get }
    var rulesetVersion: String { get }

    func computeFacts(context: TaxComputationContext) throws -> [ComputedTaxFact]
    func expectedConceptCodes(for entity: LegalEntity) -> Set<String>
}

private struct RulePackKey: Hashable {
    let jurisdictionCode: String
    let rulesetVersion: String
}

public final class RulePackRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var personalRulePacks: [RulePackKey: any PersonalTaxRulePack] = [:]

    public init() {}

    public func registerPersonalTaxRulePack(_ rulePack: any PersonalTaxRulePack) {
        lock.lock()
        defer { lock.unlock() }
        personalRulePacks[
            RulePackKey(
                jurisdictionCode: rulePack.jurisdictionCode,
                rulesetVersion: rulePack.rulesetVersion
            )
        ] = rulePack
    }

    public func personalTaxRulePack(
        jurisdictionCode: String,
        rulesetVersion: String
    ) -> (any PersonalTaxRulePack)? {
        lock.lock()
        defer { lock.unlock() }
        return personalRulePacks[RulePackKey(jurisdictionCode: jurisdictionCode, rulesetVersion: rulesetVersion)]
    }
}
