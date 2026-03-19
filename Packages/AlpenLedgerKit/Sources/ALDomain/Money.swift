import Foundation

public struct Money: Hashable, Codable, Sendable {
    public let minorUnits: Int64
    public let currency: String

    public init(minorUnits: Int64, currency: String) {
        self.minorUnits = minorUnits
        self.currency = currency.uppercased()
    }

    public func adding(_ other: Money) throws -> Money {
        guard currency == other.currency else {
            throw DomainError.currencyMismatch(expected: currency, actual: other.currency)
        }
        return Money(minorUnits: minorUnits + other.minorUnits, currency: currency)
    }
}
