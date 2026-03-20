import Foundation

public struct Money: Hashable, Codable, Sendable {
    public let minorUnits: Int64
    public let currency: CurrencyCode

    public init(minorUnits: Int64, currency: CurrencyCode) {
        self.minorUnits = minorUnits
        self.currency = currency
    }

    public init(majorUnits: Decimal, currency: CurrencyCode) {
        var scaled = majorUnits * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .bankers)
        self.minorUnits = NSDecimalNumber(decimal: rounded).int64Value
        self.currency = currency
    }

    public var majorUnits: Decimal {
        Decimal(minorUnits) / 100
    }

    public var isZero: Bool { minorUnits == 0 }

    public var abs: Money {
        Money(minorUnits: Swift.abs(minorUnits), currency: currency)
    }

    public func adding(_ other: Money) throws -> Money {
        guard currency == other.currency else {
            throw DomainError.currencyMismatch(expected: currency.rawValue, actual: other.currency.rawValue)
        }
        return Money(minorUnits: minorUnits + other.minorUnits, currency: currency)
    }

    public func subtracting(_ other: Money) throws -> Money {
        guard currency == other.currency else {
            throw DomainError.currencyMismatch(expected: currency.rawValue, actual: other.currency.rawValue)
        }
        return Money(minorUnits: minorUnits - other.minorUnits, currency: currency)
    }

    public func negated() -> Money {
        Money(minorUnits: -minorUnits, currency: currency)
    }

    public static func zero(_ currency: CurrencyCode) -> Money {
        Money(minorUnits: 0, currency: currency)
    }
}

extension Money: Comparable {
    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Cannot compare Money with different currencies")
        return lhs.minorUnits < rhs.minorUnits
    }
}
