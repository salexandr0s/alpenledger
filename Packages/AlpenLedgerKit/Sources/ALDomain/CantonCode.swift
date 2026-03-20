import Foundation

public struct CantonCode: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    private static let validCantons: Set<String> = [
        "AG", "AI", "AR", "BE", "BL", "BS", "FR", "GE", "GL", "GR",
        "JU", "LU", "NE", "NW", "OW", "SG", "SH", "SO", "SZ", "TG",
        "TI", "UR", "VD", "VS", "ZG", "ZH",
    ]

    public init?(rawValue: String) {
        let upper = rawValue.uppercased()
        guard Self.validCantons.contains(upper) else {
            return nil
        }
        self.rawValue = upper
    }

    public static let zh = CantonCode(rawValue: "ZH")!
}

extension CantonCode: CustomStringConvertible {
    public var description: String { rawValue }
}
