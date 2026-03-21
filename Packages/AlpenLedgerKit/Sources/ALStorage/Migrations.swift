import Foundation
import GRDB

func migrate(dbPool: DatabasePool) throws {
    var migrator = DatabaseMigrator()

    migrator.registerMigration("v1_core") { db in
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

    migrator.registerMigration("v2_evidence_inbox") { db in
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
            table.column("summary", .text).notNull()
            table.column("rationale", .text).notNull()
            table.column("confidence", .double).notNull()
            table.column("status", .text).notNull()
            table.column("createdAt", .datetime).notNull()
            table.column("decidedAt", .datetime)
        }
        try db.create(index: "agentProposals_fingerprint", on: "agentProposals", columns: ["fingerprint"], unique: true, ifNotExists: true)
        try db.create(index: "agentProposals_workspace_status", on: "agentProposals", columns: ["workspaceId", "status"], ifNotExists: true)
    }

    migrator.registerMigration("v3_tax_facts") { db in
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

    migrator.registerMigration("v4_performance_indexes") { db in
        try db.create(index: "transactions_account_bookingDate", on: "transactions", columns: ["accountId", "bookingDate"], ifNotExists: true)
        try db.create(index: "evidenceLinks_sourceRef", on: "evidenceLinks", columns: ["sourceRef"], ifNotExists: true)
        try db.create(index: "evidenceLinks_targetRef", on: "evidenceLinks", columns: ["targetRef"], ifNotExists: true)
        try db.create(index: "auditEvents_workspace_occurredAt", on: "auditEvents", columns: ["workspaceId", "occurredAt"], ifNotExists: true)
    }

    migrator.registerMigration("v5_entity_workspace_and_models") { db in
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
        let rows = try Row.fetchAll(db, sql: "SELECT id, workspaceId, displayName FROM legalEntities")
        for row in rows {
            let entityId: String = row["id"]
            let workspaceId: String = row["workspaceId"]
            let displayName: String = row["displayName"]
            let ewId = UUID().uuidString.lowercased()
            try db.execute(
                sql: """
                INSERT INTO entityWorkspaces (id, workspaceId, entityId, displayName, isDefault, lastAccessedAt, createdAt)
                VALUES (?, ?, ?, ?, 1, ?, ?)
                """,
                arguments: [ewId, workspaceId, entityId, displayName, now, now]
            )
        }
    }

    try migrator.migrate(dbPool)
}
