import Foundation

public enum DomainError: Error, LocalizedError, Equatable, Sendable {
    case currencyMismatch(expected: String, actual: String)
    case invalidJournalLine
    case unbalancedJournalEntry
    case invalidWorkspaceName
    case duplicateStatementImport
    case workspaceNotFound
    case missingWorkspaceKey
    case workspaceBackupAlreadyExists
    case invalidWorkspaceBackup
    case workspaceBackupKeyConflict
    case workspaceDeletionConfirmationMismatch
    case unsupportedImportFormat
    case importJobNotFound
    case invalidImportRetry(reason: String)
    case financialAccountNotFound
    case counterpartyNotFound
    case invalidCounterpartyMerge
    case lockedPeriod
    case entityNotFound
    case taxYearNotFound
    case vatPeriodNotFound
    case invalidVATPeriod(reason: String)
    case vatPeriodHasBlockers(Int)
    case invalidTaxYearStatusTransition
    case taxFactNotFound
    case invalidOverrideReason
    case invalidEvidenceLink
    case invalidDocumentMetadataReview
    case invalidDocumentArchive
    case invalidDocumentRestore
    case issueNotFound
    case proposalNotFound
    case invalidProposal
    case invalidCurrencyCode(String)
    case invalidCantonCode(String)
    case statementParseError(format: String, reason: String)
    case csvParseError(row: Int, reason: String)

