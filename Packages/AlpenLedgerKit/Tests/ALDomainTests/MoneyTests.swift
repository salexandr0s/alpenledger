import Testing
@testable import ALDomain

@Test
func moneyAdditionPreservesCurrency() throws {
    let lhs = Money(minorUnits: 2500, currency: "CHF")
    let rhs = Money(minorUnits: 4250, currency: "CHF")

    let result = try lhs.adding(rhs)
    #expect(result.minorUnits == 6750)
    #expect(result.currency == "CHF")
}

@Test
func moneyAdditionRejectsCurrencyMismatch() {
    let lhs = Money(minorUnits: 2500, currency: "CHF")
    let rhs = Money(minorUnits: 4250, currency: "EUR")

    #expect(throws: DomainError.self) {
        _ = try lhs.adding(rhs)
    }
}
