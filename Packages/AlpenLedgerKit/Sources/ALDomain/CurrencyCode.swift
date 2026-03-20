import Foundation

public struct CurrencyCode: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let upper = rawValue.uppercased()
        guard upper.count == 3,
              upper.allSatisfy({ $0.isASCII && $0.isUppercase })
        else {
            return nil
        }
        self.rawValue = upper
    }

    public static let chf = CurrencyCode(rawValue: "CHF")!
    public static let eur = CurrencyCode(rawValue: "EUR")!
    public static let usd = CurrencyCode(rawValue: "USD")!
}

extension CurrencyCode: CustomStringConvertible {
    public var description: String { rawValue }
}
