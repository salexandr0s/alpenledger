import Foundation
import GRDB

func makeAlpenLedgerDatabaseMigrator() -> DatabaseMigrator {
    var migrator = DatabaseMigrator()

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v1Core) { db in
        try db.create(table: "workspaces", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("name", .text).notNull()
            table.column("storageVersion", .integer).notNull()
            table.column("createdAt", .datetime).notNull()
            table.column("defaultCurrency", .text).notNull()
            table.column("privacyMode", .text).notNull()
            table.column("encryptionSaltRef", .text).notNull()
        }

        try db.create(table: "legalEntities", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("workspaceId", .text).notNull().references("workspaces", onDelete: .cascade)
            table.column("kind", .text).notNull()
            table.column("legalName", .text).notNull()
            table.column("displayName", .text).notNull()
            table.column("country", .text).notNull()
            table.column("canton", .text)
            table.column("taxIdOrUID", .text)
            table.column("fiscalYearStartMonth", .integer).notNull()
            table.column("fiscalYearStartDay", .integer).notNull()
            table.column("parentEntityId", .text)
        }

        try db.create(table: "taxYears", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("year", .integer).notNull()
            table.column("periodStart", .datetime).notNull()
            table.column("periodEnd", .datetime).notNull()
            table.column("canton", .text)
            table.column("filingMode", .text).notNull()
            table.column("rulesetVersion", .text).notNull()
            table.column("status", .text).notNull()
        }

        try db.create(table: "ledgerAccounts", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("code", .text).notNull()
            table.column("name", .text).notNull()
            table.column("category", .text).notNull()
            table.column("normalBalance", .text).notNull()
            table.column("parentId", .text)
            table.column("taxRole", .text)
            table.column("isControlAccount", .boolean).notNull()
        }

        try db.create(table: "financialAccounts", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("accountType", .text).notNull()
            table.column("institutionName", .text).notNull()
            table.column("displayName", .text).notNull()
            table.column("currency", .text).notNull()
            table.column("ibanMask", .text)
            table.column("statementCadence", .text).notNull()
            table.column("ledgerControlAccountId", .text).notNull().references("ledgerAccounts")
            table.column("openedAt", .datetime).notNull()
            table.column("closedAt", .datetime)
        }

        try db.create(table: "importJobs", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("workspaceId", .text).notNull().references("workspaces", onDelete: .cascade)
            table.column("kind", .text).notNull()
            table.column("source", .text).notNull()
            table.column("sourceBlobHash", .text)
            table.column("sourceFingerprint", .text)
            table.column("parserKey", .text).notNull()
            table.column("parserVersion", .text).notNull()
            table.column("status", .text).notNull()
            table.column("startedAt", .datetime).notNull()
            table.column("completedAt", .datetime)
            table.column("warningCount", .integer).notNull()
        }

        try db.create(table: "statementImports", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("accountId", .text).notNull().references("financialAccounts", onDelete: .cascade)
            table.column("importJobId", .text).notNull().references("importJobs", onDelete: .cascade)
            table.column("sourceBlobHash", .text).notNull()
            table.column("sourceFormat", .text).notNull()
            table.column("sourceFingerprint", .text).notNull()
            table.column("coverageStart", .datetime).notNull()
            table.column("coverageEnd", .datetime).notNull()
            table.column("openingBalanceMinor", .integer)
            table.column("closingBalanceMinor", .integer)
            table.column("parserVersion", .text).notNull()
            table.column("status", .text).notNull()
        }
        try db.create(index: "statementImports_account_fingerprint", on: "statementImports", columns: ["accountId", "sourceFingerprint"], unique: true, ifNotExists: true)

        try db.create(table: "transactions", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("accountId", .text).notNull().references("financialAccounts", onDelete: .cascade)
            table.column("statementImportId", .text).references("statementImports", onDelete: .cascade)
            table.column("originKind", .text).notNull()
            table.column("sourceLineRef", .text).notNull()
            table.column("bookingDate", .datetime).notNull()
            table.column("valueDate", .datetime)
            table.column("amountMinor", .integer).notNull()
            table.column("currency", .text).notNull()
            table.column("counterpartyName", .text).notNull()
            table.column("memo", .text).notNull()
            table.column("reference", .text)
            table.column("taxCode", .text)
            table.column("balanceAfterMinor", .integer)
            table.column("reviewState", .text).notNull()
        }

        try db.create(table: "documents", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("workspaceId", .text).notNull().references("workspaces", onDelete: .cascade)
            table.column("importJobId", .text).references("importJobs", onDelete: .setNull)
            table.column("blobHash", .text).notNull()
            table.column("originalFilename", .text).notNull()
            table.column("mediaType", .text).notNull()
            table.column("origin", .text).notNull()
            table.column("documentType", .text).notNull()
            table.column("issueDate", .datetime)
            table.column("detectedEntityId", .text)
            table.column("detectedTaxYearId", .text)
            table.column("extractedText", .text)
            table.column("metadataStatus", .text).notNull()
            table.column("parseVersion", .text).notNull()
        }
        try db.create(index: "documents_workspace_blobhash", on: "documents", columns: ["workspaceId", "blobHash"], unique: true, ifNotExists: true)

        try db.create(table: "evidenceLinks", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("sourceRef", .text).notNull()
            table.column("targetRef", .text).notNull()
            table.column("linkType", .text).notNull()
            table.column("status", .text).notNull()
            table.column("confidence", .double).notNull()
            table.column("createdByKind", .text).notNull()
            table.column("approvalRequired", .boolean).notNull()
            table.column("reason", .text)
        }

        try db.create(table: "auditEvents", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("workspaceId", .text).notNull().references("workspaces", onDelete: .cascade)
            table.column("actorType", .text).notNull()
            table.column("actorId", .text).notNull()
            table.column("eventType", .text).notNull()
            table.column("objectRef", .text).notNull()
            table.column("payload", .text)
            table.column("occurredAt", .datetime).notNull()
        }

        try db.execute(sql: """
        CREATE VIRTUAL TABLE IF NOT EXISTS document_search
        USING fts5(documentId UNINDEXED, workspaceId UNINDEXED, content)
        """)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v2EvidenceInbox) { db in
        try db.create(table: "requirements", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("fingerprint", .text).notNull()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("taxYearId", .text).references("taxYears", onDelete: .setNull)
            table.column("requirementCode", .text).notNull()
            table.column("subjectRef", .text).notNull()
            table.column("summary", .text).notNull()
            table.column("coverageStart", .datetime)
            table.column("coverageEnd", .datetime)
            table.column("status", .text).notNull()
            table.column("satisfiedByRef", .text)
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }
        try db.create(index: "requirements_fingerprint", on: "requirements", columns: ["fingerprint"], unique: true, ifNotExists: true)

        try db.create(table: "issues", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("fingerprint", .text).notNull()
            table.column("workspaceId", .text).notNull().references("workspaces", onDelete: .cascade)
            table.column("entityId", .text).references("legalEntities", onDelete: .setNull)
            table.column("taxYearId", .text).references("taxYears", onDelete: .setNull)
            table.column("issueCode", .text).notNull()
            table.column("severity", .text).notNull()
            table.column("status", .text).notNull()
            table.column("summary", .text).notNull()
            table.column("objectRef", .text).notNull()
            table.column("relatedRef", .text)
            table.column("firstDetectedAt", .datetime).notNull()
            table.column("lastDetectedAt", .datetime).notNull()
        }
        try db.create(index: "issues_fingerprint", on: "issues", columns: ["fingerprint"], unique: true, ifNotExists: true)
        try db.create(index: "issues_workspace_status", on: "issues", columns: ["workspaceId", "status"], ifNotExists: true)

        try db.create(table: "agentProposals", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("fingerprint", .text).notNull()
            table.column("workspaceId", .text).notNull().references("workspaces", onDelete: .cascade)
            table.column("agentKind", .text).notNull()
            table.column("proposalType", .text).notNull()
            table.column("targetRef", .text).notNull()
            table.column("relatedRef", .text)
            table.column("summary", .text).notNull()
            table.column("rationale", .text).notNull()
            table.column("confidence", .double).notNull()
            table.column("missingFields", .text).notNull().defaults(to: "[]")
            table.column("question", .text)
            table.column("requiresManualReview", .boolean).notNull().defaults(to: false)
            table.column("status", .text).notNull()
            table.column("createdAt", .datetime).notNull()
            table.column("decidedAt", .datetime)
            table.column("decidedBy", .text)
            table.column("decisionReason", .text)
        }
        try db.create(index: "agentProposals_fingerprint", on: "agentProposals", columns: ["fingerprint"], unique: true, ifNotExists: true)
        try db.create(index: "agentProposals_workspace_status", on: "agentProposals", columns: ["workspaceId", "status"], ifNotExists: true)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v3TaxFacts) { db in
        try db.create(table: "taxFacts", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("fingerprint", .text).notNull()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("taxYearId", .text).notNull().references("taxYears", onDelete: .cascade)
            table.column("jurisdictionCode", .text).notNull()
            table.column("conceptCode", .text).notNull()
            table.column("valueType", .text).notNull()
            table.column("moneyMinor", .integer)
            table.column("textValue", .text)
            table.column("boolValue", .boolean)
            table.column("dateValue", .datetime)
            table.column("currency", .text)
            table.column("status", .text).notNull()
            table.column("rulesetVersion", .text).notNull()
            table.column("provenanceRefs", .text).notNull()
            table.column("confidence", .double).notNull()
            table.column("supersedesFactId", .text).references("taxFacts")
            table.column("isCurrent", .boolean).notNull()
            table.column("overrideReason", .text)
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }
        try db.create(index: "taxFacts_entity_taxYear_current", on: "taxFacts", columns: ["entityId", "taxYearId", "isCurrent"], ifNotExists: true)
        try db.create(index: "taxFacts_fingerprint_current", on: "taxFacts", columns: ["fingerprint", "isCurrent"], ifNotExists: true)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v4PerformanceIndexes) { db in
        try db.create(index: "transactions_account_bookingDate", on: "transactions", columns: ["accountId", "bookingDate"], ifNotExists: true)
        try db.create(index: "evidenceLinks_sourceRef", on: "evidenceLinks", columns: ["sourceRef"], ifNotExists: true)
        try db.create(index: "evidenceLinks_targetRef", on: "evidenceLinks", columns: ["targetRef"], ifNotExists: true)
        try db.create(index: "auditEvents_workspace_occurredAt", on: "auditEvents", columns: ["workspaceId", "occurredAt"], ifNotExists: true)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v5EntityWorkspaceAndModels) { db in
        try db.create(table: "entityWorkspaces", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("workspaceId", .text).notNull().references("workspaces", onDelete: .cascade)
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("displayName", .text).notNull()
            table.column("isDefault", .boolean).notNull()
            table.column("lastAccessedAt", .datetime).notNull()
            table.column("createdAt", .datetime).notNull()
        }
        try db.create(index: "entityWorkspaces_workspace_entity", on: "entityWorkspaces", columns: ["workspaceId", "entityId"], unique: true, ifNotExists: true)

        try db.create(table: "taxProfiles", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("taxationType", .text).notNull()
            table.column("canton", .text).notNull()
            table.column("municipality", .text)
            table.column("maritalStatus", .text)
            table.column("numberOfDependents", .integer).notNull()
            table.column("rulesetVersionOverride", .text)
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }
        try db.create(index: "taxProfiles_entity", on: "taxProfiles", columns: ["entityId"], unique: true, ifNotExists: true)

        try db.create(table: "categories", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("code", .text).notNull()
            table.column("displayName", .text).notNull()
            table.column("parentId", .text).references("categories")
            table.column("taxRole", .text)
            table.column("isSystemDefined", .boolean).notNull()
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }
        try db.create(index: "categories_entity_code", on: "categories", columns: ["entityId", "code"], unique: true, ifNotExists: true)

        try db.create(table: "invoiceRecords", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("documentId", .text).notNull().references("documents", onDelete: .cascade)
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("invoiceNumber", .text)
            table.column("counterpartyName", .text).notNull()
            table.column("issueDate", .datetime)
            table.column("dueDate", .datetime)
            table.column("totalAmountMinor", .integer).notNull()
            table.column("currency", .text).notNull()
            table.column("direction", .text).notNull()
            table.column("status", .text).notNull()
            table.column("linkedTransactionId", .text).references("transactions")
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }

        try db.create(index: "invoiceRecords_entity", on: "invoiceRecords", columns: ["entityId"], ifNotExists: true)
        try db.create(index: "invoiceRecords_document", on: "invoiceRecords", columns: ["documentId"], ifNotExists: true)

        try db.create(table: "filingPackages", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("taxYearId", .text).notNull().references("taxYears", onDelete: .cascade)
            table.column("status", .text).notNull()
            table.column("generatedAt", .datetime)
            table.column("finalizedAt", .datetime)
            table.column("finalizedBy", .text)
            table.column("submittedAt", .datetime)
            table.column("snapshotHash", .text)
            table.column("exportFormat", .text).notNull()
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }

        try db.create(index: "filingPackages_entity_taxYear", on: "filingPackages", columns: ["entityId", "taxYearId"], ifNotExists: true)

        try db.alter(table: "documents") { table in
            table.add(column: "entityId", .text).references("legalEntities", onDelete: .setNull)
        }

        try db.execute(sql: "UPDATE documents SET entityId = detectedEntityId WHERE detectedEntityId IS NOT NULL")

        let now = ISO8601DateFormatter().string(from: Date())
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT id, workspaceId, displayName, kind
            FROM legalEntities
            ORDER BY workspaceId, kind = 'naturalPerson' DESC, displayName
            """
        )
        var defaultedWorkspaceIds = Set<String>()
        for row in rows {
            let entityId: String = row["id"]
            let workspaceId: String = row["workspaceId"]
            let displayName: String = row["displayName"]
            let ewId = UUID().uuidString.lowercased()
            let isDefault = defaultedWorkspaceIds.insert(workspaceId).inserted
            try db.execute(
                sql: """
                INSERT INTO entityWorkspaces (id, workspaceId, entityId, displayName, isDefault, lastAccessedAt, createdAt)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [ewId, workspaceId, entityId, displayName, isDefault, now, now]
            )
        }
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v6AgentProposalDecisionMetadata) { db in
        let columns = try Set(db.columns(in: "agentProposals").map(\.name))
        if columns.contains("decidedBy") == false {
            try db.alter(table: "agentProposals") { table in
                table.add(column: "decidedBy", .text)
            }
        }
        if columns.contains("decisionReason") == false {
            try db.alter(table: "agentProposals") { table in
                table.add(column: "decisionReason", .text)
            }
        }
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v7AgentProposalRelatedRef) { db in
        let columns = try Set(db.columns(in: "agentProposals").map(\.name))
        if columns.contains("relatedRef") == false {
            try db.alter(table: "agentProposals") { table in
                table.add(column: "relatedRef", .text)
            }
        }
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v8TransactionVATCode) { db in
        let columns = try Set(db.columns(in: "transactions").map(\.name))
        if columns.contains("taxCode") == false {
            try db.alter(table: "transactions") { table in
                table.add(column: "taxCode", .text)
            }
        }
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v9VATPeriods) { db in
        try db.create(table: "vatPeriods", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("periodStart", .datetime).notNull()
            table.column("periodEnd", .datetime).notNull()
            table.column("currency", .text).notNull()
            table.column("status", .text).notNull()
        }
        try db.create(index: "vatPeriods_entity_period", on: "vatPeriods", columns: ["entityId", "periodStart", "periodEnd"], ifNotExists: true)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v10FilingPackageFinalization) { db in
        let columns = try Set(db.columns(in: "filingPackages").map(\.name))
        if columns.contains("finalizedAt") == false {
            try db.alter(table: "filingPackages") { table in
                table.add(column: "finalizedAt", .datetime)
            }
        }
        if columns.contains("finalizedBy") == false {
            try db.alter(table: "filingPackages") { table in
                table.add(column: "finalizedBy", .text)
            }
        }
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v11JournalEntries) { db in
        try db.create(table: "journalEntries", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("taxYearId", .text).references("taxYears", onDelete: .setNull)
            table.column("entryNumber", .text).notNull()
            table.column("effectiveDate", .datetime).notNull()
            table.column("kind", .text).notNull()
            table.column("status", .text).notNull()
            table.column("memo", .text).notNull()
            table.column("reversalOfId", .text).references("journalEntries", onDelete: .setNull)
            table.column("createdBy", .text).notNull()
            table.column("approvedBy", .text)
            table.column("approvedAt", .datetime)
        }
        try db.create(
            index: "journalEntries_entity_entryNumber",
            on: "journalEntries",
            columns: ["entityId", "entryNumber"],
            unique: true,
            ifNotExists: true
        )
        try db.create(index: "journalEntries_entity_taxYear", on: "journalEntries", columns: ["entityId", "taxYearId"], ifNotExists: true)

        try db.create(table: "journalLines", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("journalEntryId", .text).notNull().references("journalEntries", onDelete: .cascade)
            table.column("ledgerAccountId", .text).notNull().references("ledgerAccounts")
            table.column("debitMinor", .integer).notNull()
            table.column("creditMinor", .integer).notNull()
            table.column("currency", .text).notNull()
            table.column("taxCode", .text)
            table.column("sourceObjectRef", .text)
            table.column("memo", .text).notNull()
        }
        try db.create(index: "journalLines_entry", on: "journalLines", columns: ["journalEntryId"], ifNotExists: true)
        try db.create(index: "journalLines_account", on: "journalLines", columns: ["ledgerAccountId"], ifNotExists: true)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v12Counterparties) { db in
        try db.create(table: "counterparties", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("entityId", .text).notNull().references("legalEntities", onDelete: .cascade)
            table.column("displayName", .text).notNull()
            table.column("normalizedName", .text).notNull()
            table.column("status", .text).notNull()
            table.column("mergedIntoCounterpartyId", .text).references("counterparties", onDelete: .setNull)
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }
        try db.create(
            index: "counterparties_entity_normalized",
            on: "counterparties",
            columns: ["entityId", "normalizedName"],
            unique: true,
            ifNotExists: true
        )
        try db.create(index: "counterparties_entity_status", on: "counterparties", columns: ["entityId", "status"], ifNotExists: true)
        try db.create(index: "counterparties_merged_into", on: "counterparties", columns: ["mergedIntoCounterpartyId"], ifNotExists: true)

        let transactionColumns = try Set(db.columns(in: "transactions").map(\.name))
        if transactionColumns.contains("counterpartyId") == false {
            try db.alter(table: "transactions") { table in
                table.add(column: "counterpartyId", .text).references("counterparties", onDelete: .setNull)
            }
        }
        try db.create(index: "transactions_counterparty", on: "transactions", columns: ["counterpartyId"], ifNotExists: true)

        try backfillCounterparties(db)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v13ReportingViews) { db in
        try createReportingViews(db)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v14GlobalSearch) { db in
        try createGlobalSearchIndex(db)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v15AgentProposalUncertaintyMetadata) { db in
        let columns = try Set(db.columns(in: "agentProposals").map(\.name))
        if columns.contains("missingFields") == false {
            try db.alter(table: "agentProposals") { table in
                table.add(column: "missingFields", .text).notNull().defaults(to: "[]")
            }
        }
        if columns.contains("question") == false {
            try db.alter(table: "agentProposals") { table in
                table.add(column: "question", .text)
            }
        }
        if columns.contains("requiresManualReview") == false {
            try db.alter(table: "agentProposals") { table in
                table.add(column: "requiresManualReview", .boolean).notNull().defaults(to: false)
            }
        }
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v16ImportDiagnostics) { db in
        try db.create(table: "importDiagnostics", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("importJobId", .text).notNull().references("importJobs", onDelete: .cascade)
            table.column("severity", .text).notNull()
            table.column("code", .text).notNull()
            table.column("location", .text)
            table.column("message", .text).notNull()
            table.column("createdAt", .datetime).notNull()
        }
        try db.create(index: "importDiagnostics_importJob", on: "importDiagnostics", columns: ["importJobId"], ifNotExists: true)
        try db.create(index: "importDiagnostics_code", on: "importDiagnostics", columns: ["code"], ifNotExists: true)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v17AgentConversationStorage) { db in
        try db.create(table: "agentConversations", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("workspaceId", .text).notNull().references("workspaces", onDelete: .cascade)
            table.column("title", .text).notNull()
            table.column("activeEntityId", .text).references("legalEntities", onDelete: .setNull)
            table.column("activeTaxYearId", .text).references("taxYears", onDelete: .setNull)
            table.column("status", .text).notNull()
            table.column("createdAt", .datetime).notNull()
            table.column("updatedAt", .datetime).notNull()
        }
        try db.create(index: "agentConversations_workspace_status", on: "agentConversations", columns: ["workspaceId", "status"], ifNotExists: true)

        try db.create(table: "agentMessages", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("conversationId", .text).notNull().references("agentConversations", onDelete: .cascade)
            table.column("role", .text).notNull()
            table.column("content", .text).notNull()
            table.column("sourceRefs", .text).notNull().defaults(to: "[]")
            table.column("unresolvedQuestions", .text).notNull().defaults(to: "[]")
            table.column("providerID", .text)
            table.column("promptTemplateID", .text)
            table.column("sentDataOffDevice", .boolean).notNull().defaults(to: false)
            table.column("createdAt", .datetime).notNull()
        }
        try db.create(index: "agentMessages_conversation_createdAt", on: "agentMessages", columns: ["conversationId", "createdAt"], ifNotExists: true)

        try db.create(table: "agentPendingApprovals", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("conversationId", .text).notNull().references("agentConversations", onDelete: .cascade)
            table.column("toolName", .text).notNull()
            table.column("inputHash", .text).notNull()
            table.column("inputSummary", .text).notNull()
            table.column("requiredScopes", .text).notNull().defaults(to: "[]")
            table.column("targetRefs", .text).notNull().defaults(to: "[]")
            table.column("status", .text).notNull()
            table.column("requestedBy", .text).notNull()
            table.column("requestedAt", .datetime).notNull()
            table.column("decidedBy", .text)
            table.column("decidedAt", .datetime)
            table.column("decisionReason", .text)
        }
        try db.create(index: "agentPendingApprovals_conversation_status", on: "agentPendingApprovals", columns: ["conversationId", "status"], ifNotExists: true)
        try db.create(index: "agentPendingApprovals_tool_input_hash", on: "agentPendingApprovals", columns: ["toolName", "inputHash"], ifNotExists: true)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v18ImportJobSourceTracking) { db in
        let columns = try Set(db.columns(in: "importJobs").map(\.name))
        if columns.contains("sourceBlobHash") == false {
            try db.alter(table: "importJobs") { table in
                table.add(column: "sourceBlobHash", .text)
            }
        }
        if columns.contains("sourceFingerprint") == false {
            try db.alter(table: "importJobs") { table in
                table.add(column: "sourceFingerprint", .text)
            }
        }
        try db.create(
            index: "importJobs_workspace_kind_sourceBlobHash",
            on: "importJobs",
            columns: ["workspaceId", "kind", "sourceBlobHash"],
            ifNotExists: true
        )
        try db.create(
            index: "importJobs_workspace_kind_sourceFingerprint",
            on: "importJobs",
            columns: ["workspaceId", "kind", "sourceFingerprint"],
            ifNotExists: true
        )
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v19AgentRunTrace) { db in
        try db.create(table: "agentRuns", ifNotExists: true) { table in
            table.column("id", .text).primaryKey()
            table.column("conversationId", .text).notNull().references("agentConversations", onDelete: .cascade)
            table.column("userMessageId", .text).references("agentMessages", onDelete: .setNull)
            table.column("assistantMessageId", .text).references("agentMessages", onDelete: .setNull)
            table.column("status", .text).notNull()
            table.column("intent", .text).notNull()
            table.column("specialists", .text).notNull().defaults(to: "[]")
            table.column("plannedToolNames", .text).notNull().defaults(to: "[]")
            table.column("unavailableToolNames", .text).notNull().defaults(to: "[]")
            table.column("requiredScopes", .text).notNull().defaults(to: "[]")
            table.column("contextRefs", .text).notNull().defaults(to: "[]")
            table.column("clarificationQuestion", .text)
            table.column("rationale", .text).notNull().defaults(to: "")
            table.column("modelProviderID", .text)
            table.column("modelCapability", .text)
            table.column("promptTemplateID", .text)
            table.column("modelInputScope", .text)
            table.column("sentDataOffDevice", .boolean).notNull().defaults(to: false)
            table.column("toolCalls", .text).notNull().defaults(to: "[]")
            table.column("approvalDecisions", .text).notNull().defaults(to: "[]")
            table.column("errorCode", .text)
            table.column("startedAt", .datetime).notNull()
            table.column("finishedAt", .datetime)
        }
        try db.create(index: "agentRuns_conversation_startedAt", on: "agentRuns", columns: ["conversationId", "startedAt"], ifNotExists: true)
        try db.create(index: "agentRuns_status", on: "agentRuns", columns: ["status"], ifNotExists: true)
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v20DocumentArchiveState) { db in
        guard try db.tableExists("documents") else {
            return
        }
        let columns = try Set(db.columns(in: "documents").map(\.name))
        if columns.contains("status") == false {
            try db.alter(table: "documents") { table in
                table.add(column: "status", .text).notNull().defaults(to: "active")
            }
        }
        if columns.contains("archivedAt") == false {
            try db.alter(table: "documents") { table in
                table.add(column: "archivedAt", .datetime)
            }
        }
        if columns.contains("archivedBy") == false {
            try db.alter(table: "documents") { table in
                table.add(column: "archivedBy", .text)
            }
        }
        if columns.contains("archiveReason") == false {
            try db.alter(table: "documents") { table in
                table.add(column: "archiveReason", .text)
            }
        }

        try db.execute(sql: "UPDATE documents SET status = 'active' WHERE status IS NULL OR status = ''")
        if try db.tableExists("document_search") {
            try db.execute(sql: "DELETE FROM document_search WHERE documentId IN (SELECT id FROM documents WHERE status != 'active')")
        }
        if try db.tableExists("globalSearchRecords") {
            try recreateGlobalSearchDocumentTriggers(db)
            try backfillGlobalSearchIndex(db)
        }
    }

    migrator.registerMigration(AlpenLedgerDatabaseMigrations.v21AccountOpeningBalances) { db in
        guard try db.tableExists("financialAccounts") else {
            return
        }
        let columns = try Set(db.columns(in: "financialAccounts").map(\.name))
        if columns.contains("openingBalanceMinor") == false {
            try db.alter(table: "financialAccounts") { table in
                table.add(column: "openingBalanceMinor", .integer)
            }
        }
        if columns.contains("openingBalanceDate") == false {
            try db.alter(table: "financialAccounts") { table in
                table.add(column: "openingBalanceDate", .datetime)
            }
        }
    }

    return migrator
}

