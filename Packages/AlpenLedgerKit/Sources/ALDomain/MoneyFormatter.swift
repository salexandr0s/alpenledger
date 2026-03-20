import Foundation

public struct MoneyFormatter: Sendable {
    public init() {}

    public func format(_ money: Money) -> String {
        format(minorUnits: money.minorUnits, currency: money.currency)
    }

    public func format(minorUnits: Int64, currency: CurrencyCode) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let value = Decimal(minorUnits) / 100
        let formatted = formatter.string(from: value as NSDecimalNumber) ?? "\(value)"
        return "\(formatted) \(currency.rawValue)"
    }
}
