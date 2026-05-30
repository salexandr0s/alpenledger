import Foundation

public enum VATCodeTreatment: String, Codable, CaseIterable, Sendable {
    case outputTax
    case inputTax
    case exempt
    case outsideScope
}

public enum VATAmountBasis: String, Codable, CaseIterable, Sendable {
    case grossInclusive
    case netExclusive
}

public struct VATCode: Hashable, Codable, Sendable {
    public let code: String
    public let displayName: String
    public let rateBasisPoints: Int
    public let treatment: VATCodeTreatment
    public let defaultAmountBasis: VATAmountBasis
    public let effectiveFrom: Date
    public let effectiveTo: Date?

    public init(
        code: String,
        displayName: String,
        rateBasisPoints: Int,
        treatment: VATCodeTreatment,
        defaultAmountBasis: VATAmountBasis = .grossInclusive,
        effectiveFrom: Date,
        effectiveTo: Date? = nil
    ) {
        self.code = code
        self.displayName = displayName
        self.rateBasisPoints = max(0, rateBasisPoints)
        self.treatment = treatment
        self.defaultAmountBasis = defaultAmountBasis
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
    }

    public func isEffective(on date: Date) -> Bool {
        effectiveFrom <= date && effectiveTo.map { date <= $0 } != false
    }
}

public struct VATCodeBook: Hashable, Codable, Sendable {
    public let jurisdictionCode: String
    public let rulesetVersion: String
    public let codes: [VATCode]

    public init(jurisdictionCode: String, rulesetVersion: String, codes: [VATCode]) {
        self.jurisdictionCode = jurisdictionCode
        self.rulesetVersion = rulesetVersion
        self.codes = codes
    }

    public func code(_ code: String, on date: Date) -> VATCode? {
        codes
            .filter { $0.code == code && $0.isEffective(on: date) }
            .sorted { $0.effectiveFrom > $1.effectiveFrom }
            .first
    }
}

public enum VATPeriodStatus: String, Codable, CaseIterable, Sendable {
    case open
    case locked
}

public struct VATPeriod: Hashable, Codable, Sendable {
    public let id: VATPeriodID
    public let entityId: LegalEntityID
    public let periodStart: Date
    public let periodEnd: Date
    public let currency: CurrencyCode
    public var status: VATPeriodStatus

    public init(
        id: VATPeriodID = VATPeriodID(),
        entityId: LegalEntityID,
        periodStart: Date,
        periodEnd: Date,
        currency: CurrencyCode,
        status: VATPeriodStatus = .open
    ) {
        self.id = id
        self.entityId = entityId
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.currency = currency
        self.status = status
    }

    public func contains(_ date: Date) -> Bool {
        periodStart <= date && date <= periodEnd
    }
}

public enum VATReconciliationIssueSeverity: String, Codable, CaseIterable, Sendable {
    case warning
    case blocker
}

public struct VATReconciliationIssue: Hashable, Codable, Sendable {
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

public struct VATReconciliationLine: Hashable, Codable, Sendable {
    public let transactionId: TransactionID
    public let taxCode: String
    public let treatment: VATCodeTreatment
    public let sourceAmountMinor: Int64
    public let taxableBaseMinor: Int64
    public let vatAmountMinor: Int64
    public let currency: CurrencyCode

    public init(
        transactionId: TransactionID,
        taxCode: String,
        treatment: VATCodeTreatment,
        sourceAmountMinor: Int64,
        taxableBaseMinor: Int64,
        vatAmountMinor: Int64,
        currency: CurrencyCode
    ) {
        self.transactionId = transactionId
        self.taxCode = taxCode
        self.treatment = treatment
        self.sourceAmountMinor = sourceAmountMinor
        self.taxableBaseMinor = taxableBaseMinor
        self.vatAmountMinor = vatAmountMinor
        self.currency = currency
    }
}

public struct VATReconciliationReport: Hashable, Codable, Sendable {
    public let period: VATPeriod
    public let jurisdictionCode: String
    public let rulesetVersion: String
    public let lines: [VATReconciliationLine]
    public let issues: [VATReconciliationIssue]
    public let outputTaxMinor: Int64
    public let inputTaxMinor: Int64
    public let netTaxPayableMinor: Int64

    public init(
        period: VATPeriod,
        jurisdictionCode: String,
        rulesetVersion: String,
        lines: [VATReconciliationLine],
        issues: [VATReconciliationIssue],
        outputTaxMinor: Int64,
        inputTaxMinor: Int64,
        netTaxPayableMinor: Int64
    ) {
        self.period = period
        self.jurisdictionCode = jurisdictionCode
        self.rulesetVersion = rulesetVersion
        self.lines = lines
        self.issues = issues
        self.outputTaxMinor = outputTaxMinor
        self.inputTaxMinor = inputTaxMinor
        self.netTaxPayableMinor = netTaxPayableMinor
    }

    public var blockerCount: Int {
        issues.filter { $0.severity == .blocker }.count
    }
}