func migrate(dbPool: DatabasePool) throws {
    try makeAlpenLedgerDatabaseMigrator().migrate(dbPool)
}

private func backfillCounterparties(_ db: Database) throws {
    let now = ISO8601DateFormatter().string(from: Date())
    let rows = try Row.fetchAll(
        db,
        sql: """
        SELECT
            financialAccounts.entityId AS entityId,
            TRIM(transactions.counterpartyName) AS displayName,
            LOWER(TRIM(transactions.counterpartyName)) AS normalizedName
        FROM transactions
        JOIN financialAccounts ON financialAccounts.id = transactions.accountId
        WHERE TRIM(transactions.counterpartyName) <> ''
        GROUP BY financialAccounts.entityId, LOWER(TRIM(transactions.counterpartyName))
        ORDER BY financialAccounts.entityId, LOWER(TRIM(transactions.counterpartyName))
        """
    )

    for row in rows {
        let entityId: String = row["entityId"]
        let displayName: String = row["displayName"]
        let normalizedName: String = row["normalizedName"]
        try db.execute(
            sql: """
            INSERT OR IGNORE INTO counterparties (
                id,
                entityId,
                displayName,
                normalizedName,
                status,
                mergedIntoCounterpartyId,
                createdAt,
                updatedAt
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                UUID().uuidString.lowercased(),
                entityId,
                displayName,
                normalizedName,
                "active",
                nil,
                now,
                now,
            ]
        )
    }

    try db.execute(sql: """
    UPDATE transactions
    SET counterpartyId = (
        SELECT counterparties.id
        FROM counterparties
        JOIN financialAccounts ON financialAccounts.entityId = counterparties.entityId
        WHERE financialAccounts.id = transactions.accountId
          AND counterparties.normalizedName = LOWER(TRIM(transactions.counterpartyName))
        LIMIT 1
    )
    WHERE counterpartyId IS NULL
      AND TRIM(counterpartyName) <> ''
    """)
}

private func createReportingViews(_ db: Database) throws {
    try db.execute(sql: """
    CREATE VIEW IF NOT EXISTS vw_spend_by_month AS
    SELECT
        legalEntities.workspaceId AS workspaceId,
        financialAccounts.entityId AS entityId,
        substr(CAST(transactions.bookingDate AS TEXT), 1, 7) AS yearMonth,
        transactions.currency AS currency,
        SUM(-transactions.amountMinor) AS spendMinor,
        COUNT(transactions.id) AS transactionCount
    FROM transactions
    JOIN financialAccounts ON financialAccounts.id = transactions.accountId
    JOIN legalEntities ON legalEntities.id = financialAccounts.entityId
    WHERE transactions.amountMinor < 0
    GROUP BY
        legalEntities.workspaceId,
        financialAccounts.entityId,
        yearMonth,
        transactions.currency
    """)

    try db.execute(sql: """
    CREATE VIEW IF NOT EXISTS vw_cashflow_by_entity AS
    SELECT
        legalEntities.workspaceId AS workspaceId,
        financialAccounts.entityId AS entityId,
        substr(CAST(transactions.bookingDate AS TEXT), 1, 7) AS yearMonth,
        transactions.currency AS currency,
        SUM(CASE WHEN transactions.amountMinor > 0 THEN transactions.amountMinor ELSE 0 END) AS inflowMinor,
        SUM(CASE WHEN transactions.amountMinor < 0 THEN -transactions.amountMinor ELSE 0 END) AS outflowMinor,
        SUM(transactions.amountMinor) AS netMinor,
        COUNT(transactions.id) AS transactionCount
    FROM transactions
    JOIN financialAccounts ON financialAccounts.id = transactions.accountId
    JOIN legalEntities ON legalEntities.id = financialAccounts.entityId
    GROUP BY
        legalEntities.workspaceId,
        financialAccounts.entityId,
        yearMonth,
        transactions.currency
    """)

    try db.execute(sql: """
    CREATE VIEW IF NOT EXISTS vw_missing_evidence AS
    SELECT
        issues.id AS issueId,
        issues.workspaceId AS workspaceId,
        issues.entityId AS entityId,
        issues.taxYearId AS taxYearId,
        issues.issueCode AS issueCode,
        issues.severity AS severity,
        issues.status AS status,
        issues.summary AS summary,
        issues.objectRef AS objectRef,
        issues.relatedRef AS relatedRef,
        issues.firstDetectedAt AS firstDetectedAt,
        issues.lastDetectedAt AS lastDetectedAt
    FROM issues
    WHERE issues.status = 'open'
      AND issues.issueCode IN ('missingStatementCoverage', 'missingExpenseEvidence')
    """)

    try db.execute(sql: """
    CREATE VIEW IF NOT EXISTS vw_statement_coverage AS
    SELECT
        statementImports.id AS statementImportId,
        legalEntities.workspaceId AS workspaceId,
        financialAccounts.entityId AS entityId,
        statementImports.accountId AS accountId,
        financialAccounts.displayName AS accountDisplayName,
        statementImports.coverageStart AS coverageStart,
        statementImports.coverageEnd AS coverageEnd,
        statementImports.openingBalanceMinor AS openingBalanceMinor,
        statementImports.closingBalanceMinor AS closingBalanceMinor,
        statementImports.sourceFormat AS sourceFormat,
        statementImports.status AS status,
        statementImports.importJobId AS importJobId
    FROM statementImports
    JOIN financialAccounts ON financialAccounts.id = statementImports.accountId
    JOIN legalEntities ON legalEntities.id = financialAccounts.entityId
    """)

    try db.execute(sql: """
    CREATE VIEW IF NOT EXISTS vw_tax_fact_status AS
    SELECT
        taxFacts.id AS taxFactId,
        legalEntities.workspaceId AS workspaceId,
        taxFacts.entityId AS entityId,
        taxFacts.taxYearId AS taxYearId,
        taxFacts.jurisdictionCode AS jurisdictionCode,
        taxFacts.conceptCode AS conceptCode,
        taxFacts.valueType AS valueType,
        taxFacts.moneyMinor AS moneyMinor,
        taxFacts.textValue AS textValue,
        taxFacts.boolValue AS boolValue,
        taxFacts.dateValue AS dateValue,
        taxFacts.currency AS currency,
        taxFacts.status AS status,
        taxFacts.rulesetVersion AS rulesetVersion,
        taxFacts.confidence AS confidence,
        taxFacts.isCurrent AS isCurrent,
        taxFacts.supersedesFactId AS supersedesFactId,
        taxFacts.updatedAt AS updatedAt
    FROM taxFacts
    JOIN legalEntities ON legalEntities.id = taxFacts.entityId
    WHERE taxFacts.isCurrent = 1
    """)

    try db.execute(sql: """
    CREATE VIEW IF NOT EXISTS vw_unmatched_transactions AS
    SELECT
        transactions.id AS transactionId,
        legalEntities.workspaceId AS workspaceId,
        financialAccounts.entityId AS entityId,
        transactions.accountId AS accountId,
        transactions.statementImportId AS statementImportId,
        transactions.bookingDate AS bookingDate,
        transactions.valueDate AS valueDate,
        transactions.amountMinor AS amountMinor,
        transactions.currency AS currency,
        transactions.counterpartyName AS counterpartyName,
        transactions.counterpartyId AS counterpartyId,
        transactions.memo AS memo,
        transactions.reference AS reference,
        transactions.taxCode AS taxCode,
        transactions.reviewState AS reviewState
    FROM transactions
    JOIN financialAccounts ON financialAccounts.id = transactions.accountId
    JOIN legalEntities ON legalEntities.id = financialAccounts.entityId
    WHERE NOT EXISTS (
        SELECT 1
        FROM evidenceLinks
        WHERE evidenceLinks.status = 'confirmed'
          AND evidenceLinks.linkType = 'documentToTransaction'
          AND (
              evidenceLinks.sourceRef = 'transaction|' || transactions.id
              OR evidenceLinks.targetRef = 'transaction|' || transactions.id
          )
    )
    """)

    try db.execute(sql: """
    CREATE VIEW IF NOT EXISTS vw_vat_reconciliation AS
    SELECT
        vatPeriods.id AS vatPeriodId,
        legalEntities.workspaceId AS workspaceId,
        vatPeriods.entityId AS entityId,
        vatPeriods.periodStart AS periodStart,
        vatPeriods.periodEnd AS periodEnd,
        vatPeriods.currency AS currency,
        vatPeriods.status AS status,
        COUNT(transactions.id) AS transactionCount,
        SUM(CASE WHEN transactions.id IS NOT NULL AND (transactions.taxCode IS NULL OR transactions.taxCode = '') THEN 1 ELSE 0 END) AS missingTaxCodeCount,
        SUM(CASE WHEN transactions.amountMinor > 0 THEN transactions.amountMinor ELSE 0 END) AS outputBaseMinor,
        SUM(CASE WHEN transactions.amountMinor < 0 THEN -transactions.amountMinor ELSE 0 END) AS inputBaseMinor,
        SUM(CASE WHEN transactions.amountMinor IS NOT NULL THEN transactions.amountMinor ELSE 0 END) AS netCashflowMinor
    FROM vatPeriods
    JOIN legalEntities ON legalEntities.id = vatPeriods.entityId
    LEFT JOIN financialAccounts ON financialAccounts.entityId = vatPeriods.entityId
    LEFT JOIN transactions ON transactions.accountId = financialAccounts.id
        AND transactions.currency = vatPeriods.currency
        AND transactions.bookingDate >= vatPeriods.periodStart
        AND transactions.bookingDate <= vatPeriods.periodEnd
    GROUP BY
        vatPeriods.id,
        legalEntities.workspaceId,
        vatPeriods.entityId,
        vatPeriods.periodStart,
        vatPeriods.periodEnd,
        vatPeriods.currency,
        vatPeriods.status
    """)
}

private func createGlobalSearchIndex(_ db: Database) throws {
    try db.create(table: "globalSearchRecords", ifNotExists: true) { table in
        table.column("objectRef", .text).primaryKey()
        table.column("workspaceId", .text).notNull()
        table.column("entityId", .text)
        table.column("objectKind", .text).notNull()
        table.column("title", .text).notNull()
        table.column("subtitle", .text)
        table.column("content", .text).notNull()
    }
    try db.create(index: "globalSearchRecords_workspace", on: "globalSearchRecords", columns: ["workspaceId"], ifNotExists: true)
    try db.create(index: "globalSearchRecords_entity", on: "globalSearchRecords", columns: ["entityId"], ifNotExists: true)

    try db.execute(sql: """
    CREATE VIRTUAL TABLE IF NOT EXISTS global_search
    USING fts5(title, subtitle, content, content='globalSearchRecords', content_rowid='rowid')
    """)

    try createGlobalSearchDocumentTriggers(db)

    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_transactions_ai
    AFTER INSERT ON transactions
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'transaction|' || NEW.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'transaction|' || NEW.id;
        INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
        SELECT
            'transaction|' || NEW.id,
            legalEntities.workspaceId,
            financialAccounts.entityId,
            'transaction',
            CASE WHEN TRIM(NEW.counterpartyName) = '' THEN 'Transaction' ELSE NEW.counterpartyName END,
            NEW.currency || ' ' || NEW.amountMinor || ' ' || NEW.reviewState,
            COALESCE(NEW.memo, '') || ' ' ||
                COALESCE(NEW.reference, '') || ' ' ||
                COALESCE(NEW.sourceLineRef, '') || ' ' ||
                COALESCE(NEW.counterpartyName, '') || ' ' ||
                COALESCE(NEW.taxCode, '')
        FROM financialAccounts
        JOIN legalEntities ON legalEntities.id = financialAccounts.entityId
        WHERE financialAccounts.id = NEW.accountId;
        INSERT INTO global_search(rowid, title, subtitle, content)
        SELECT rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'transaction|' || NEW.id;
    END
    """)
    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_transactions_au
    AFTER UPDATE ON transactions
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'transaction|' || NEW.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'transaction|' || NEW.id;
        INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
        SELECT
            'transaction|' || NEW.id,
            legalEntities.workspaceId,
            financialAccounts.entityId,
            'transaction',
            CASE WHEN TRIM(NEW.counterpartyName) = '' THEN 'Transaction' ELSE NEW.counterpartyName END,
            NEW.currency || ' ' || NEW.amountMinor || ' ' || NEW.reviewState,
            COALESCE(NEW.memo, '') || ' ' ||
                COALESCE(NEW.reference, '') || ' ' ||
                COALESCE(NEW.sourceLineRef, '') || ' ' ||
                COALESCE(NEW.counterpartyName, '') || ' ' ||
                COALESCE(NEW.taxCode, '')
        FROM financialAccounts
        JOIN legalEntities ON legalEntities.id = financialAccounts.entityId
        WHERE financialAccounts.id = NEW.accountId;
        INSERT INTO global_search(rowid, title, subtitle, content)
        SELECT rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'transaction|' || NEW.id;
    END
    """)
    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_transactions_ad
    AFTER DELETE ON transactions
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'transaction|' || OLD.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'transaction|' || OLD.id;
    END
    """)

    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_counterparties_ai
    AFTER INSERT ON counterparties
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'counterparty|' || NEW.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'counterparty|' || NEW.id;
        INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
        SELECT
            'counterparty|' || NEW.id,
            legalEntities.workspaceId,
            NEW.entityId,
            'counterparty',
            NEW.displayName,
            NEW.status,
            NEW.displayName || ' ' || NEW.normalizedName || ' ' || COALESCE(NEW.mergedIntoCounterpartyId, '')
        FROM legalEntities
        WHERE legalEntities.id = NEW.entityId;
        INSERT INTO global_search(rowid, title, subtitle, content)
        SELECT rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'counterparty|' || NEW.id;
    END
    """)
    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_counterparties_au
    AFTER UPDATE ON counterparties
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'counterparty|' || NEW.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'counterparty|' || NEW.id;
        INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
        SELECT
            'counterparty|' || NEW.id,
            legalEntities.workspaceId,
            NEW.entityId,
            'counterparty',
            NEW.displayName,
            NEW.status,
            NEW.displayName || ' ' || NEW.normalizedName || ' ' || COALESCE(NEW.mergedIntoCounterpartyId, '')
        FROM legalEntities
        WHERE legalEntities.id = NEW.entityId;
        INSERT INTO global_search(rowid, title, subtitle, content)
        SELECT rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'counterparty|' || NEW.id;
    END
    """)
    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_counterparties_ad
    AFTER DELETE ON counterparties
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'counterparty|' || OLD.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'counterparty|' || OLD.id;
    END
    """)

    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_issues_ai
    AFTER INSERT ON issues
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'issue|' || NEW.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'issue|' || NEW.id;
        INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
        VALUES (
            'issue|' || NEW.id,
            NEW.workspaceId,
            NEW.entityId,
            'issue',
            NEW.summary,
            NEW.issueCode || ' ' || NEW.severity || ' ' || NEW.status,
            NEW.summary || ' ' || NEW.objectRef || ' ' || COALESCE(NEW.relatedRef, '')
        );
        INSERT INTO global_search(rowid, title, subtitle, content)
        SELECT rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'issue|' || NEW.id;
    END
    """)
    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_issues_au
    AFTER UPDATE ON issues
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'issue|' || NEW.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'issue|' || NEW.id;
        INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
        VALUES (
            'issue|' || NEW.id,
            NEW.workspaceId,
            NEW.entityId,
            'issue',
            NEW.summary,
            NEW.issueCode || ' ' || NEW.severity || ' ' || NEW.status,
            NEW.summary || ' ' || NEW.objectRef || ' ' || COALESCE(NEW.relatedRef, '')
        );
        INSERT INTO global_search(rowid, title, subtitle, content)
        SELECT rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'issue|' || NEW.id;
    END
    """)
    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_issues_ad
    AFTER DELETE ON issues
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'issue|' || OLD.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'issue|' || OLD.id;
    END
    """)

    try backfillGlobalSearchIndex(db)
}

