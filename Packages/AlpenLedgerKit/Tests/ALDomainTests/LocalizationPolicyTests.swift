import Foundation
import Testing
@testable import ALDomain

@Test
func localizationPolicyKeepsPilotLanguageClaimsConservative() {
    #expect(LocalizationPolicy.defaultLanguage == .english)
    #expect(LocalizationPolicy.pilotLanguageReadiness.map(\.language) == [.english, .german, .french])
    #expect(LocalizationPolicy.readiness(for: .english).status == .releaseReady)
    #expect(LocalizationPolicy.readiness(for: .german).status == .planned)
    #expect(LocalizationPolicy.readiness(for: .french).status == .planned)
    #expect(LocalizationPolicy.canClaimReleaseAvailability(for: .english))
    #expect(LocalizationPolicy.canClaimReleaseAvailability(for: .german) == false)
    #expect(LocalizationPolicy.canClaimReleaseAvailability(for: .french) == false)
}
