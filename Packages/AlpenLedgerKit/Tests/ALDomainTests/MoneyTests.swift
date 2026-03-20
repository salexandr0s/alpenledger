import Foundation
import Testing
@testable import ALDomain

@Test
func moneyAdditionPreservesCurrency() throws {
    let lhs = Money(minorUnits: 2500, currency: .chf)
    let rhs = Money(minorUnits: 4250, currency: .chf)

    let result = try lhs.adding(rhs)
    #expect(result.minorUnits == 6750)
    #expect(result.currency == .chf)
}

@Test
func moneyAdditionRejectsCurrencyMismatch() {
    let lhs = Money(minorUnits: 2500, currency: .chf)
    let rhs = Money(minorUnits: 4250, currency: .eur)

    #expect(throws: DomainError.self) {
        _ = try lhs.adding(rhs)
    }
}

@Test
func moneySubtraction() throws {
    let lhs = Money(minorUnits: 5000, currency: .chf)
    let rhs = Money(minorUnits: 2000, currency: .chf)
    let result = try lhs.subtracting(rhs)
    #expect(result.minorUnits == 3000)
}

@Test
func moneySubtractionRejectsMismatch() {
    let lhs = Money(minorUnits: 5000, currency: .chf)
    let rhs = Money(minorUnits: 2000, currency: .eur)
    #expect(throws: DomainError.self) {
        _ = try lhs.subtracting(rhs)
    }
}

@Test
func moneyNegation() {
    let m = Money(minorUnits: 1500, currency: .chf)
    let neg = m.negated()
    #expect(neg.minorUnits == -1500)
    #expect(neg.currency == .chf)
}

@Test
func moneyIsZero() {
    #expect(Money.zero(.chf).isZero)
    #expect(Money(minorUnits: 1, currency: .chf).isZero == false)
}

@Test
func moneyAbs() {
    let negative = Money(minorUnits: -1500, currency: .chf)
    #expect(negative.abs.minorUnits == 1500)
}

@Test
func moneyComparable() {
    let small = Money(minorUnits: 100, currency: .chf)
    let large = Money(minorUnits: 200, currency: .chf)
    #expect(small < large)
    #expect(large > small)
    #expect(small <= small)
}

@Test
func moneyMajorUnitsConversion() {
    let m = Money(minorUnits: 1999, currency: .chf)
    #expect(m.majorUnits == Decimal(string: "19.99"))
}

@Test
func moneyFromMajorUnitsDecimalPrecision() {
    let m = Money(majorUnits: Decimal(string: "19.99")!, currency: .chf)
    #expect(m.minorUnits == 1999)
}

@Test
func moneyFromMajorUnitsRounding() {
    let m = Money(majorUnits: Decimal(string: "19.995")!, currency: .chf)
    #expect(m.minorUnits == 2000)
}