private func createGlobalSearchDocumentTriggers(_ db: Database) throws {
    let hasDocumentStatus = try db.columns(in: "documents").contains { $0.name == "status" }
    let activeStatusFilter = hasDocumentStatus ? "WHERE NEW.status = 'active'" : ""
    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_documents_ai
    AFTER INSERT ON documents
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'document|' || NEW.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'document|' || NEW.id;
        INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
        SELECT
            'document|' || NEW.id,
            NEW.workspaceId,
            COALESCE(NEW.entityId, NEW.detectedEntityId),
            'document',
            NEW.originalFilename,
            NEW.documentType || ' ' || NEW.mediaType || ' ' || NEW.metadataStatus,
            COALESCE(NEW.extractedText, '') || ' ' || COALESCE(NEW.originalFilename, '')
        \(activeStatusFilter);
        INSERT INTO global_search(rowid, title, subtitle, content)
        SELECT rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'document|' || NEW.id;
    END
    """)
    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_documents_au
    AFTER UPDATE ON documents
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'document|' || NEW.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'document|' || NEW.id;
        INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
        SELECT
            'document|' || NEW.id,
            NEW.workspaceId,
            COALESCE(NEW.entityId, NEW.detectedEntityId),
            'document',
            NEW.originalFilename,
            NEW.documentType || ' ' || NEW.mediaType || ' ' || NEW.metadataStatus,
            COALESCE(NEW.extractedText, '') || ' ' || COALESCE(NEW.originalFilename, '')
        \(activeStatusFilter);
        INSERT INTO global_search(rowid, title, subtitle, content)
        SELECT rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'document|' || NEW.id;
    END
    """)
    try db.execute(sql: """
    CREATE TRIGGER IF NOT EXISTS global_search_documents_ad
    AFTER DELETE ON documents
    BEGIN
        INSERT INTO global_search(global_search, rowid, title, subtitle, content)
        SELECT 'delete', rowid, title, subtitle, content
        FROM globalSearchRecords
        WHERE objectRef = 'document|' || OLD.id;
        DELETE FROM globalSearchRecords WHERE objectRef = 'document|' || OLD.id;
    END
    """)
}

