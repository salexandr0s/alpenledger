import Foundation
import Testing
@testable import ALDomain

@Test
func currencyCodeAcceptsValidISO4217() {
    #expect(CurrencyCode(rawValue: "CHF") != nil)
    #expect(CurrencyCode(rawValue: "eur") != nil)
    #expect(CurrencyCode(rawValue: "Usd") != nil)
}

@Test
func currencyCodeNormalizesToUppercase() {
    let code = CurrencyCode(rawValue: "chf")
    #expect(code?.rawValue == "CHF")
}

@Test
func currencyCodeRejectsInvalid() {
    #expect(CurrencyCode(rawValue: "") == nil)
    #expect(CurrencyCode(rawValue: "CH") == nil)
    #expect(CurrencyCode(rawValue: "CHFF") == nil)
    #expect(CurrencyCode(rawValue: "123") == nil)
    #expect(CurrencyCode(rawValue: "C F") == nil)
}

@Test
func currencyCodeStaticConstants() {
    #expect(CurrencyCode.chf.rawValue == "CHF")
    #expect(CurrencyCode.eur.rawValue == "EUR")
    #expect(CurrencyCode.usd.rawValue == "USD")
}

@Test
func currencyCodeRoundTripsCodable() throws {
    let original = CurrencyCode.chf
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(CurrencyCode.self, from: data)
    #expect(decoded == original)
}

@Test
func currencyCodeEquality() {
    #expect(CurrencyCode(rawValue: "chf") == CurrencyCode(rawValue: "CHF"))
}
