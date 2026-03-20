import Foundation
import Testing
@testable import ALDomain

@Test
func moneyFormatterBasic() {
    let formatter = MoneyFormatter()
    let result = formatter.format(Money(minorUnits: 123456, currency: .chf))
    #expect(result == "1\u{2019}234.56 CHF")
}

@Test
func moneyFormatterTrailingZeros() {
    let formatter = MoneyFormatter()
    let result = formatter.format(Money(minorUnits: 12300, currency: .chf))
    #expect(result == "123.00 CHF")
}

@Test
func moneyFormatterNegative() {
    let formatter = MoneyFormatter()
    let result = formatter.format(Money(minorUnits: -5000, currency: .eur))
    #expect(result == "-50.00 EUR")
}

@Test
func moneyFormatterZero() {
    let formatter = MoneyFormatter()
    let result = formatter.format(Money(minorUnits: 0, currency: .usd))
    #expect(result == "0.00 USD")
}