private func recreateGlobalSearchDocumentTriggers(_ db: Database) throws {
    try db.execute(sql: "DROP TRIGGER IF EXISTS global_search_documents_ai")
    try db.execute(sql: "DROP TRIGGER IF EXISTS global_search_documents_au")
    try db.execute(sql: "DROP TRIGGER IF EXISTS global_search_documents_ad")
    try createGlobalSearchIndex(db)
}

private func backfillGlobalSearchIndex(_ db: Database) throws {
    try db.execute(sql: "DELETE FROM globalSearchRecords")
    let hasDocumentStatus = try db.columns(in: "documents").contains { $0.name == "status" }
    let documentStatusFilter = hasDocumentStatus ? "WHERE documents.status = 'active'" : ""

    try db.execute(sql: """
    INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
    SELECT
        'document|' || documents.id,
        documents.workspaceId,
        COALESCE(documents.entityId, documents.detectedEntityId),
        'document',
        documents.originalFilename,
        documents.documentType || ' ' || documents.mediaType || ' ' || documents.metadataStatus,
        COALESCE(documents.extractedText, '') || ' ' || COALESCE(documents.originalFilename, '')
    FROM documents
    \(documentStatusFilter)
    """)

    try db.execute(sql: """
    INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
    SELECT
        'transaction|' || transactions.id,
        legalEntities.workspaceId,
        financialAccounts.entityId,
        'transaction',
        CASE WHEN TRIM(transactions.counterpartyName) = '' THEN 'Transaction' ELSE transactions.counterpartyName END,
        transactions.currency || ' ' || transactions.amountMinor || ' ' || transactions.reviewState,
        COALESCE(transactions.memo, '') || ' ' ||
            COALESCE(transactions.reference, '') || ' ' ||
            COALESCE(transactions.sourceLineRef, '') || ' ' ||
            COALESCE(transactions.counterpartyName, '') || ' ' ||
            COALESCE(transactions.taxCode, '')
    FROM transactions
    JOIN financialAccounts ON financialAccounts.id = transactions.accountId
    JOIN legalEntities ON legalEntities.id = financialAccounts.entityId
    """)

    try db.execute(sql: """
    INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
    SELECT
        'counterparty|' || counterparties.id,
        legalEntities.workspaceId,
        counterparties.entityId,
        'counterparty',
        counterparties.displayName,
        counterparties.status,
        counterparties.displayName || ' ' ||
            counterparties.normalizedName || ' ' ||
            COALESCE(counterparties.mergedIntoCounterpartyId, '')
    FROM counterparties
    JOIN legalEntities ON legalEntities.id = counterparties.entityId
    """)

    try db.execute(sql: """
    INSERT INTO globalSearchRecords(objectRef, workspaceId, entityId, objectKind, title, subtitle, content)
    SELECT
        'issue|' || issues.id,
        issues.workspaceId,
        issues.entityId,
        'issue',
        issues.summary,
        issues.issueCode || ' ' || issues.severity || ' ' || issues.status,
        issues.summary || ' ' || issues.objectRef || ' ' || COALESCE(issues.relatedRef, '')
    FROM issues
    """)

    try db.execute(sql: "INSERT INTO global_search(global_search) VALUES ('rebuild')")
}
