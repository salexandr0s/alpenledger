import Foundation
import ALDomain

public enum SwissVATCodeBook {
    public static func current2026() -> VATCodeBook {
        VATCodeBook(
            jurisdictionCode: "CH",
            rulesetVersion: "ch-vat-2026",
            codes: [
                VATCode(
                    code: "CH-VAT-OUTPUT-STD",
                    displayName: "Output VAT standard rate 8.1%",
                    rateBasisPoints: 810,
                    treatment: .outputTax,
                    effectiveFrom: effectiveDate("2024-01-01")
                ),
                VATCode(
                    code: "CH-VAT-OUTPUT-RED",
                    displayName: "Output VAT reduced rate 2.6%",
                    rateBasisPoints: 260,
                    treatment: .outputTax,
                    effectiveFrom: effectiveDate("2024-01-01")
                ),
                VATCode(
                    code: "CH-VAT-OUTPUT-ACC",
                    displayName: "Output VAT accommodation rate 3.8%",
                    rateBasisPoints: 380,
                    treatment: .outputTax,
                    effectiveFrom: effectiveDate("2024-01-01")
                ),
                VATCode(
                    code: "CH-VAT-INPUT-STD",
                    displayName: "Input VAT standard rate 8.1%",
                    rateBasisPoints: 810,
                    treatment: .inputTax,
                    effectiveFrom: effectiveDate("2024-01-01")
                ),
                VATCode(
                    code: "CH-VAT-INPUT-RED",
                    displayName: "Input VAT reduced rate 2.6%",
                    rateBasisPoints: 260,
                    treatment: .inputTax,
                    effectiveFrom: effectiveDate("2024-01-01")
                ),
                VATCode(
                    code: "CH-VAT-INPUT-ACC",
                    displayName: "Input VAT accommodation rate 3.8%",
                    rateBasisPoints: 380,
                    treatment: .inputTax,
                    effectiveFrom: effectiveDate("2024-01-01")
                ),
                VATCode(
                    code: "CH-VAT-EXEMPT",
                    displayName: "VAT exempt",
                    rateBasisPoints: 0,
                    treatment: .exempt,
                    effectiveFrom: effectiveDate("2024-01-01")
                ),
                VATCode(
                    code: "CH-VAT-OUTSIDE",
                    displayName: "Outside Swiss VAT scope",
                    rateBasisPoints: 0,
                    treatment: .outsideScope,
                    effectiveFrom: effectiveDate("2024-01-01")
                ),
            ]
        )
    }

    private static func effectiveDate(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)!
    }
}
