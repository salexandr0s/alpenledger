import Foundation

public func accessibilitySlug(_ value: String) -> String {
    let lowered = value.lowercased()
    let allowed = CharacterSet.alphanumerics
    let scalars = lowered.unicodeScalars.map { scalar -> Character in
        allowed.contains(scalar) ? Character(String(scalar)) : "-"
    }
    let collapsed = String(scalars)
        .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return collapsed.isEmpty ? "item" : collapsed
}
