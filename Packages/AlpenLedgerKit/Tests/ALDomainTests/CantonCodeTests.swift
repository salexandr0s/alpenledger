import Foundation
import Testing
@testable import ALDomain

@Test
func cantonCodeAcceptsAll26Cantons() {
    let cantons = [
        "AG", "AI", "AR", "BE", "BL", "BS", "FR", "GE", "GL", "GR",
        "JU", "LU", "NE", "NW", "OW", "SG", "SH", "SO", "SZ", "TG",
        "TI", "UR", "VD", "VS", "ZG", "ZH",
    ]
    for canton in cantons {
        #expect(CantonCode(rawValue: canton) != nil, "Should accept \(canton)")
    }
}

@Test
func cantonCodeNormalizesToUppercase() {
    let code = CantonCode(rawValue: "zh")
    #expect(code?.rawValue == "ZH")
}

@Test
func cantonCodeRejectsInvalid() {
    #expect(CantonCode(rawValue: "") == nil)
    #expect(CantonCode(rawValue: "XX") == nil)
    #expect(CantonCode(rawValue: "Z") == nil)
    #expect(CantonCode(rawValue: "ZHH") == nil)
    #expect(CantonCode(rawValue: "DE") == nil)
}

@Test
func cantonCodeRoundTripsCodable() throws {
    let original = CantonCode(rawValue: "BE")!
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CantonCode.self, from: data)
    #expect(decoded == original)
}

@Test
func cantonCodeEquality() {
    #expect(CantonCode(rawValue: "zh") == CantonCode(rawValue: "ZH"))
}
