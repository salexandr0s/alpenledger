import Foundation
import ALDomain

public struct VATPeriodComputationOptions: Hashable, Sendable {
    public let requireTaxCodeForTransactions: Bool

    public init(requireTaxCodeForTransactions: Bool = true) {
        self.requireTaxCodeForTransactions = requireTaxCodeForTransactions
    }
}

public final class VATPeriodComputationService: Sendable {
    private let codeBook: VATCodeBook

    public init(codeBook: VATCodeBook) {
        self.codeBook = codeBook
    }

    public func reconcile(
        period: VATPeriod,
        transactions: [Transaction],
        options: VATPeriodComputationOptions = VATPeriodComputationOptions()
    ) -> VATReconciliationReport {
        var lines: [VATReconciliationLine] = []
        var issues: [VATReconciliationIssue] = []
        var outputTaxMinor: Int64 = 0
        var inputTaxMinor: Int64 = 0

        for transaction in transactions
        where period.contains(transaction.bookingDate) {
            let sourceRef = ObjectRef(kind: .transaction, id: transaction.id.rawValue)
            guard transaction.currency == period.currency else {
                issues.append(VATReconciliationIssue(
                    severity: .blocker,
                    code: "vat.currency_mismatch",
                    message: "Transaction currency \(transaction.currency.rawValue) does not match VAT period currency \(period.currency.rawValue).",
                    sourceRef: sourceRef
                ))
                continue
            }

            guard let taxCode = transaction.taxCode, taxCode.isEmpty == false else {
                if options.requireTaxCodeForTransactions {
                    issues.append(VATReconciliationIssue(
                        severity: .blocker,
                        code: "vat.missing_tax_code",
                        message: "Transaction has no VAT tax code.",
                        sourceRef: sourceRef
                    ))
                }
                continue
            }

            guard let vatCode = codeBook.code(taxCode, on: transaction.bookingDate) else {
                issues.append(VATReconciliationIssue(
                    severity: .blocker,
                    code: "vat.unknown_tax_code",
                    message: "VAT tax code \(taxCode) is not valid for the transaction date.",
                    sourceRef: sourceRef
                ))
                continue
            }

            appendSignWarningIfNeeded(
                vatCode: vatCode,
                transaction: transaction,
                sourceRef: sourceRef,
                issues: &issues
            )

            let amounts = computeAmounts(
                sourceAmountMinor: transaction.amountMinor,
                rateBasisPoints: vatCode.rateBasisPoints,
                basis: vatCode.defaultAmountBasis,
                treatment: vatCode.treatment
            )

            let line = VATReconciliationLine(
                transactionId: transaction.id,
                taxCode: vatCode.code,
                treatment: vatCode.treatment,
                sourceAmountMinor: transaction.amountMinor,
                taxableBaseMinor: amounts.taxableBaseMinor,
                vatAmountMinor: amounts.vatAmountMinor,
                currency: transaction.currency
            )
            lines.append(line)

            switch vatCode.treatment {
            case .outputTax:
                outputTaxMinor += line.vatAmountMinor
            case .inputTax:
                inputTaxMinor += line.vatAmountMinor
            case .exempt, .outsideScope:
                break
            }
        }

        return VATReconciliationReport(
            period: period,
            jurisdictionCode: codeBook.jurisdictionCode,
            rulesetVersion: codeBook.rulesetVersion,
            lines: lines,
            issues: issues,
            outputTaxMinor: outputTaxMinor,
            inputTaxMinor: inputTaxMinor,
            netTaxPayableMinor: outputTaxMinor - inputTaxMinor
        )
    }

    private func appendSignWarningIfNeeded(
        vatCode: VATCode,
        transaction: Transaction,
        sourceRef: ObjectRef,
        issues: inout [VATReconciliationIssue]
    ) {
        switch vatCode.treatment {
        case .outputTax where transaction.amountMinor < 0:
            issues.append(VATReconciliationIssue(
                severity: .warning,
                code: "vat.output_code_on_debit",
                message: "Output VAT code is mapped to a debit transaction.",
                sourceRef: sourceRef
            ))
        case .inputTax where transaction.amountMinor > 0:
            issues.append(VATReconciliationIssue(
                severity: .warning,
                code: "vat.input_code_on_credit",
                message: "Input VAT code is mapped to a credit transaction.",
                sourceRef: sourceRef
            ))
        default:
            break
        }
    }

    private func computeAmounts(
        sourceAmountMinor: Int64,
        rateBasisPoints: Int,
        basis: VATAmountBasis,
        treatment: VATCodeTreatment
    ) -> (taxableBaseMinor: Int64, vatAmountMinor: Int64) {
        guard treatment != .outsideScope else {
            return (0, 0)
        }
        let absoluteAmount = abs(sourceAmountMinor)
        guard rateBasisPoints > 0 else {
            return (absoluteAmount, 0)
        }

        let vatAmount: Int64
        switch basis {
        case .grossInclusive:
            vatAmount = roundedMinorUnits(
                Decimal(absoluteAmount) * Decimal(rateBasisPoints) / Decimal(10_000 + rateBasisPoints)
            )
        case .netExclusive:
            vatAmount = roundedMinorUnits(
                Decimal(absoluteAmount) * Decimal(rateBasisPoints) / Decimal(10_000)
            )
        }

        let taxableBase: Int64
        switch basis {
        case .grossInclusive:
            taxableBase = absoluteAmount - vatAmount
        case .netExclusive:
            taxableBase = absoluteAmount
        }
        return (taxableBase, vatAmount)
    }

    private func roundedMinorUnits(_ value: Decimal) -> Int64 {
        var value = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}
