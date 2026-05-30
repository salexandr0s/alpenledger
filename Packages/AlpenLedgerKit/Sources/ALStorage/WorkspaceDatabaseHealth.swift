import Foundation
import GRDB

public enum AlpenLedgerDatabaseMigrations {
    public static let v1Core = "v1_core"
    public static let v2EvidenceInbox = "v2_evidence_inbox"
    public static let v3TaxFacts = "v3_tax_facts"
    public static let v4PerformanceIndexes = "v4_performance_indexes"
    public static let v5EntityWorkspaceAndModels = "v5_entity_workspace_and_models"
    public static let v6AgentProposalDecisionMetadata = "v6_agent_proposal_decision_metadata"
    public static let v7AgentProposalRelatedRef = "v7_agent_proposal_related_ref"
    public static let v8TransactionVATCode = "v8_transaction_vat_code"
    public static let v9VATPeriods = "v9_vat_periods"
    public static let v10FilingPackageFinalization = "v10_filing_package_finalization"
    public static let v11JournalEntries = "v11_journal_entries"
    public static let v12Counterparties = "v12_counterparties"
    public static let v13ReportingViews = "v13_reporting_views"
    public static let v14GlobalSearch = "v14_global_search"
    public static let v15AgentProposalUncertaintyMetadata = "v15_agent_proposal_uncertainty_metadata"
    public static let v16ImportDiagnostics = "v16_import_diagnostics"
    public static let v17AgentConversationStorage = "v17_agent_conversation_storage"
    public static let v18ImportJobSourceTracking = "v18_import_job_source_tracking"
    public static let v19AgentRunTrace = "v19_agent_run_trace"
    public static let v20DocumentArchiveState = "v20_document_archive_state"
    public static let v21AccountOpeningBalances = "v21_account_opening_balances"

    public static let identifiers: [String] = [
        v1Core,
        v2EvidenceInbox,
        v3TaxFacts,
        v4PerformanceIndexes,
        v5EntityWorkspaceAndModels,
        v6AgentProposalDecisionMetadata,
        v7AgentProposalRelatedRef,
        v8TransactionVATCode,
        v9VATPeriods,
        v10FilingPackageFinalization,
        v11JournalEntries,
        v12Counterparties,
        v13ReportingViews,
        v14GlobalSearch,
        v15AgentProposalUncertaintyMetadata,
        v16ImportDiagnostics,
        v17AgentConversationStorage,
        v18ImportJobSourceTracking,
        v19AgentRunTrace,
        v20DocumentArchiveState,
        v21AccountOpeningBalances,
    ]

    public static let requiredTables: [String] = [
        "agentConversations",
        "agentMessages",
        "agentPendingApprovals",
        "agentProposals",
        "agentRuns",
        "auditEvents",
        "categories",
        "counterparties",
        "document_search",
        "documents",
        "entityWorkspaces",
        "evidenceLinks",
        "filingPackages",
        "financialAccounts",
        "global_search",
        "globalSearchRecords",
        "importDiagnostics",
        "importJobs",
        "invoiceRecords",
        "issues",
        "journalEntries",
        "journalLines",
        "ledgerAccounts",
        "legalEntities",
        "requirements",
        "statementImports",
        "taxFacts",
        "taxProfiles",
        "taxYears",
        "transactions",
        "vatPeriods",
        "workspaces",
    ]

    public static let requiredViews: [String] = [
        "vw_spend_by_month",
        "vw_cashflow_by_entity",
        "vw_missing_evidence",
        "vw_statement_coverage",
        "vw_tax_fact_status",
        "vw_unmatched_transactions",
        "vw_vat_reconciliation",
    ]
}

public enum WorkspaceDatabaseHealthSeverity: String, Codable, Equatable, Sendable {
    case warning
    case blocker
}

public struct WorkspaceDatabaseHealthIssue: Codable, Equatable, Identifiable, Sendable {
    public var id: String { code }

    public let code: String
    public let severity: WorkspaceDatabaseHealthSeverity
    public let summary: String

    public init(code: String, severity: WorkspaceDatabaseHealthSeverity, summary: String) {
        self.code = code
        self.severity = severity
        self.summary = summary
    }
}

public struct WorkspaceDatabaseHealthReport: Codable, Equatable, Sendable {
    public let quickCheckResult: String
    public let foreignKeysEnabled: Bool
    public let foreignKeyViolationCount: Int
    public let expectedMigrationIdentifiers: [String]
    public let appliedMigrationIdentifiers: [String]
    public let missingRequiredTables: [String]
    public let missingRequiredViews: [String]
    public let pageCount: Int
    public let freelistCount: Int
    public let issues: [WorkspaceDatabaseHealthIssue]

    public var isHealthy: Bool {
        issues.isEmpty
    }

    public init(
        quickCheckResult: String,
        foreignKeysEnabled: Bool,
        foreignKeyViolationCount: Int,
        expectedMigrationIdentifiers: [String],
        appliedMigrationIdentifiers: [String],
        missingRequiredTables: [String],
        missingRequiredViews: [String],
        pageCount: Int,
        freelistCount: Int,
        issues: [WorkspaceDatabaseHealthIssue]
    ) {
        self.quickCheckResult = quickCheckResult
        self.foreignKeysEnabled = foreignKeysEnabled
        self.foreignKeyViolationCount = foreignKeyViolationCount
        self.expectedMigrationIdentifiers = expectedMigrationIdentifiers
        self.appliedMigrationIdentifiers = appliedMigrationIdentifiers
        self.missingRequiredTables = missingRequiredTables
        self.missingRequiredViews = missingRequiredViews
        self.pageCount = pageCount
        self.freelistCount = freelistCount
        self.issues = issues
    }
}