    public var userFacingTitle: String {
        switch self {
        case .currencyMismatch:
            "Currency mismatch"
        case .invalidJournalLine:
            "Journal line incomplete"
        case .unbalancedJournalEntry:
            "Journal entry does not balance"
        case .invalidWorkspaceName:
            "Workspace name required"
        case .duplicateStatementImport:
            "Statement already imported"
        case .workspaceNotFound:
            "Workspace not found"
        case .missingWorkspaceKey:
            "Workspace key missing"
        case .workspaceBackupAlreadyExists:
            "Backup already exists"
        case .invalidWorkspaceBackup:
            "Backup cannot be restored"
        case .workspaceBackupKeyConflict:
            "Backup key conflict"
        case .workspaceDeletionConfirmationMismatch:
            "Workspace deletion not confirmed"
        case .unsupportedImportFormat:
            "Unsupported import format"
        case .importJobNotFound:
            "Import job not found"
        case .invalidImportRetry:
            "Import cannot be retried"
        case .financialAccountNotFound:
            "Account not found"
        case .counterpartyNotFound:
            "Counterparty not found"
        case .invalidCounterpartyMerge:
            "Counterparties cannot be merged"
        case .lockedPeriod:
            "Period is locked"
        case .entityNotFound:
            "Entity not found"
        case .taxYearNotFound:
            "Tax year not found"
        case .vatPeriodNotFound:
            "VAT period not found"
        case .invalidVATPeriod:
            "VAT period invalid"
        case .vatPeriodHasBlockers:
            "VAT period has blockers"
        case .invalidTaxYearStatusTransition:
            "Tax year status change blocked"
        case .taxFactNotFound:
            "Tax fact not found"
        case .invalidOverrideReason:
            "Override reason required"
        case .invalidEvidenceLink:
            "Evidence link not allowed"
        case .invalidDocumentMetadataReview:
            "Document metadata review blocked"
        case .invalidDocumentArchive:
            "Document cannot be archived"
        case .invalidDocumentRestore:
            "Document cannot be restored"
        case .issueNotFound:
            "Issue not found"
        case .proposalNotFound:
            "Proposal not found"
        case .invalidProposal:
            "Proposal cannot be applied"
        case .invalidCurrencyCode:
            "Invalid currency code"
        case .invalidCantonCode:
            "Invalid canton code"
        case let .statementParseError(format, _):
            "\(format) import failed"
        case .csvParseError:
            "CSV import failed"
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .currencyMismatch(expected, actual):
            "Currency mismatch. Expected \(expected), got \(actual)."
        case .invalidJournalLine:
            "Journal lines must contain exactly one non-zero side."
        case .unbalancedJournalEntry:
            "Journal entry lines must balance."
        case .invalidWorkspaceName:
            "Workspace names must not be empty."
        case .duplicateStatementImport:
            "This statement import was already processed."
        case .workspaceNotFound:
            "Workspace could not be found."
        case .missingWorkspaceKey:
            "Workspace encryption key is missing."
        case .workspaceBackupAlreadyExists:
            "A workspace backup already exists at the selected location."
        case .invalidWorkspaceBackup:
            "The selected workspace backup is invalid or incomplete."
        case .workspaceBackupKeyConflict:
            "A different encryption key already exists for this workspace."
        case .workspaceDeletionConfirmationMismatch:
            "The confirmation text did not match the current workspace name."
        case .unsupportedImportFormat:
            "The selected file is not supported by the current importer."
        case .importJobNotFound:
            "Import job could not be found."
        case let .invalidImportRetry(reason):
            "Import retry is not available: \(reason)."
        case .financialAccountNotFound:
            "Financial account could not be found."
        case .counterpartyNotFound:
            "Counterparty could not be found."
        case .invalidCounterpartyMerge:
            "Counterparty merges require two active counterparties from the same legal entity."
        case .lockedPeriod:
            "The selected operation would change a locked tax year or VAT period."
        case .entityNotFound:
            "Legal entity could not be found."
        case .taxYearNotFound:
            "Tax year could not be found."
        case .vatPeriodNotFound:
            "VAT period could not be found."
        case let .invalidVATPeriod(reason):
            "VAT period is invalid: \(reason)."
        case let .vatPeriodHasBlockers(count):
            "VAT period cannot be locked because \(count) blocking reconciliation issue(s) remain."
        case .invalidTaxYearStatusTransition:
            "The requested tax year status change is not allowed."
        case .taxFactNotFound:
            "Tax fact could not be found."
        case .invalidOverrideReason:
            "Manual overrides require a reason."
        case .invalidEvidenceLink:
            "Evidence links require an existing document and transaction in the same legal entity."
        case .invalidDocumentMetadataReview:
            "Document metadata can only be reviewed for active documents in the current workspace."
        case .invalidDocumentArchive:
            "Documents can only be archived when they exist in this workspace, have a reviewer reason, and are not active evidence."
        case .invalidDocumentRestore:
            "Archived documents can only be restored when they exist in this workspace and have a reviewer reason."
        case .issueNotFound:
            "Issue could not be found."
        case .proposalNotFound:
            "Proposal could not be found."
        case .invalidProposal:
            "The proposal cannot be applied."
        case let .invalidCurrencyCode(code):
            "Invalid ISO 4217 currency code: \(code)."
        case let .invalidCantonCode(code):
            "Invalid Swiss canton code: \(code)."
        case let .statementParseError(format, reason):
            "\(format) parse error: \(reason)."
        case let .csvParseError(row, reason):
            "CSV parse error at row \(row): \(reason)."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .currencyMismatch:
            "Use matching currencies for the amounts, or record a separate conversion before continuing."
        case .invalidJournalLine:
            "Enter either a debit or a credit amount for each line, not both."
        case .unbalancedJournalEntry:
            "Review the debit and credit totals, then adjust the draft before posting."
        case .invalidWorkspaceName:
            "Enter a workspace name with at least one visible character."
        case .duplicateStatementImport:
            "Review the existing import in the Inbox, or choose a different statement file."
        case .workspaceNotFound:
            "Choose an AlpenLedger workspace folder that contains workspace.json."
        case .missingWorkspaceKey:
            "Restore the workspace key from a trusted backup, or choose another workspace."
        case .workspaceBackupAlreadyExists:
            "Choose a different filename or location, or remove the existing backup after verifying it is no longer needed."
        case .invalidWorkspaceBackup:
            "Choose a complete .alpenledgerbackup folder and run Check Backup Integrity before restoring."
        case .workspaceBackupKeyConflict:
            "Use a backup created for this workspace, or restore into a separate workspace location."
        case .workspaceDeletionConfirmationMismatch:
            "Type the exact workspace name before deleting local workspace data and its encryption key."
        case .unsupportedImportFormat:
            "Choose a supported bank-statement CSV, CAMT.053 XML, or document file."
        case .importJobNotFound:
            "Refresh the Inbox and select an existing import job before retrying."
        case .invalidImportRetry:
            "Retry a failed or cancelled statement import that still has a stored raw source blob."
        case .financialAccountNotFound:
            "Select an existing financial account and refresh the workspace before retrying."
        case .counterpartyNotFound:
            "Refresh the workspace and select existing counterparties before retrying."
        case .invalidCounterpartyMerge:
            "Choose a different active source and target counterparty within the same entity."
        case .lockedPeriod:
            "Reopen the tax year or VAT period, or choose an unlocked period before making changes."
        case .entityNotFound:
            "Select an existing legal entity and refresh the workspace before retrying."
        case .taxYearNotFound:
            "Create or select the tax year before continuing."
        case .vatPeriodNotFound:
            "Create or select the VAT period before continuing."
        case .invalidVATPeriod:
            "Review the VAT period dates and existing periods, then try again."
        case .vatPeriodHasBlockers:
            "Resolve the blocking VAT reconciliation issues before locking the period."
        case .invalidTaxYearStatusTransition:
            "Use an allowed status path: open, locked, then filed. Filed years cannot be reopened."
        case .taxFactNotFound:
            "Refresh Tax Studio and select an existing tax fact."
        case .invalidOverrideReason:
            "Add a short reason explaining why the manual override is correct."
        case .invalidEvidenceLink:
            "Choose an unassigned document or a document assigned to the same entity as the selected transaction."
        case .invalidDocumentMetadataReview:
            "Restore the document first, or choose an active document in this workspace before confirming metadata."
        case .invalidDocumentArchive:
            "Revoke confirmed links or remove filing references first, then archive with a short reason."
        case .invalidDocumentRestore:
            "Select an archived document and add a short reason before restoring it to the active document vault."
        case .issueNotFound:
            "Refresh the Inbox and select an existing issue."
        case .proposalNotFound:
            "Refresh the Inbox and select an existing proposal."
        case .invalidProposal:
            "Review the proposal details and resolve any missing document or transaction links before applying it."
        case .invalidCurrencyCode:
            "Use a three-letter ISO 4217 code such as CHF, EUR, or USD."
        case .invalidCantonCode:
            "Use a valid Swiss canton abbreviation such as ZH, BE, or GE."
        case let .statementParseError(format, _):
            "Check that the selected file is a valid \(format) bank statement export, then import it again."
        case let .csvParseError(row, _):
            "Check the CSV header and row \(row), fix the reported value, then import the file again."
        }
    }
}
