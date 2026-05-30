import Foundation
import Testing
@testable import ALDomain

@Test
func domainErrorCopyIsSpecificAndActionableForReleaseReview() {
    for error in sampleDomainErrorsForCopyReview() {
        let title = error.userFacingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = (error.errorDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let localizedDescription = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let recovery = (error.recoverySuggestion ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        #expect(title.isEmpty == false)
        #expect(title.count <= 52)
        #expect(title.hasSuffix(".") == false)
        #expect(title.localizedCaseInsensitiveContains("error") == false)

        #expect(description.isEmpty == false)
        #expect(description == localizedDescription)
        #expect(description.hasSuffix("."))
        #expect(description.localizedCaseInsensitiveContains("unknown error") == false)
        #expect(description.localizedCaseInsensitiveContains("something went wrong") == false)

        #expect(recovery.isEmpty == false)
        #expect(recovery.hasSuffix("."))
        #expect(recovery.localizedCaseInsensitiveContains("contact support") == false)
        #expect(recovery.localizedCaseInsensitiveContains("try again later") == false)
        #expect(recovery.localizedCaseInsensitiveContains("unknown") == false)
    }
}

private func sampleDomainErrorsForCopyReview() -> [DomainError] {
    [
        .currencyMismatch(expected: "CHF", actual: "EUR"),
        .invalidJournalLine,
        .unbalancedJournalEntry,
        .invalidWorkspaceName,
        .duplicateStatementImport,
        .workspaceNotFound,
        .missingWorkspaceKey,
        .workspaceBackupAlreadyExists,
        .invalidWorkspaceBackup,
        .workspaceBackupKeyConflict,
        .workspaceDeletionConfirmationMismatch,
        .unsupportedImportFormat,
        .importJobNotFound,
        .invalidImportRetry(reason: "the stored source blob is missing"),
        .financialAccountNotFound,
        .counterpartyNotFound,
        .invalidCounterpartyMerge,
        .lockedPeriod,
        .entityNotFound,
        .taxYearNotFound,
        .vatPeriodNotFound,
        .invalidVATPeriod(reason: "the end date is before the start date"),
        .vatPeriodHasBlockers(2),
        .invalidTaxYearStatusTransition,
        .taxFactNotFound,
        .invalidOverrideReason,
        .invalidEvidenceLink,
        .invalidDocumentArchive,
        .invalidDocumentRestore,
        .issueNotFound,
        .proposalNotFound,
        .invalidProposal,
        .invalidCurrencyCode("CH1"),
        .invalidCantonCode("ZZ"),
        .statementParseError(format: "CAMT.053", reason: "missing account statement"),
        .csvParseError(row: 4, reason: "amount is not numeric"),
    ]
}
