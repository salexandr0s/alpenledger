import Foundation

public enum AlpenLedgerLanguage: String, CaseIterable, Codable, Hashable, Sendable {
    case english = "en"
    case german = "de"
    case french = "fr"

    public var englishName: String {
        switch self {
        case .english:
            "English"
        case .german:
            "German"
        case .french:
            "French"
        }
    }
}

public enum LocalizationReadinessStatus: String, Codable, Sendable {
    case releaseReady
    case planned
}

public struct LocalizationLanguageReadiness: Codable, Equatable, Sendable {
    public let language: AlpenLedgerLanguage
    public let status: LocalizationReadinessStatus
    public let scopeNote: String

    public init(
        language: AlpenLedgerLanguage,
        status: LocalizationReadinessStatus,
        scopeNote: String
    ) {
        self.language = language
        self.status = status
        self.scopeNote = scopeNote
    }
}

public enum LocalizationPolicy {
    public static let defaultLanguage: AlpenLedgerLanguage = .english

    public static let pilotLanguageReadiness: [LocalizationLanguageReadiness] = [
        LocalizationLanguageReadiness(
            language: .english,
            status: .releaseReady,
            scopeNote: "English is the v0.1 pilot UI, help, error, support, and release-note language."
        ),
        LocalizationLanguageReadiness(
            language: .german,
            status: .planned,
            scopeNote: "German requires translated app/package UI strings, Swiss finance/tax glossary review, and layout checks before availability can be claimed."
        ),
        LocalizationLanguageReadiness(
            language: .french,
            status: .planned,
            scopeNote: "French requires translated app/package UI strings, Swiss finance/tax glossary review, and layout checks before availability can be claimed."
        ),
    ]

    public static func readiness(for language: AlpenLedgerLanguage) -> LocalizationLanguageReadiness {
        pilotLanguageReadiness.first { $0.language == language }
            ?? LocalizationLanguageReadiness(
                language: language,
                status: .planned,
                scopeNote: "Language is not part of the current release-ready pilot set."
            )
    }

    public static func canClaimReleaseAvailability(for language: AlpenLedgerLanguage) -> Bool {
        readiness(for: language).status == .releaseReady
    }
}
