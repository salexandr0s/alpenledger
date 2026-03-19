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

    try migrator.migrate(dbPool)
}