public extension WorkspaceStorage {
    func databaseHealthReport() throws -> WorkspaceDatabaseHealthReport {
        try dbPool.read { db in
            let quickCheckRows = try String.fetchAll(db, sql: "PRAGMA quick_check")
            let quickCheckResult = quickCheckRows.joined(separator: "\n")
            let foreignKeysEnabled = (try Int.fetchOne(db, sql: "PRAGMA foreign_keys") ?? 0) == 1
            let foreignKeyViolationCount = try Row.fetchAll(db, sql: "PRAGMA foreign_key_check").count
            let migrationTableExists = try db.tableExists("grdb_migrations")
            let appliedMigrationIdentifiers: [String]
            if migrationTableExists {
                appliedMigrationIdentifiers = try String.fetchAll(
                    db,
                    sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
                )
            } else {
                appliedMigrationIdentifiers = []
            }

            let missingRequiredTables = try AlpenLedgerDatabaseMigrations.requiredTables
                .filter { try db.tableExists($0) == false }
            let existingViews = try Set(String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'view'"
            ))
            let missingRequiredViews = AlpenLedgerDatabaseMigrations.requiredViews
                .filter { existingViews.contains($0) == false }
            let pageCount = try Int.fetchOne(db, sql: "PRAGMA page_count") ?? 0
            let freelistCount = try Int.fetchOne(db, sql: "PRAGMA freelist_count") ?? 0

            var issues: [WorkspaceDatabaseHealthIssue] = []
            if quickCheckRows != ["ok"] {
                issues.append(
                    WorkspaceDatabaseHealthIssue(
                        code: "quick-check-failed",
                        severity: .blocker,
                        summary: "SQLite quick_check returned \(quickCheckResult.isEmpty ? "no result" : quickCheckResult)."
                    )
                )
            }
            if foreignKeysEnabled == false {
                issues.append(
                    WorkspaceDatabaseHealthIssue(
                        code: "foreign-keys-disabled",
                        severity: .blocker,
                        summary: "Foreign-key enforcement is disabled for this database connection."
                    )
                )
            }
            if foreignKeyViolationCount > 0 {
                issues.append(
                    WorkspaceDatabaseHealthIssue(
                        code: "foreign-key-violations",
                        severity: .blocker,
                        summary: "\(foreignKeyViolationCount) foreign-key violation(s) were found."
                    )
                )
            }
            if migrationTableExists == false {
                issues.append(
                    WorkspaceDatabaseHealthIssue(
                        code: "migration-ledger-missing",
                        severity: .blocker,
                        summary: "The migration ledger table is missing."
                    )
                )
            }

            let appliedSet = Set(appliedMigrationIdentifiers)
            let expectedSet = Set(AlpenLedgerDatabaseMigrations.identifiers)
            let missingMigrations = AlpenLedgerDatabaseMigrations.identifiers.filter { appliedSet.contains($0) == false }
            if missingMigrations.isEmpty == false {
                issues.append(
                    WorkspaceDatabaseHealthIssue(
                        code: "migrations-missing",
                        severity: .blocker,
                        summary: "Missing migration(s): \(missingMigrations.joined(separator: ", "))."
                    )
                )
            }

            let unknownMigrations = appliedMigrationIdentifiers.filter { expectedSet.contains($0) == false }
            if unknownMigrations.isEmpty == false {
                issues.append(
                    WorkspaceDatabaseHealthIssue(
                        code: "unknown-migrations",
                        severity: .warning,
                        summary: "Unknown migration(s): \(unknownMigrations.joined(separator: ", "))."
                    )
                )
            }

            if missingRequiredTables.isEmpty == false {
                issues.append(
                    WorkspaceDatabaseHealthIssue(
                        code: "required-tables-missing",
                        severity: .blocker,
                        summary: "Missing required table(s): \(missingRequiredTables.joined(separator: ", "))."
                    )
                )
            }

            if missingRequiredViews.isEmpty == false {
                issues.append(
                    WorkspaceDatabaseHealthIssue(
                        code: "required-views-missing",
                        severity: .blocker,
                        summary: "Missing required view(s): \(missingRequiredViews.joined(separator: ", "))."
                    )
                )
            }

            return WorkspaceDatabaseHealthReport(
                quickCheckResult: quickCheckResult,
                foreignKeysEnabled: foreignKeysEnabled,
                foreignKeyViolationCount: foreignKeyViolationCount,
                expectedMigrationIdentifiers: AlpenLedgerDatabaseMigrations.identifiers,
                appliedMigrationIdentifiers: appliedMigrationIdentifiers,
                missingRequiredTables: missingRequiredTables,
                missingRequiredViews: missingRequiredViews,
                pageCount: pageCount,
                freelistCount: freelistCount,
                issues: issues
            )
        }
    }
}
