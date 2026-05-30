import Foundation
import GRDB
import Testing
@testable import ALDomain
@testable import ALStorage

@Test
func databaseMigrationsCreateRequiredSchemaFromEmptyDatabase() throws {
    let database = try makeMigrationTestDatabase()
    try makeAlpenLedgerDatabaseMigrator().migrate(database.dbPool)

    try database.dbPool.read { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        for tableName in AlpenLedgerDatabaseMigrations.requiredTables {
            #expect(try db.tableExists(tableName))
        }

        let viewNames = try Set(String.fetchAll(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'view'"
        ))
        #expect(viewNames.isSuperset(of: AlpenLedgerDatabaseMigrations.requiredViews))

        let documentColumns = try columnNames(in: "documents", db: db)
        #expect(documentColumns.contains("entityId"))
        #expect(documentColumns.isSuperset(of: [
            "status",
            "archivedAt",
            "archivedBy",
            "archiveReason",
        ]))

        let transactionColumns = try columnNames(in: "transactions", db: db)
        #expect(transactionColumns.contains("taxCode"))
        #expect(transactionColumns.contains("counterpartyId"))

        let counterpartyColumns = try columnNames(in: "counterparties", db: db)
        #expect(counterpartyColumns.isSuperset(of: [
            "id",
            "entityId",
            "displayName",
            "normalizedName",
            "status",
            "mergedIntoCounterpartyId",
        ]))

        let globalSearchRecordColumns = try columnNames(in: "globalSearchRecords", db: db)
        #expect(globalSearchRecordColumns.isSuperset(of: [
            "objectRef",
            "workspaceId",
            "entityId",
            "objectKind",
            "title",
            "subtitle",
            "content",
        ]))

        let vatPeriodColumns = try columnNames(in: "vatPeriods", db: db)
        #expect(vatPeriodColumns.isSuperset(of: [
            "id",
            "entityId",
            "periodStart",
            "periodEnd",
            "currency",
            "status",
        ]))

        let filingPackageColumns = try columnNames(in: "filingPackages", db: db)
        #expect(filingPackageColumns.contains("finalizedAt"))
        #expect(filingPackageColumns.contains("finalizedBy"))

        let journalEntryColumns = try columnNames(in: "journalEntries", db: db)
        #expect(journalEntryColumns.isSuperset(of: [
            "id",
            "entityId",
            "taxYearId",
            "entryNumber",
            "effectiveDate",
            "status",
            "approvedBy",
            "approvedAt",
        ]))

        let journalLineColumns = try columnNames(in: "journalLines", db: db)
        #expect(journalLineColumns.isSuperset(of: [
            "id",
            "journalEntryId",
            "ledgerAccountId",
            "debitMinor",
            "creditMinor",
            "currency",
            "sourceObjectRef",
        ]))

        let proposalColumns = try columnNames(in: "agentProposals", db: db)
        #expect(proposalColumns.contains("relatedRef"))
        #expect(proposalColumns.contains("decidedBy"))
        #expect(proposalColumns.contains("decisionReason"))
        #expect(proposalColumns.contains("missingFields"))
        #expect(proposalColumns.contains("question"))
        #expect(proposalColumns.contains("requiresManualReview"))

        let conversationColumns = try columnNames(in: "agentConversations", db: db)
        #expect(conversationColumns.isSuperset(of: [
            "id",
            "workspaceId",
            "title",
            "activeEntityId",
            "activeTaxYearId",
            "status",
            "createdAt",
            "updatedAt",
        ]))

        let messageColumns = try columnNames(in: "agentMessages", db: db)
        #expect(messageColumns.isSuperset(of: [
            "id",
            "conversationId",
            "role",
            "content",
            "sourceRefs",
            "unresolvedQuestions",
            "providerID",
            "promptTemplateID",
            "sentDataOffDevice",
            "createdAt",
        ]))

        let pendingApprovalColumns = try columnNames(in: "agentPendingApprovals", db: db)
        #expect(pendingApprovalColumns.isSuperset(of: [
            "id",
            "conversationId",
            "toolName",
            "inputHash",
            "inputSummary",
            "requiredScopes",
            "targetRefs",
            "status",
            "requestedBy",
            "requestedAt",
            "decidedBy",
            "decidedAt",
            "decisionReason",
        ]))

        let agentRunColumns = try columnNames(in: "agentRuns", db: db)
        #expect(agentRunColumns.isSuperset(of: [
            "id",
            "conversationId",
            "userMessageId",
            "assistantMessageId",
            "status",
            "intent",
            "specialists",
            "plannedToolNames",
            "unavailableToolNames",
            "requiredScopes",
            "contextRefs",
            "clarificationQuestion",
            "rationale",
            "modelProviderID",
            "modelCapability",
            "promptTemplateID",
            "modelInputScope",
            "sentDataOffDevice",
            "toolCalls",
            "approvalDecisions",
            "errorCode",
            "startedAt",
            "finishedAt",
        ]))

        let importDiagnosticColumns = try columnNames(in: "importDiagnostics", db: db)
        #expect(importDiagnosticColumns.isSuperset(of: [
            "id",
            "importJobId",
            "severity",
            "code",
            "location",
            "message",
            "createdAt",
        ]))

        let importJobColumns = try columnNames(in: "importJobs", db: db)
        #expect(importJobColumns.isSuperset(of: [
            "sourceBlobHash",
            "sourceFingerprint",
        ]))

        let financialAccountColumns = try columnNames(in: "financialAccounts", db: db)
        #expect(financialAccountColumns.isSuperset(of: [
            "openingBalanceMinor",
            "openingBalanceDate",
        ]))

        let indexNames = try Set(String.fetchAll(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'index'"
        ))
        #expect(indexNames.isSuperset(of: [
            "statementImports_account_fingerprint",
            "agentConversations_workspace_status",
            "agentMessages_conversation_createdAt",
            "agentPendingApprovals_conversation_status",
            "agentPendingApprovals_tool_input_hash",
            "agentRuns_conversation_startedAt",
            "agentRuns_status",
            "documents_workspace_blobhash",
            "requirements_fingerprint",
            "issues_workspace_status",
            "agentProposals_workspace_status",
            "taxFacts_entity_taxYear_current",
            "transactions_account_bookingDate",
            "entityWorkspaces_workspace_entity",
            "taxProfiles_entity",
            "categories_entity_code",
            "counterparties_entity_normalized",
            "counterparties_entity_status",
            "counterparties_merged_into",
            "globalSearchRecords_workspace",
            "globalSearchRecords_entity",
            "importDiagnostics_importJob",
            "importDiagnostics_code",
            "importJobs_workspace_kind_sourceBlobHash",
            "importJobs_workspace_kind_sourceFingerprint",
            "invoiceRecords_entity",
            "filingPackages_entity_taxYear",
            "vatPeriods_entity_period",
            "journalEntries_entity_entryNumber",
            "journalEntries_entity_taxYear",
            "journalLines_entry",
            "journalLines_account",
        ]))

        let searchSQL = try String.fetchOne(
            db,
            sql: "SELECT sql FROM sqlite_master WHERE name = 'document_search'"
        )
        #expect(searchSQL?.contains("USING fts5") == true)

        let globalSearchSQL = try String.fetchOne(
            db,
            sql: "SELECT sql FROM sqlite_master WHERE name = 'global_search'"
        )
        #expect(globalSearchSQL?.contains("USING fts5") == true)
        #expect(globalSearchSQL?.contains("content='globalSearchRecords'") == true)
    }
}

@Test
func databaseMigrationsAreIdempotentAfterFullApplication() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()

    try migrator.migrate(database.dbPool)
    let schemaBefore = try schemaSnapshot(database.dbPool)

    try migrator.migrate(database.dbPool)
    let schemaAfter = try schemaSnapshot(database.dbPool)

    #expect(schemaAfter == schemaBefore)
    try database.dbPool.read { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)
    }
}

@Test
func databaseMigrationsBackfillLegacyV4WorkspaceData() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = UUID().uuidString.lowercased()
    let entityId = UUID().uuidString.lowercased()
    let documentId = UUID().uuidString.lowercased()
    let transactionId = UUID().uuidString.lowercased()

    try migrator.migrate(database.dbPool, upTo: AlpenLedgerDatabaseMigrations.v4PerformanceIndexes)
    try database.dbPool.write { db in
        #expect(try columnNames(in: "documents", db: db).contains("entityId") == false)
        #expect(try columnNames(in: "transactions", db: db).contains("counterpartyId") == false)
        try insertLegacyV4Rows(
            into: db,
            workspaceId: workspaceId,
            entityId: entityId,
            documentId: documentId,
            transactionId: transactionId
        )
    }

    try migrator.migrate(database.dbPool)

    try database.dbPool.read { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        let backfilledEntityId = try String.fetchOne(
            db,
            sql: "SELECT entityId FROM documents WHERE id = ?",
            arguments: [documentId]
        )
        #expect(backfilledEntityId == entityId)

        let entityWorkspaceCount = try Int.fetchOne(
            db,
            sql: """
            SELECT COUNT(*)
            FROM entityWorkspaces
            WHERE workspaceId = ? AND entityId = ? AND displayName = ? AND isDefault = 1
            """,
            arguments: [workspaceId, entityId, "Legacy Taxpayer"]
        )
        #expect(entityWorkspaceCount == 1)

        let proposalColumns = try columnNames(in: "agentProposals", db: db)
        #expect(proposalColumns.contains("relatedRef"))
        #expect(proposalColumns.contains("decidedBy"))
        #expect(proposalColumns.contains("decisionReason"))
        #expect(proposalColumns.contains("missingFields"))
        #expect(proposalColumns.contains("question"))
        #expect(proposalColumns.contains("requiresManualReview"))
        #expect(try db.tableExists("importDiagnostics"))
        #expect(try db.tableExists("agentConversations"))
        #expect(try db.tableExists("agentMessages"))
        #expect(try db.tableExists("agentPendingApprovals"))
        #expect(try db.tableExists("agentRuns"))
        let importJobColumns = try columnNames(in: "importJobs", db: db)
        #expect(importJobColumns.contains("sourceBlobHash"))
        #expect(importJobColumns.contains("sourceFingerprint"))

        let counterpartyRow = try Row.fetchOne(
            db,
            sql: """
            SELECT counterparties.displayName, counterparties.normalizedName
            FROM transactions
            JOIN counterparties ON counterparties.id = transactions.counterpartyId
            WHERE transactions.id = ?
            """,
            arguments: [transactionId]
        )
        let counterpartyDisplayName: String? = counterpartyRow?["displayName"]
        let counterpartyNormalizedName: String? = counterpartyRow?["normalizedName"]
        #expect(counterpartyDisplayName == "Legacy Supplier AG")
        #expect(counterpartyNormalizedName == "legacy supplier ag")
    }
}

@Test
func databaseMigrationsUpgradeLegacyV19DocumentArchiveState() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = UUID().uuidString.lowercased()
    let documentId = UUID().uuidString.lowercased()
    let createdAt = "2026-05-30T00:00:00Z"

    try migrator.migrate(database.dbPool, upTo: AlpenLedgerDatabaseMigrations.v19AgentRunTrace)
    try database.dbPool.write { db in
        #expect(try columnNames(in: "documents", db: db).contains("status") == false)
        try db.execute(
            sql: """
            INSERT INTO workspaces (id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                workspaceId,
                "Legacy V19 Archive State",
                19,
                createdAt,
                "CHF",
                "localOnly",
                "workspace.json",
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO documents (
                id, workspaceId, importJobId, blobHash, originalFilename, mediaType,
                origin, documentType, issueDate, detectedEntityId, detectedTaxYearId,
                extractedText, metadataStatus, parseVersion, entityId
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                documentId,
                workspaceId,
                nil,
                "legacy-v19-archive-document-blob",
                "legacy-v19-receipt.pdf",
                "application/pdf",
                "userImport",
                "receipt",
                nil,
                nil,
                nil,
                "Legacy V19 archive receipt search text",
                "confirmed",
                "v1",
                nil,
            ]
        )
    }

    try migrator.migrate(database.dbPool)

    try database.dbPool.write { db in
        let documentColumns = try columnNames(in: "documents", db: db)
        #expect(documentColumns.isSuperset(of: [
            "status",
            "archivedAt",
            "archivedBy",
            "archiveReason",
        ]))
        let status = try String.fetchOne(
            db,
            sql: "SELECT status FROM documents WHERE id = ?",
            arguments: [documentId]
        )
        #expect(status == "active")
        let activeSearchRecordCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM globalSearchRecords WHERE objectRef = ?",
            arguments: ["document|\(documentId)"]
        )
        #expect(activeSearchRecordCount == 1)

        try db.execute(
            sql: """
            UPDATE documents
            SET status = 'archived', archivedAt = ?, archivedBy = ?, archiveReason = ?
            WHERE id = ?
            """,
            arguments: [createdAt, "reviewer", "Legacy archive migration test.", documentId]
        )
        let archivedSearchRecordCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM globalSearchRecords WHERE objectRef = ?",
            arguments: ["document|\(documentId)"]
        )
        #expect(archivedSearchRecordCount == 0)
    }
}

@Test
func databaseMigrationsUpgradeLegacyV20FinancialAccountOpeningBalances() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = UUID().uuidString.lowercased()
    let entityId = UUID().uuidString.lowercased()
    let ledgerAccountId = UUID().uuidString.lowercased()
    let financialAccountId = UUID().uuidString.lowercased()
    let createdAt = Date(timeIntervalSinceReferenceDate: 800_000_000)

    try migrator.migrate(database.dbPool, upTo: AlpenLedgerDatabaseMigrations.v20DocumentArchiveState)
    try database.dbPool.write { db in
        let financialAccountColumns = try columnNames(in: "financialAccounts", db: db)
        #expect(financialAccountColumns.contains("openingBalanceMinor") == false)
        #expect(financialAccountColumns.contains("openingBalanceDate") == false)
        try db.execute(
            sql: """
            INSERT INTO workspaces (id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                workspaceId,
                "Legacy V20 Opening Balance",
                20,
                createdAt,
                "CHF",
                "localOnly",
                "workspace.json",
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO legalEntities (
                id, workspaceId, kind, legalName, displayName, country, canton,
                taxIdOrUID, fiscalYearStartMonth, fiscalYearStartDay, parentEntityId
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                entityId,
                workspaceId,
                "naturalPerson",
                "Legacy Person",
                "Legacy Person",
                "CH",
                "ZH",
                nil,
                1,
                1,
                nil,
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO ledgerAccounts (
                id, entityId, code, name, category, normalBalance, parentId, taxRole, isControlAccount
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                ledgerAccountId,
                entityId,
                "1000",
                "Legacy Bank",
                "asset",
                "debit",
                nil,
                nil,
                true,
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO financialAccounts (
                id, entityId, accountType, institutionName, displayName, currency,
                ibanMask, statementCadence, ledgerControlAccountId, openedAt, closedAt
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                financialAccountId,
                entityId,
                "bank",
                "Legacy Bank",
                "Legacy Bank",
                "CHF",
                nil,
                "monthly",
                ledgerAccountId,
                createdAt,
                nil,
            ]
        )
    }

    try migrator.migrate(database.dbPool)

    let repository = GRDBFinancialAccountRepository(dbPool: database.dbPool)
    var account = try #require(try repository.fetchFinancialAccount(id: FinancialAccountID(rawValue: UUID(uuidString: financialAccountId)!)))
    #expect(account.openingBalanceMinor == nil)
    #expect(account.openingBalanceDate == nil)

    let openingBalanceDate = Date(timeIntervalSinceReferenceDate: 800_086_400)
    account.openingBalanceMinor = 123_456
    account.openingBalanceDate = openingBalanceDate
    try repository.saveFinancialAccount(account)

    let reloadedAccount = try #require(try repository.fetchFinancialAccount(id: account.id))
    #expect(reloadedAccount.openingBalanceMinor == 123_456)
    #expect(reloadedAccount.openingBalanceDate == openingBalanceDate)
}

@Test
func databaseMigrationsUpgradeLegacyV5AgentProposalMetadataPreservesPendingRows() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = WorkspaceID()
    let proposalId = AgentProposalID()
    let documentId = DocumentID()
    let transactionId = TransactionID()

    try migrator.migrate(database.dbPool, upTo: AlpenLedgerDatabaseMigrations.v5EntityWorkspaceAndModels)
    try database.dbPool.write { db in
        try installLegacyV5AgentProposalTable(
            into: db,
            workspaceId: workspaceId.description,
            proposalId: proposalId.description,
            documentId: documentId.description
        )

        let proposalColumns = try columnNames(in: "agentProposals", db: db)
        #expect(proposalColumns.contains("relatedRef") == false)
        #expect(proposalColumns.contains("decidedBy") == false)
        #expect(proposalColumns.contains("decisionReason") == false)
        #expect(proposalColumns.contains("missingFields") == false)
        #expect(proposalColumns.contains("question") == false)
        #expect(proposalColumns.contains("requiresManualReview") == false)
    }

    try migrator.migrate(database.dbPool)

    let proposalRepository = GRDBAgentProposalRepository(dbPool: database.dbPool)
    var migratedProposal = try #require(try proposalRepository.fetchAgentProposal(id: proposalId))
    #expect(migratedProposal.fingerprint == "legacy-v5-proposal:document-link")
    #expect(migratedProposal.workspaceId == workspaceId)
    #expect(migratedProposal.agentKind == .systemHeuristics)
    #expect(migratedProposal.proposalType == .documentLinkReview)
    #expect(migratedProposal.targetRef == ObjectRef(kind: .document, id: documentId.description))
    #expect(migratedProposal.relatedRef == nil)
    #expect(migratedProposal.summary == "Legacy v5 document match proposal.")
    #expect(migratedProposal.rationale == "Created before decision, related-ref, and uncertainty metadata existed.")
    #expect(migratedProposal.confidence == 0.74)
    #expect(migratedProposal.missingFields == [])
    #expect(migratedProposal.question == nil)
    #expect(migratedProposal.requiresManualReview == false)
    #expect(migratedProposal.status == .pending)
    #expect(migratedProposal.decidedAt == nil)
    #expect(migratedProposal.decidedBy == nil)
    #expect(migratedProposal.decisionReason == nil)

    migratedProposal.relatedRef = ObjectRef(kind: .transaction, id: transactionId.description)
    migratedProposal.missingFields = ["counterpartyName"]
    migratedProposal.question = "Which imported transaction belongs to this document?"
    migratedProposal.requiresManualReview = true
    migratedProposal.status = .rejected
    migratedProposal.decidedAt = Date(timeIntervalSinceReferenceDate: 800_010_000)
    migratedProposal.decidedBy = "migration-test-reviewer"
    migratedProposal.decisionReason = "Rejected during migration repository round-trip."
    try proposalRepository.saveAgentProposal(migratedProposal)

    let updatedProposal = try #require(try proposalRepository.fetchAgentProposal(fingerprint: "legacy-v5-proposal:document-link"))
    #expect(updatedProposal.relatedRef == ObjectRef(kind: .transaction, id: transactionId.description))
    #expect(updatedProposal.missingFields == ["counterpartyName"])
    #expect(updatedProposal.question == "Which imported transaction belongs to this document?")
    #expect(updatedProposal.requiresManualReview == true)
    #expect(updatedProposal.status == .rejected)
    #expect(updatedProposal.decidedBy == "migration-test-reviewer")
    #expect(updatedProposal.decisionReason == "Rejected during migration repository round-trip.")

    try database.dbPool.read { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        let proposalColumns = try columnNames(in: "agentProposals", db: db)
        #expect(proposalColumns.isSuperset(of: [
            "relatedRef",
            "decidedBy",
            "decisionReason",
            "missingFields",
            "question",
            "requiresManualReview",
        ]))

        let foreignKeyViolations = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pragma_foreign_key_check") ?? -1
        #expect(foreignKeyViolations == 0)
    }
}

@Test
func databaseMigrationsUpgradeLegacyV17AgentAndImportState() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = UUID().uuidString.lowercased()
    let entityId = UUID().uuidString.lowercased()
    let taxYearId = UUID().uuidString.lowercased()
    let importJobId = UUID().uuidString.lowercased()
    let conversationId = UUID().uuidString.lowercased()
    let userMessageId = UUID().uuidString.lowercased()
    let assistantMessageId = UUID().uuidString.lowercased()
    let pendingApprovalId = UUID().uuidString.lowercased()

    try database.dbPool.write { db in
        try installLegacyV17AgentAndImportRows(
            into: db,
            workspaceId: workspaceId,
            entityId: entityId,
            taxYearId: taxYearId,
            importJobId: importJobId,
            conversationId: conversationId,
            userMessageId: userMessageId,
            assistantMessageId: assistantMessageId,
            pendingApprovalId: pendingApprovalId
        )
    }

    try migrator.migrate(database.dbPool)

    try database.dbPool.write { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        let importJobColumns = try columnNames(in: "importJobs", db: db)
        #expect(importJobColumns.contains("sourceBlobHash"))
        #expect(importJobColumns.contains("sourceFingerprint"))

        let legacyImportJobRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT sourceBlobHash, sourceFingerprint
            FROM importJobs
            WHERE id = ?
            """,
            arguments: [importJobId]
        ))
        let migratedSourceBlobHash: String? = legacyImportJobRow["sourceBlobHash"]
        let migratedSourceFingerprint: String? = legacyImportJobRow["sourceFingerprint"]
        #expect(migratedSourceBlobHash == nil)
        #expect(migratedSourceFingerprint == nil)

        let conversationCount = try Int.fetchOne(
            db,
            sql: """
            SELECT COUNT(*)
            FROM agentConversations
            WHERE id = ? AND workspaceId = ? AND activeEntityId = ? AND activeTaxYearId = ?
            """,
            arguments: [conversationId, workspaceId, entityId, taxYearId]
        )
        #expect(conversationCount == 1)

        let messageRoles = try String.fetchAll(
            db,
            sql: """
            SELECT role
            FROM agentMessages
            WHERE conversationId = ?
            ORDER BY createdAt
            """,
            arguments: [conversationId]
        )
        #expect(messageRoles == ["user", "assistant"])

        let pendingApprovalRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT toolName, inputHash, requiredScopes, targetRefs, status
            FROM agentPendingApprovals
            WHERE id = ?
            """,
            arguments: [pendingApprovalId]
        ))
        let toolName: String = pendingApprovalRow["toolName"]
        let inputHash: String = pendingApprovalRow["inputHash"]
        let requiredScopes: String = pendingApprovalRow["requiredScopes"]
        let targetRefs: String = pendingApprovalRow["targetRefs"]
        let status: String = pendingApprovalRow["status"]
        #expect(toolName == "ledger.apply_draft_entry")
        #expect(inputHash == AgentToolInputHash.hash(Data(#"{"entryNumber":"JE-2026-099"}"#.utf8)))
        #expect(requiredScopes == #"["ledger.write"]"#)
        #expect(targetRefs == #"[{"kind":"taxYear","id":"\#(taxYearId)"}]"#)
        #expect(status == "pending")

        let indexNames = try Set(String.fetchAll(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'index'"
        ))
        #expect(indexNames.isSuperset(of: [
            "importJobs_workspace_kind_sourceBlobHash",
            "importJobs_workspace_kind_sourceFingerprint",
            "agentRuns_conversation_startedAt",
            "agentRuns_status",
        ]))

        let agentRunId = UUID().uuidString.lowercased()
        try db.execute(
            sql: """
            INSERT INTO agentRuns (
                id, conversationId, userMessageId, assistantMessageId,
                status, intent, startedAt
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                agentRunId,
                conversationId,
                userMessageId,
                assistantMessageId,
                "planned",
                "missingTaxEvidence",
                "2026-05-30T09:02:00Z",
            ]
        )

        let agentRunDefaults = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT specialists, plannedToolNames, unavailableToolNames,
                   requiredScopes, contextRefs, rationale, sentDataOffDevice,
                   toolCalls, approvalDecisions
            FROM agentRuns
            WHERE id = ?
            """,
            arguments: [agentRunId]
        ))
        let specialists: String = agentRunDefaults["specialists"]
        let plannedToolNames: String = agentRunDefaults["plannedToolNames"]
        let unavailableToolNames: String = agentRunDefaults["unavailableToolNames"]
        let requiredRunScopes: String = agentRunDefaults["requiredScopes"]
        let contextRefs: String = agentRunDefaults["contextRefs"]
        let rationale: String = agentRunDefaults["rationale"]
        let sentDataOffDevice: Bool = agentRunDefaults["sentDataOffDevice"]
        let toolCalls: String = agentRunDefaults["toolCalls"]
        let approvalDecisions: String = agentRunDefaults["approvalDecisions"]
        #expect(specialists == "[]")
        #expect(plannedToolNames == "[]")
        #expect(unavailableToolNames == "[]")
        #expect(requiredRunScopes == "[]")
        #expect(contextRefs == "[]")
        #expect(rationale == "")
        #expect(sentDataOffDevice == false)
        #expect(toolCalls == "[]")
        #expect(approvalDecisions == "[]")
    }
}

@Test
func databaseMigrationsUpgradeLegacyV9FilingPackageState() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = UUID().uuidString.lowercased()
    let entityId = UUID().uuidString.lowercased()
    let taxYearId = UUID().uuidString.lowercased()
    let filingPackageId = UUID().uuidString.lowercased()
    let vatPeriodId = UUID().uuidString.lowercased()

    try migrator.migrate(database.dbPool, upTo: AlpenLedgerDatabaseMigrations.v9VATPeriods)
    try database.dbPool.write { db in
        try replaceFilingPackagesWithLegacyV9Shape(db)
        #expect(try columnNames(in: "filingPackages", db: db).contains("finalizedAt") == false)
        #expect(try columnNames(in: "filingPackages", db: db).contains("finalizedBy") == false)

        try insertLegacyV9FilingPackageRows(
            into: db,
            workspaceId: workspaceId,
            entityId: entityId,
            taxYearId: taxYearId,
            filingPackageId: filingPackageId,
            vatPeriodId: vatPeriodId
        )
    }

    try migrator.migrate(database.dbPool)

    try database.dbPool.read { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        let filingPackageColumns = try columnNames(in: "filingPackages", db: db)
        #expect(filingPackageColumns.contains("finalizedAt"))
        #expect(filingPackageColumns.contains("finalizedBy"))

        let packageRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT status, generatedAt, finalizedAt, finalizedBy,
                   submittedAt, snapshotHash, exportFormat, createdAt, updatedAt
            FROM filingPackages
            WHERE id = ?
            """,
            arguments: [filingPackageId]
        ))
        let status: String = packageRow["status"]
        let generatedAt: String? = packageRow["generatedAt"]
        let finalizedAt: String? = packageRow["finalizedAt"]
        let finalizedBy: String? = packageRow["finalizedBy"]
        let submittedAt: String? = packageRow["submittedAt"]
        let snapshotHash: String? = packageRow["snapshotHash"]
        let exportFormat: String = packageRow["exportFormat"]
        let createdAt: String = packageRow["createdAt"]
        let updatedAt: String = packageRow["updatedAt"]
        #expect(status == "generated")
        #expect(generatedAt == "2026-03-31T18:00:00Z")
        #expect(finalizedAt == nil)
        #expect(finalizedBy == nil)
        #expect(submittedAt == nil)
        #expect(snapshotHash == "legacy-vat-package-sha256")
        #expect(exportFormat == "eCH-0217")
        #expect(createdAt == "2026-03-31T17:58:00Z")
        #expect(updatedAt == "2026-03-31T18:00:00Z")

        let vatPeriodCount = try Int.fetchOne(
            db,
            sql: """
            SELECT COUNT(*)
            FROM vatPeriods
            WHERE id = ? AND entityId = ? AND status = ?
            """,
            arguments: [vatPeriodId, entityId, "locked"]
        )
        #expect(vatPeriodCount == 1)

        let foreignKeyViolations = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pragma_foreign_key_check")
        #expect(foreignKeyViolations == 0)
    }
}

@Test
func databaseMigrationsUpgradeLegacyV10AccountingStateAddsJournalPostingTables() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = UUID().uuidString.lowercased()
    let entityId = UUID().uuidString.lowercased()
    let taxYearId = UUID().uuidString.lowercased()
    let bankLedgerAccountId = UUID().uuidString.lowercased()
    let revenueLedgerAccountId = UUID().uuidString.lowercased()
    let expenseLedgerAccountId = UUID().uuidString.lowercased()
    let transactionId = UUID().uuidString.lowercased()
    let filingPackageId = UUID().uuidString.lowercased()
    let vatPeriodId = UUID().uuidString.lowercased()
    let taxFactId = UUID().uuidString.lowercased()
    let journalEntryId = UUID().uuidString.lowercased()
    let debitLineId = UUID().uuidString.lowercased()
    let creditLineId = UUID().uuidString.lowercased()

    try migrator.migrate(database.dbPool, upTo: AlpenLedgerDatabaseMigrations.v10FilingPackageFinalization)
    try database.dbPool.write { db in
        #expect(try db.tableExists("journalEntries") == false)
        #expect(try db.tableExists("journalLines") == false)
        try insertLegacyV10AccountingRows(
            into: db,
            workspaceId: workspaceId,
            entityId: entityId,
            taxYearId: taxYearId,
            bankLedgerAccountId: bankLedgerAccountId,
            revenueLedgerAccountId: revenueLedgerAccountId,
            expenseLedgerAccountId: expenseLedgerAccountId,
            transactionId: transactionId,
            filingPackageId: filingPackageId,
            vatPeriodId: vatPeriodId,
            taxFactId: taxFactId
        )
    }

    try migrator.migrate(database.dbPool)

    try database.dbPool.write { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        let journalEntryColumns = try columnNames(in: "journalEntries", db: db)
        #expect(journalEntryColumns.isSuperset(of: [
            "id",
            "entityId",
            "taxYearId",
            "entryNumber",
            "effectiveDate",
            "kind",
            "status",
            "memo",
            "createdBy",
            "approvedBy",
            "approvedAt",
        ]))

        let journalLineColumns = try columnNames(in: "journalLines", db: db)
        #expect(journalLineColumns.isSuperset(of: [
            "id",
            "journalEntryId",
            "ledgerAccountId",
            "debitMinor",
            "creditMinor",
            "currency",
            "taxCode",
            "sourceObjectRef",
            "memo",
        ]))

        let accountCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM ledgerAccounts WHERE entityId = ?",
            arguments: [entityId]
        )
        #expect(accountCount == 3)

        let migratedTransaction = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT amountMinor, currency, counterpartyName, taxCode
            FROM transactions
            WHERE id = ?
            """,
            arguments: [transactionId]
        ))
        let amountMinor: Int64 = migratedTransaction["amountMinor"]
        let currency: String = migratedTransaction["currency"]
        let counterpartyName: String = migratedTransaction["counterpartyName"]
        let taxCode: String? = migratedTransaction["taxCode"]
        #expect(amountMinor == 12_500_00)
        #expect(currency == "CHF")
        #expect(counterpartyName == "Legacy Client AG")
        #expect(taxCode == "CH-VAT-OUTPUT-STD")

        let packageRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT status, generatedAt, finalizedAt, finalizedBy, snapshotHash, exportFormat
            FROM filingPackages
            WHERE id = ?
            """,
            arguments: [filingPackageId]
        ))
        let packageStatus: String = packageRow["status"]
        let generatedAt: String? = packageRow["generatedAt"]
        let finalizedAt: String? = packageRow["finalizedAt"]
        let finalizedBy: String? = packageRow["finalizedBy"]
        let snapshotHash: String? = packageRow["snapshotHash"]
        let exportFormat: String = packageRow["exportFormat"]
        #expect(packageStatus == "generated")
        #expect(generatedAt == "2026-06-30T17:00:00Z")
        #expect(finalizedAt == nil)
        #expect(finalizedBy == nil)
        #expect(snapshotHash == "legacy-accounting-export-sha256")
        #expect(exportFormat == "business-tax-draft-review")

        let migratedFact = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT conceptCode, moneyMinor, currency, provenanceRefs, isCurrent
            FROM taxFacts
            WHERE id = ?
            """,
            arguments: [taxFactId]
        ))
        let conceptCode: String = migratedFact["conceptCode"]
        let moneyMinor: Int64 = migratedFact["moneyMinor"]
        let factCurrency: String = migratedFact["currency"]
        let provenanceRefs: String = migratedFact["provenanceRefs"]
        let isCurrent: Bool = migratedFact["isCurrent"]
        #expect(conceptCode == "personal.self_employment.revenue_gross")
        #expect(moneyMinor == 12_500_00)
        #expect(factCurrency == "CHF")
        #expect(provenanceRefs == #"[{"kind":"transaction","id":"\#(transactionId)"}]"#)
        #expect(isCurrent == true)

        try db.execute(
            sql: """
            INSERT INTO journalEntries (
                id, entityId, taxYearId, entryNumber, effectiveDate, kind,
                status, memo, reversalOfId, createdBy, approvedBy, approvedAt
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                journalEntryId,
                entityId,
                taxYearId,
                "JE-2026-001",
                "2026-06-30T12:00:00Z",
                "manual",
                "draft",
                "Accrue June advisory revenue from legacy migration fixture.",
                nil,
                "migration-test",
                nil,
                nil,
            ]
        )

        try db.execute(
            sql: """
            INSERT INTO journalLines (
                id, journalEntryId, ledgerAccountId, debitMinor, creditMinor,
                currency, taxCode, sourceObjectRef, memo
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                debitLineId,
                journalEntryId,
                bankLedgerAccountId,
                12_500_00,
                0,
                "CHF",
                nil,
                "transaction:\(transactionId)",
                "Debit receivable/bank control.",
            ]
        )

        try db.execute(
            sql: """
            INSERT INTO journalLines (
                id, journalEntryId, ledgerAccountId, debitMinor, creditMinor,
                currency, taxCode, sourceObjectRef, memo
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                creditLineId,
                journalEntryId,
                revenueLedgerAccountId,
                0,
                12_500_00,
                "CHF",
                "CH-VAT-OUTPUT-STD",
                "transaction:\(transactionId)",
                "Credit revenue.",
            ]
        )

        let journalTotals = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT COUNT(*) AS lineCount,
                   SUM(debitMinor) AS debitTotal,
                   SUM(creditMinor) AS creditTotal
            FROM journalLines
            WHERE journalEntryId = ?
            """,
            arguments: [journalEntryId]
        ))
        let lineCount: Int = journalTotals["lineCount"]
        let debitTotal: Int64 = journalTotals["debitTotal"]
        let creditTotal: Int64 = journalTotals["creditTotal"]
        #expect(lineCount == 2)
        #expect(debitTotal == 12_500_00)
        #expect(creditTotal == 12_500_00)

        let vatPeriodStatus = try String.fetchOne(
            db,
            sql: "SELECT status FROM vatPeriods WHERE id = ?",
            arguments: [vatPeriodId]
        )
        #expect(vatPeriodStatus == "open")

        let indexNames = try Set(String.fetchAll(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'index'"
        ))
        #expect(indexNames.isSuperset(of: [
            "journalEntries_entity_entryNumber",
            "journalEntries_entity_taxYear",
            "journalLines_entry",
            "journalLines_account",
        ]))

        let foreignKeyViolations = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pragma_foreign_key_check")
        #expect(foreignKeyViolations == 0)
    }
}

@Test
func databaseMigrationsUpgradeLegacyV12ReportingViewsExposeExistingRecords() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = UUID().uuidString.lowercased()
    let entityId = UUID().uuidString.lowercased()
    let taxYearId = UUID().uuidString.lowercased()
    let statementImportId = UUID().uuidString.lowercased()
    let incomeTransactionId = UUID().uuidString.lowercased()
    let expenseTransactionId = UUID().uuidString.lowercased()
    let issueId = UUID().uuidString.lowercased()
    let taxFactId = UUID().uuidString.lowercased()
    let vatPeriodId = UUID().uuidString.lowercased()
    let documentId = UUID().uuidString.lowercased()
    let evidenceLinkId = UUID().uuidString.lowercased()

    try migrator.migrate(database.dbPool, upTo: AlpenLedgerDatabaseMigrations.v12Counterparties)
    try database.dbPool.write { db in
        let existingReportingView = try String.fetchOne(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'view' AND name = 'vw_cashflow_by_entity'"
        )
        #expect(existingReportingView == nil)
        try insertLegacyV12ReportingRows(
            into: db,
            workspaceId: workspaceId,
            entityId: entityId,
            taxYearId: taxYearId,
            statementImportId: statementImportId,
            incomeTransactionId: incomeTransactionId,
            expenseTransactionId: expenseTransactionId,
            issueId: issueId,
            taxFactId: taxFactId,
            vatPeriodId: vatPeriodId,
            documentId: documentId,
            evidenceLinkId: evidenceLinkId
        )
    }

    try migrator.migrate(database.dbPool)

    try database.dbPool.read { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        let viewNames = try Set(String.fetchAll(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'view'"
        ))
        #expect(viewNames.isSuperset(of: AlpenLedgerDatabaseMigrations.requiredViews))

        let spendRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT spendMinor, transactionCount
            FROM vw_spend_by_month
            WHERE workspaceId = ? AND entityId = ? AND yearMonth = ? AND currency = ?
            """,
            arguments: [workspaceId, entityId, "2026-05", "CHF"]
        ))
        let spendMinor: Int64 = spendRow["spendMinor"]
        let spendTransactionCount: Int = spendRow["transactionCount"]
        #expect(spendMinor == 25_000)
        #expect(spendTransactionCount == 1)

        let cashflowRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT inflowMinor, outflowMinor, netMinor, transactionCount
            FROM vw_cashflow_by_entity
            WHERE workspaceId = ? AND entityId = ? AND yearMonth = ? AND currency = ?
            """,
            arguments: [workspaceId, entityId, "2026-05", "CHF"]
        ))
        let inflowMinor: Int64 = cashflowRow["inflowMinor"]
        let outflowMinor: Int64 = cashflowRow["outflowMinor"]
        let netMinor: Int64 = cashflowRow["netMinor"]
        let cashflowTransactionCount: Int = cashflowRow["transactionCount"]
        #expect(inflowMinor == 100_000)
        #expect(outflowMinor == 25_000)
        #expect(netMinor == 75_000)
        #expect(cashflowTransactionCount == 2)

        let missingEvidenceCount = try Int.fetchOne(
            db,
            sql: """
            SELECT COUNT(*)
            FROM vw_missing_evidence
            WHERE issueId = ? AND workspaceId = ? AND entityId = ? AND taxYearId = ?
            """,
            arguments: [issueId, workspaceId, entityId, taxYearId]
        )
        #expect(missingEvidenceCount == 1)

        let statementCoverageRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT accountDisplayName, openingBalanceMinor, closingBalanceMinor, sourceFormat, status
            FROM vw_statement_coverage
            WHERE statementImportId = ?
            """,
            arguments: [statementImportId]
        ))
        let accountDisplayName: String = statementCoverageRow["accountDisplayName"]
        let openingBalanceMinor: Int64 = statementCoverageRow["openingBalanceMinor"]
        let closingBalanceMinor: Int64 = statementCoverageRow["closingBalanceMinor"]
        let sourceFormat: String = statementCoverageRow["sourceFormat"]
        let statementStatus: String = statementCoverageRow["status"]
        #expect(accountDisplayName == "Legacy Reporting Account")
        #expect(openingBalanceMinor == 0)
        #expect(closingBalanceMinor == 75_000)
        #expect(sourceFormat == "csv")
        #expect(statementStatus == "imported")

        let taxFactRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT conceptCode, valueType, moneyMinor, currency, status, isCurrent
            FROM vw_tax_fact_status
            WHERE taxFactId = ?
            """,
            arguments: [taxFactId]
        ))
        let conceptCode: String = taxFactRow["conceptCode"]
        let valueType: String = taxFactRow["valueType"]
        let moneyMinor: Int64 = taxFactRow["moneyMinor"]
        let taxFactCurrency: String = taxFactRow["currency"]
        let taxFactStatus: String = taxFactRow["status"]
        let isCurrent: Bool = taxFactRow["isCurrent"]
        #expect(conceptCode == "personal.self_employment.net_profit")
        #expect(valueType == "money")
        #expect(moneyMinor == 75_000)
        #expect(taxFactCurrency == "CHF")
        #expect(taxFactStatus == "computed")
        #expect(isCurrent == true)

        let unmatchedExpenseCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_unmatched_transactions WHERE transactionId = ?",
            arguments: [expenseTransactionId]
        )
        let unmatchedIncomeCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_unmatched_transactions WHERE transactionId = ?",
            arguments: [incomeTransactionId]
        )
        #expect(unmatchedExpenseCount == 1)
        #expect(unmatchedIncomeCount == 0)

        let vatRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT transactionCount, missingTaxCodeCount, outputBaseMinor,
                   inputBaseMinor, netCashflowMinor, status
            FROM vw_vat_reconciliation
            WHERE vatPeriodId = ?
            """,
            arguments: [vatPeriodId]
        ))
        let vatTransactionCount: Int = vatRow["transactionCount"]
        let missingTaxCodeCount: Int = vatRow["missingTaxCodeCount"]
        let outputBaseMinor: Int64 = vatRow["outputBaseMinor"]
        let inputBaseMinor: Int64 = vatRow["inputBaseMinor"]
        let netCashflowMinor: Int64 = vatRow["netCashflowMinor"]
        let vatStatus: String = vatRow["status"]
        #expect(vatTransactionCount == 2)
        #expect(missingTaxCodeCount == 0)
        #expect(outputBaseMinor == 100_000)
        #expect(inputBaseMinor == 25_000)
        #expect(netCashflowMinor == 75_000)
        #expect(vatStatus == "open")

        let foreignKeyViolations = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pragma_foreign_key_check")
        #expect(foreignKeyViolations == 0)
    }
}

@Test
func databaseMigrationsUpgradeLegacyV13GlobalSearchBackfillsExistingRecords() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = UUID().uuidString.lowercased()
    let entityId = UUID().uuidString.lowercased()
    let taxYearId = UUID().uuidString.lowercased()
    let documentId = UUID().uuidString.lowercased()
    let transactionId = UUID().uuidString.lowercased()
    let counterpartyId = UUID().uuidString.lowercased()
    let issueId = UUID().uuidString.lowercased()

    try migrator.migrate(database.dbPool, upTo: AlpenLedgerDatabaseMigrations.v13ReportingViews)
    try database.dbPool.write { db in
        #expect(try db.tableExists("globalSearchRecords") == false)
        #expect(try db.tableExists("global_search") == false)
        try insertLegacyV13GlobalSearchRows(
            into: db,
            workspaceId: workspaceId,
            entityId: entityId,
            taxYearId: taxYearId,
            documentId: documentId,
            transactionId: transactionId,
            counterpartyId: counterpartyId,
            issueId: issueId
        )
    }

    try migrator.migrate(database.dbPool)

    try database.dbPool.read { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        let objectRefs = try Set(String.fetchAll(
            db,
            sql: "SELECT objectRef FROM globalSearchRecords"
        ))
        #expect(objectRefs == [
            "document|\(documentId)",
            "transaction|\(transactionId)",
            "counterparty|\(counterpartyId)",
            "issue|\(issueId)",
        ])

        let documentRecord = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT workspaceId, entityId, objectKind, title, subtitle, content
            FROM globalSearchRecords
            WHERE objectRef = ?
            """,
            arguments: ["document|\(documentId)"]
        ))
        let documentWorkspaceId: String = documentRecord["workspaceId"]
        let documentEntityId: String = documentRecord["entityId"]
        let documentKind: String = documentRecord["objectKind"]
        let documentTitle: String = documentRecord["title"]
        let documentSubtitle: String = documentRecord["subtitle"]
        let documentContent: String = documentRecord["content"]
        #expect(documentWorkspaceId == workspaceId)
        #expect(documentEntityId == entityId)
        #expect(documentKind == "document")
        #expect(documentTitle == "legacy-v13-salary.pdf")
        #expect(documentSubtitle.contains("salaryCertificate"))
        #expect(documentContent.contains("alphav13"))

        let transactionRecord = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT workspaceId, entityId, objectKind, title, subtitle, content
            FROM globalSearchRecords
            WHERE objectRef = ?
            """,
            arguments: ["transaction|\(transactionId)"]
        ))
        let transactionWorkspaceId: String = transactionRecord["workspaceId"]
        let transactionEntityId: String = transactionRecord["entityId"]
        let transactionKind: String = transactionRecord["objectKind"]
        let transactionTitle: String = transactionRecord["title"]
        let transactionSubtitle: String = transactionRecord["subtitle"]
        let transactionContent: String = transactionRecord["content"]
        #expect(transactionWorkspaceId == workspaceId)
        #expect(transactionEntityId == entityId)
        #expect(transactionKind == "transaction")
        #expect(transactionTitle == "LegacyV13Vendor AG")
        #expect(transactionSubtitle.contains("CHF"))
        #expect(transactionContent.contains("legacyv13payment"))

        let indexSQL = try String.fetchOne(
            db,
            sql: "SELECT sql FROM sqlite_master WHERE name = 'global_search'"
        )
        #expect(indexSQL?.contains("USING fts5") == true)

        let foreignKeyViolations = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pragma_foreign_key_check")
        #expect(foreignKeyViolations == 0)
    }

    let workspaceUUID = try #require(UUID(uuidString: workspaceId))
    let entityUUID = try #require(UUID(uuidString: entityId))
    let searchIndex = SQLiteSearchIndex(dbPool: database.dbPool)
    let documentHits = try searchIndex.search(
        workspaceId: WorkspaceID(rawValue: workspaceUUID),
        query: "alphav13",
        limit: 10
    )
    #expect(documentHits.contains {
        $0.objectRef == ObjectRef(kind: .document, id: documentId) &&
        $0.objectKind == .document &&
        $0.title == "legacy-v13-salary.pdf"
    })

    let transactionHits = try searchIndex.search(
        workspaceId: WorkspaceID(rawValue: workspaceUUID),
        query: "legacyv13payment",
        limit: 10
    )
    #expect(transactionHits.contains {
        $0.objectRef == ObjectRef(kind: .transaction, id: transactionId) &&
        $0.objectKind == .transaction &&
        $0.entityId == LegalEntityID(rawValue: entityUUID)
    })

    let counterpartyHits = try searchIndex.search(
        workspaceId: WorkspaceID(rawValue: workspaceUUID),
        query: "LegacyV13Vendor",
        limit: 10
    )
    #expect(counterpartyHits.contains {
        $0.objectRef == ObjectRef(kind: .counterparty, id: counterpartyId) &&
        $0.objectKind == .counterparty
    })

    let issueHits = try searchIndex.search(
        workspaceId: WorkspaceID(rawValue: workspaceUUID),
        query: "legacyv13expense",
        limit: 10
    )
    #expect(issueHits.contains {
        $0.objectRef == ObjectRef(kind: .issue, id: issueId) &&
        $0.objectKind == .issue
    })
}

@Test
func databaseMigrationsUpgradeLegacyV14AgentProposalUncertaintyState() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = UUID().uuidString.lowercased()
    let proposalId = UUID().uuidString.lowercased()
    let importJobId = UUID().uuidString.lowercased()

    try database.dbPool.write { db in
        try installLegacyV14AgentProposalRows(
            into: db,
            workspaceId: workspaceId,
            proposalId: proposalId,
            importJobId: importJobId
        )
    }

    try migrator.migrate(database.dbPool)

    try database.dbPool.read { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        let proposalColumns = try columnNames(in: "agentProposals", db: db)
        #expect(proposalColumns.contains("missingFields"))
        #expect(proposalColumns.contains("question"))
        #expect(proposalColumns.contains("requiresManualReview"))

        let migratedProposal = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT fingerprint, summary, rationale, confidence, relatedRef,
                   missingFields, question, requiresManualReview, status,
                   decidedAt, decidedBy, decisionReason
            FROM agentProposals
            WHERE id = ?
            """,
            arguments: [proposalId]
        ))
        let fingerprint: String = migratedProposal["fingerprint"]
        let summary: String = migratedProposal["summary"]
        let rationale: String = migratedProposal["rationale"]
        let confidence: Double = migratedProposal["confidence"]
        let relatedRef: String? = migratedProposal["relatedRef"]
        let missingFields: String = migratedProposal["missingFields"]
        let question: String? = migratedProposal["question"]
        let requiresManualReview: Bool = migratedProposal["requiresManualReview"]
        let status: String = migratedProposal["status"]
        let decidedAt: String? = migratedProposal["decidedAt"]
        let decidedBy: String? = migratedProposal["decidedBy"]
        let decisionReason: String? = migratedProposal["decisionReason"]
        #expect(fingerprint == "legacy-proposal:receipt-match")
        #expect(summary == "Match receipt to imported expense.")
        #expect(rationale == "Legacy proposal created before uncertainty metadata existed.")
        #expect(confidence == 0.82)
        #expect(relatedRef == "document:legacy-receipt")
        #expect(missingFields == "[]")
        #expect(question == nil)
        #expect(requiresManualReview == false)
        #expect(status == "pending")
        #expect(decidedAt == nil)
        #expect(decidedBy == nil)
        #expect(decisionReason == nil)

        let importJobColumns = try columnNames(in: "importJobs", db: db)
        #expect(importJobColumns.contains("sourceBlobHash"))
        #expect(importJobColumns.contains("sourceFingerprint"))
    }
}

@Test
func databaseMigrationsUpgradeLegacyV15ImportDiagnosticsSupportExistingImportJobs() throws {
    let database = try makeMigrationTestDatabase()
    let migrator = makeAlpenLedgerDatabaseMigrator()
    let workspaceId = WorkspaceID()
    let importJobId = ImportJobID()

    try migrator.migrate(database.dbPool, upTo: AlpenLedgerDatabaseMigrations.v15AgentProposalUncertaintyMetadata)

    try database.dbPool.write { db in
        #expect(try db.tableExists("importDiagnostics") == false)
        try db.execute(
            sql: """
            INSERT INTO workspaces (
                id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                workspaceId.description,
                "Legacy Import Diagnostics Workspace",
                1,
                "2026-05-30T10:00:00Z",
                "CHF",
                "localOnly",
                "workspace.json",
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO importJobs (
                id, workspaceId, kind, source, parserKey, parserVersion,
                status, startedAt, completedAt, warningCount
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                importJobId.description,
                workspaceId.description,
                "bankStatementCSV",
                "legacy-v15-bank-statement.csv",
                "csv.generic",
                "1.0.0",
                "failed",
                "2026-05-30T10:01:00Z",
                "2026-05-30T10:02:00Z",
                2,
            ]
        )
    }

    try migrator.migrate(database.dbPool)

    let diagnosticRepository = GRDBImportDiagnosticRepository(dbPool: database.dbPool)
    let missingColumnsId = ImportDiagnosticID()
    let unparseableAmountId = ImportDiagnosticID()
    let firstDiagnosticDate = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let secondDiagnosticDate = firstDiagnosticDate.addingTimeInterval(60)
    try diagnosticRepository.saveImportDiagnostics([
        ImportDiagnostic(
            id: missingColumnsId,
            importJobId: importJobId,
            severity: .error,
            code: "csv.missing_columns",
            location: "header",
            message: "Legacy CSV import is missing required bookingDate and amount columns.",
            createdAt: firstDiagnosticDate
        ),
        ImportDiagnostic(
            id: unparseableAmountId,
            importJobId: importJobId,
            severity: .warning,
            code: "csv.unparseable_amount",
            location: "row 17",
            message: "Legacy CSV row 17 had an amount that could not be parsed.",
            createdAt: secondDiagnosticDate
        ),
    ])

    let diagnosticsForJob = try diagnosticRepository.fetchImportDiagnostics(importJobId: importJobId)
    #expect(diagnosticsForJob.map(\.id) == [missingColumnsId, unparseableAmountId])
    #expect(diagnosticsForJob.map(\.severity) == [.error, .warning])
    #expect(diagnosticsForJob.map(\.code) == ["csv.missing_columns", "csv.unparseable_amount"])
    #expect(diagnosticsForJob.map(\.location) == ["header", "row 17"])

    let diagnosticsForWorkspace = try diagnosticRepository.fetchImportDiagnostics(workspaceId: workspaceId)
    #expect(diagnosticsForWorkspace.map(\.id) == [missingColumnsId, unparseableAmountId])

    try database.dbPool.write { db in
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)

        let diagnosticColumns = try columnNames(in: "importDiagnostics", db: db)
        #expect(diagnosticColumns.isSuperset(of: [
            "id",
            "importJobId",
            "severity",
            "code",
            "location",
            "message",
            "createdAt",
        ]))

        let diagnosticIndexes = try Set(String.fetchAll(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'importDiagnostics'"
        ))
        #expect(diagnosticIndexes.contains("importDiagnostics_importJob"))
        #expect(diagnosticIndexes.contains("importDiagnostics_code"))

        let foreignKeyViolations = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pragma_foreign_key_check") ?? -1
        #expect(foreignKeyViolations == 0)

        try db.execute(sql: "DELETE FROM importJobs WHERE id = ?", arguments: [importJobId.description])
        let remainingDiagnostics = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM importDiagnostics WHERE importJobId = ?",
            arguments: [importJobId.description]
        )
        #expect(remainingDiagnostics == 0)
    }
}

private struct MigrationTestDatabase {
    let dbPool: DatabasePool
}

private func makeMigrationTestDatabase() throws -> MigrationTestDatabase {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    var configuration = Configuration()
    configuration.prepareDatabase { db in
        try db.execute(sql: "PRAGMA foreign_keys = ON")
    }

    let databaseURL = directoryURL.appendingPathComponent("workspace.sqlite")
    return MigrationTestDatabase(
        dbPool: try DatabasePool(path: databaseURL.path, configuration: configuration)
    )
}

private func columnNames(in tableName: String, db: Database) throws -> Set<String> {
    try Set(db.columns(in: tableName).map(\.name))
}

private func schemaSnapshot(_ dbPool: DatabasePool) throws -> [String] {
    try dbPool.read { db in
        try Row.fetchAll(
            db,
            sql: """
            SELECT type, name, tbl_name, COALESCE(sql, '') AS sql
            FROM sqlite_master
            WHERE name NOT LIKE 'sqlite_%'
            ORDER BY type, name, tbl_name
            """
        )
        .map { row in
            let type: String = row["type"]
            let name: String = row["name"]
            let tableName: String = row["tbl_name"]
            let sql: String = row["sql"]
            return "\(type)|\(name)|\(tableName)|\(sql)"
        }
    }
}

private func installLegacyV5AgentProposalTable(
    into db: Database,
    workspaceId: String,
    proposalId: String,
    documentId: String
) throws {
    let createdAt = "2026-05-30T07:00:00Z"
    try db.execute(sql: "DROP TABLE agentProposals")
    try db.execute(sql: """
    CREATE TABLE agentProposals (
        id TEXT PRIMARY KEY,
        fingerprint TEXT NOT NULL,
        workspaceId TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        agentKind TEXT NOT NULL,
        proposalType TEXT NOT NULL,
        targetRef TEXT NOT NULL,
        summary TEXT NOT NULL,
        rationale TEXT NOT NULL,
        confidence DOUBLE NOT NULL,
        status TEXT NOT NULL,
        createdAt DATETIME NOT NULL
    )
    """)
    try db.create(index: "agentProposals_fingerprint", on: "agentProposals", columns: ["fingerprint"], unique: true, ifNotExists: true)
    try db.create(index: "agentProposals_workspace_status", on: "agentProposals", columns: ["workspaceId", "status"], ifNotExists: true)

    try db.execute(
        sql: """
        INSERT INTO workspaces (
            id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            workspaceId,
            "Legacy V5 Proposal Workspace",
            1,
            createdAt,
            "CHF",
            "localOnly",
            "workspace.json",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO agentProposals (
            id, fingerprint, workspaceId, agentKind, proposalType,
            targetRef, summary, rationale, confidence, status, createdAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            proposalId,
            "legacy-v5-proposal:document-link",
            workspaceId,
            "systemHeuristics",
            "documentLinkReview",
            "document|\(documentId)",
            "Legacy v5 document match proposal.",
            "Created before decision, related-ref, and uncertainty metadata existed.",
            0.74,
            "pending",
            createdAt,
        ]
    )
}

private func insertLegacyV4Rows(
    into db: Database,
    workspaceId: String,
    entityId: String,
    documentId: String,
    transactionId: String
) throws {
    let createdAt = "2026-01-15T09:00:00Z"
    let ledgerAccountId = UUID().uuidString.lowercased()
    let financialAccountId = UUID().uuidString.lowercased()
    try db.execute(
        sql: """
        INSERT INTO workspaces (
            id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            workspaceId,
            "Legacy Workspace",
            1,
            createdAt,
            "CHF",
            "localOnly",
            "workspace.json",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO legalEntities (
            id, workspaceId, kind, legalName, displayName, country, canton,
            taxIdOrUID, fiscalYearStartMonth, fiscalYearStartDay, parentEntityId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            entityId,
            workspaceId,
            "naturalPerson",
            "Legacy Taxpayer",
            "Legacy Taxpayer",
            "CH",
            "ZH",
            nil,
            1,
            1,
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO documents (
            id, workspaceId, importJobId, blobHash, originalFilename, mediaType,
            origin, documentType, issueDate, detectedEntityId, detectedTaxYearId,
            extractedText, metadataStatus, parseVersion
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            documentId,
            workspaceId,
            nil,
            "legacy-document-blob",
            "legacy-receipt.pdf",
            "application/pdf",
            "userImport",
            "receipt",
            nil,
            entityId,
            nil,
            "legacy receipt text",
            "confirmed",
            "v1",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO ledgerAccounts (
            id, entityId, code, name, category, normalBalance, parentId, taxRole,
            isControlAccount
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            ledgerAccountId,
            entityId,
            "1000",
            "Bank",
            "asset",
            "debit",
            nil,
            nil,
            true,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO financialAccounts (
            id, entityId, accountType, institutionName, displayName, currency,
            ibanMask, statementCadence, ledgerControlAccountId, openedAt, closedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            financialAccountId,
            entityId,
            "bank",
            "Legacy Bank",
            "Legacy Account",
            "CHF",
            nil,
            "monthly",
            ledgerAccountId,
            createdAt,
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO transactions (
            id, accountId, statementImportId, originKind, sourceLineRef,
            bookingDate, valueDate, amountMinor, currency, counterpartyName,
            memo, reference, balanceAfterMinor, reviewState
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            transactionId,
            financialAccountId,
            nil,
            "manual",
            "legacy-line-1",
            createdAt,
            nil,
            -4_200,
            "CHF",
            "Legacy Supplier AG",
            "Legacy imported transaction",
            "LEGACY-1",
            nil,
            "pending",
        ]
    )
}

private func replaceFilingPackagesWithLegacyV9Shape(_ db: Database) throws {
    try db.execute(sql: "DROP INDEX IF EXISTS filingPackages_entity_taxYear")
    try db.execute(sql: "DROP TABLE IF EXISTS filingPackages")
    try db.execute(sql: """
    CREATE TABLE filingPackages (
        id TEXT PRIMARY KEY,
        entityId TEXT NOT NULL REFERENCES legalEntities(id) ON DELETE CASCADE,
        taxYearId TEXT NOT NULL REFERENCES taxYears(id) ON DELETE CASCADE,
        status TEXT NOT NULL,
        generatedAt DATETIME,
        submittedAt DATETIME,
        snapshotHash TEXT,
        exportFormat TEXT NOT NULL,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL
    )
    """)
    try db.execute(sql: """
    CREATE INDEX filingPackages_entity_taxYear
    ON filingPackages(entityId, taxYearId)
    """)
}

private func insertLegacyV9FilingPackageRows(
    into db: Database,
    workspaceId: String,
    entityId: String,
    taxYearId: String,
    filingPackageId: String,
    vatPeriodId: String
) throws {
    try db.execute(
        sql: """
        INSERT INTO workspaces (
            id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            workspaceId,
            "Legacy Filing Workspace",
            1,
            "2026-01-01T08:00:00Z",
            "CHF",
            "localOnly",
            "workspace.json",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO legalEntities (
            id, workspaceId, kind, legalName, displayName, country, canton,
            taxIdOrUID, fiscalYearStartMonth, fiscalYearStartDay, parentEntityId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            entityId,
            workspaceId,
            "soleProprietor",
            "Legacy Filing Studio",
            "Legacy Filing Studio",
            "CH",
            "ZH",
            "CHE-000.000.001",
            1,
            1,
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO taxYears (
            id, entityId, year, periodStart, periodEnd, canton,
            filingMode, rulesetVersion, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            taxYearId,
            entityId,
            2026,
            "2026-01-01T00:00:00Z",
            "2026-12-31T23:59:59Z",
            "ZH",
            "soleProprietor",
            "ch-zh-2026-v1",
            "open",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO vatPeriods (
            id, entityId, periodStart, periodEnd, currency, status
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            vatPeriodId,
            entityId,
            "2026-01-01T00:00:00Z",
            "2026-03-31T23:59:59Z",
            "CHF",
            "locked",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO filingPackages (
            id, entityId, taxYearId, status, generatedAt, submittedAt,
            snapshotHash, exportFormat, createdAt, updatedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            filingPackageId,
            entityId,
            taxYearId,
            "generated",
            "2026-03-31T18:00:00Z",
            nil,
            "legacy-vat-package-sha256",
            "eCH-0217",
            "2026-03-31T17:58:00Z",
            "2026-03-31T18:00:00Z",
        ]
    )
}

private func insertLegacyV10AccountingRows(
    into db: Database,
    workspaceId: String,
    entityId: String,
    taxYearId: String,
    bankLedgerAccountId: String,
    revenueLedgerAccountId: String,
    expenseLedgerAccountId: String,
    transactionId: String,
    filingPackageId: String,
    vatPeriodId: String,
    taxFactId: String
) throws {
    let createdAt = "2026-06-30T10:00:00Z"
    let financialAccountId = UUID().uuidString.lowercased()
    try db.execute(
        sql: """
        INSERT INTO workspaces (
            id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            workspaceId,
            "Legacy Accounting Workspace",
            1,
            createdAt,
            "CHF",
            "localOnly",
            "workspace.json",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO legalEntities (
            id, workspaceId, kind, legalName, displayName, country, canton,
            taxIdOrUID, fiscalYearStartMonth, fiscalYearStartDay, parentEntityId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            entityId,
            workspaceId,
            "soleProprietor",
            "Legacy Accounting Studio",
            "Legacy Accounting Studio",
            "CH",
            "ZH",
            "CHE-000.000.011",
            1,
            1,
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO taxYears (
            id, entityId, year, periodStart, periodEnd, canton,
            filingMode, rulesetVersion, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            taxYearId,
            entityId,
            2026,
            "2026-01-01T00:00:00Z",
            "2026-12-31T23:59:59Z",
            "ZH",
            "soleProprietor",
            "ch-zh-2026-v1",
            "open",
        ]
    )

    for (id, code, name, category, normalBalance, taxRole, isControlAccount) in [
        (bankLedgerAccountId, "1020", "Operating Bank", "asset", "debit", nil as String?, true),
        (revenueLedgerAccountId, "3400", "Advisory Revenue", "revenue", "credit", "selfEmploymentRevenue", false),
        (expenseLedgerAccountId, "6500", "Office Expenses", "expense", "debit", "businessExpense", false),
    ] {
        try db.execute(
            sql: """
            INSERT INTO ledgerAccounts (
                id, entityId, code, name, category, normalBalance, parentId,
                taxRole, isControlAccount
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id,
                entityId,
                code,
                name,
                category,
                normalBalance,
                nil,
                taxRole,
                isControlAccount,
            ]
        )
    }

    try db.execute(
        sql: """
        INSERT INTO financialAccounts (
            id, entityId, accountType, institutionName, displayName, currency,
            ibanMask, statementCadence, ledgerControlAccountId, openedAt, closedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            financialAccountId,
            entityId,
            "bank",
            "Legacy Bank",
            "Business Account",
            "CHF",
            "CH93 **** **** **** 0000 1",
            "monthly",
            bankLedgerAccountId,
            "2026-01-01T00:00:00Z",
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO transactions (
            id, accountId, statementImportId, originKind, sourceLineRef,
            bookingDate, valueDate, amountMinor, currency, counterpartyName,
            memo, reference, taxCode, balanceAfterMinor, reviewState
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            transactionId,
            financialAccountId,
            nil,
            "bankStatement",
            "legacy-v10-line-42",
            "2026-06-30T00:00:00Z",
            "2026-06-30T00:00:00Z",
            12_500_00,
            "CHF",
            "Legacy Client AG",
            "June advisory invoice payment",
            "INV-2026-042",
            "CH-VAT-OUTPUT-STD",
            78_900_00,
            "confirmed",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO vatPeriods (
            id, entityId, periodStart, periodEnd, currency, status
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            vatPeriodId,
            entityId,
            "2026-04-01T00:00:00Z",
            "2026-06-30T23:59:59Z",
            "CHF",
            "open",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO filingPackages (
            id, entityId, taxYearId, status, generatedAt, finalizedAt,
            finalizedBy, submittedAt, snapshotHash, exportFormat, createdAt,
            updatedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            filingPackageId,
            entityId,
            taxYearId,
            "generated",
            "2026-06-30T17:00:00Z",
            nil,
            nil,
            nil,
            "legacy-accounting-export-sha256",
            "business-tax-draft-review",
            "2026-06-30T16:58:00Z",
            "2026-06-30T17:00:00Z",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO taxFacts (
            id, fingerprint, entityId, taxYearId, jurisdictionCode,
            conceptCode, valueType, moneyMinor, textValue, boolValue,
            dateValue, currency, status, rulesetVersion, provenanceRefs,
            confidence, supersedesFactId, isCurrent, overrideReason,
            createdAt, updatedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            taxFactId,
            "taxfact:\(entityId):2026:revenue-gross",
            entityId,
            taxYearId,
            "CH-ZH",
            "personal.self_employment.revenue_gross",
            "money",
            12_500_00,
            nil,
            nil,
            nil,
            "CHF",
            "computed",
            "ch-zh-2026-v1",
            #"[{"kind":"transaction","id":"\#(transactionId)"}]"#,
            1.0,
            nil,
            true,
            nil,
            createdAt,
            createdAt,
        ]
    )
}

private func insertLegacyV12ReportingRows(
    into db: Database,
    workspaceId: String,
    entityId: String,
    taxYearId: String,
    statementImportId: String,
    incomeTransactionId: String,
    expenseTransactionId: String,
    issueId: String,
    taxFactId: String,
    vatPeriodId: String,
    documentId: String,
    evidenceLinkId: String
) throws {
    let createdAt = "2026-05-31T10:00:00Z"
    let ledgerAccountId = UUID().uuidString.lowercased()
    let financialAccountId = UUID().uuidString.lowercased()
    let importJobId = UUID().uuidString.lowercased()
    let incomeCounterpartyId = UUID().uuidString.lowercased()
    let expenseCounterpartyId = UUID().uuidString.lowercased()

    try db.execute(
        sql: """
        INSERT INTO workspaces (
            id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            workspaceId,
            "Legacy V12 Reporting Workspace",
            1,
            createdAt,
            "CHF",
            "localOnly",
            "workspace.json",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO legalEntities (
            id, workspaceId, kind, legalName, displayName, country, canton,
            taxIdOrUID, fiscalYearStartMonth, fiscalYearStartDay, parentEntityId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            entityId,
            workspaceId,
            "soleProprietor",
            "Legacy V12 Reporter",
            "Legacy V12 Reporter",
            "CH",
            "ZH",
            "CHE-000.000.012",
            1,
            1,
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO taxYears (
            id, entityId, year, periodStart, periodEnd, canton,
            filingMode, rulesetVersion, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            taxYearId,
            entityId,
            2026,
            "2026-01-01T00:00:00Z",
            "2026-12-31T23:59:59Z",
            "ZH",
            "soleProprietor",
            "ch-zh-2026-v1",
            "open",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO ledgerAccounts (
            id, entityId, code, name, category, normalBalance, parentId,
            taxRole, isControlAccount
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            ledgerAccountId,
            entityId,
            "1020",
            "Reporting Bank",
            "asset",
            "debit",
            nil,
            nil,
            true,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO financialAccounts (
            id, entityId, accountType, institutionName, displayName, currency,
            ibanMask, statementCadence, ledgerControlAccountId, openedAt, closedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            financialAccountId,
            entityId,
            "bank",
            "Legacy Reporting Bank",
            "Legacy Reporting Account",
            "CHF",
            nil,
            "monthly",
            ledgerAccountId,
            "2026-01-01T00:00:00Z",
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO importJobs (
            id, workspaceId, kind, source, parserKey, parserVersion,
            status, startedAt, completedAt, warningCount
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            importJobId,
            workspaceId,
            "bankStatementCSV",
            "legacy-v12-reporting.csv",
            "csv.generic",
            "1.0.0",
            "completed",
            createdAt,
            "2026-05-31T10:01:00Z",
            0,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO statementImports (
            id, accountId, importJobId, sourceBlobHash, sourceFormat,
            sourceFingerprint, coverageStart, coverageEnd, openingBalanceMinor,
            closingBalanceMinor, parserVersion, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            statementImportId,
            financialAccountId,
            importJobId,
            "legacy-v12-statement-blob",
            "csv",
            "legacy-v12-statement-fingerprint",
            "2026-05-01T00:00:00Z",
            "2026-05-31T23:59:59Z",
            0,
            75_000,
            "1.0.0",
            "imported",
        ]
    )

    for (id, displayName, normalizedName) in [
        (incomeCounterpartyId, "Legacy V12 Client AG", "legacy v12 client ag"),
        (expenseCounterpartyId, "Legacy V12 Supplier AG", "legacy v12 supplier ag"),
    ] {
        try db.execute(
            sql: """
            INSERT INTO counterparties (
                id, entityId, displayName, normalizedName, status,
                mergedIntoCounterpartyId, createdAt, updatedAt
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id,
                entityId,
                displayName,
                normalizedName,
                "active",
                nil,
                createdAt,
                createdAt,
            ]
        )
    }

    try db.execute(
        sql: """
        INSERT INTO transactions (
            id, accountId, statementImportId, originKind, sourceLineRef,
            bookingDate, valueDate, amountMinor, currency, counterpartyName,
            memo, reference, taxCode, balanceAfterMinor, reviewState,
            counterpartyId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            incomeTransactionId,
            financialAccountId,
            statementImportId,
            "bankStatement",
            "legacy-v12-income",
            "2026-05-15T00:00:00Z",
            "2026-05-15T00:00:00Z",
            100_000,
            "CHF",
            "Legacy V12 Client AG",
            "Legacy V12 consulting revenue",
            "V12-INCOME",
            "CH-VAT-OUTPUT-STD",
            100_000,
            "confirmed",
            incomeCounterpartyId,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO transactions (
            id, accountId, statementImportId, originKind, sourceLineRef,
            bookingDate, valueDate, amountMinor, currency, counterpartyName,
            memo, reference, taxCode, balanceAfterMinor, reviewState,
            counterpartyId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            expenseTransactionId,
            financialAccountId,
            statementImportId,
            "bankStatement",
            "legacy-v12-expense",
            "2026-05-20T00:00:00Z",
            "2026-05-20T00:00:00Z",
            -25_000,
            "CHF",
            "Legacy V12 Supplier AG",
            "Legacy V12 equipment expense",
            "V12-EXPENSE",
            "CH-VAT-INPUT-STD",
            75_000,
            "pending",
            expenseCounterpartyId,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO documents (
            id, workspaceId, importJobId, blobHash, originalFilename, mediaType,
            origin, documentType, issueDate, detectedEntityId, detectedTaxYearId,
            extractedText, metadataStatus, parseVersion, entityId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            documentId,
            workspaceId,
            nil,
            "legacy-v12-revenue-document-blob",
            "legacy-v12-invoice.pdf",
            "application/pdf",
            "userImport",
            "customerInvoice",
            "2026-05-15T00:00:00Z",
            entityId,
            taxYearId,
            "Legacy V12 invoice supporting matched revenue",
            "confirmed",
            "v1",
            entityId,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO evidenceLinks (
            id, sourceRef, targetRef, linkType, status, confidence,
            createdByKind, approvalRequired, reason
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            evidenceLinkId,
            "document|\(documentId)",
            "transaction|\(incomeTransactionId)",
            "documentToTransaction",
            "confirmed",
            1.0,
            "user",
            false,
            "Legacy confirmed invoice match.",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO issues (
            id, fingerprint, workspaceId, entityId, taxYearId, issueCode,
            severity, status, summary, objectRef, relatedRef,
            firstDetectedAt, lastDetectedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            issueId,
            "legacy-v12-missing-expense-evidence",
            workspaceId,
            entityId,
            taxYearId,
            "missingExpenseEvidence",
            "warning",
            "open",
            "Legacy V12 supplier receipt is missing.",
            "transaction|\(expenseTransactionId)",
            nil,
            createdAt,
            createdAt,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO taxFacts (
            id, fingerprint, entityId, taxYearId, jurisdictionCode,
            conceptCode, valueType, moneyMinor, textValue, boolValue,
            dateValue, currency, status, rulesetVersion, provenanceRefs,
            confidence, supersedesFactId, isCurrent, overrideReason,
            createdAt, updatedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            taxFactId,
            "legacy-v12-taxfact-net-profit",
            entityId,
            taxYearId,
            "CH-ZH",
            "personal.self_employment.net_profit",
            "money",
            75_000,
            nil,
            nil,
            nil,
            "CHF",
            "computed",
            "ch-zh-2026-v1",
            #"[{"kind":"transaction","id":"\#(incomeTransactionId)"},{"kind":"transaction","id":"\#(expenseTransactionId)"}]"#,
            1.0,
            nil,
            true,
            nil,
            createdAt,
            createdAt,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO vatPeriods (
            id, entityId, periodStart, periodEnd, currency, status
        )
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            vatPeriodId,
            entityId,
            "2026-04-01T00:00:00Z",
            "2026-06-30T23:59:59Z",
            "CHF",
            "open",
        ]
    )
}

private func insertLegacyV13GlobalSearchRows(
    into db: Database,
    workspaceId: String,
    entityId: String,
    taxYearId: String,
    documentId: String,
    transactionId: String,
    counterpartyId: String,
    issueId: String
) throws {
    let createdAt = "2026-05-13T10:00:00Z"
    let ledgerAccountId = UUID().uuidString.lowercased()
    let financialAccountId = UUID().uuidString.lowercased()

    try db.execute(
        sql: """
        INSERT INTO workspaces (
            id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            workspaceId,
            "Legacy V13 Search Workspace",
            1,
            createdAt,
            "CHF",
            "localOnly",
            "workspace.json",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO legalEntities (
            id, workspaceId, kind, legalName, displayName, country, canton,
            taxIdOrUID, fiscalYearStartMonth, fiscalYearStartDay, parentEntityId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            entityId,
            workspaceId,
            "naturalPerson",
            "Legacy V13 Taxpayer",
            "Legacy V13 Taxpayer",
            "CH",
            "ZH",
            nil,
            1,
            1,
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO taxYears (
            id, entityId, year, periodStart, periodEnd, canton,
            filingMode, rulesetVersion, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            taxYearId,
            entityId,
            2026,
            "2026-01-01T00:00:00Z",
            "2026-12-31T23:59:59Z",
            "ZH",
            "single",
            "ch-zh-2026-v1",
            "open",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO ledgerAccounts (
            id, entityId, code, name, category, normalBalance, parentId,
            taxRole, isControlAccount
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            ledgerAccountId,
            entityId,
            "1020",
            "Legacy Search Bank",
            "asset",
            "debit",
            nil,
            nil,
            true,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO financialAccounts (
            id, entityId, accountType, institutionName, displayName, currency,
            ibanMask, statementCadence, ledgerControlAccountId, openedAt, closedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            financialAccountId,
            entityId,
            "bank",
            "Legacy V13 Bank",
            "Legacy V13 Account",
            "CHF",
            nil,
            "monthly",
            ledgerAccountId,
            createdAt,
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO documents (
            id, workspaceId, importJobId, blobHash, originalFilename, mediaType,
            origin, documentType, issueDate, detectedEntityId, detectedTaxYearId,
            extractedText, metadataStatus, parseVersion, entityId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            documentId,
            workspaceId,
            nil,
            "legacy-v13-search-document-blob",
            "legacy-v13-salary.pdf",
            "application/pdf",
            "userImport",
            "salaryCertificate",
            "2026-05-13T00:00:00Z",
            entityId,
            taxYearId,
            "alphav13 salary certificate for migrated global search",
            "confirmed",
            "v1",
            entityId,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO counterparties (
            id, entityId, displayName, normalizedName, status,
            mergedIntoCounterpartyId, createdAt, updatedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            counterpartyId,
            entityId,
            "LegacyV13Vendor AG",
            "legacyv13vendor ag",
            "active",
            nil,
            createdAt,
            createdAt,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO transactions (
            id, accountId, statementImportId, originKind, sourceLineRef,
            bookingDate, valueDate, amountMinor, currency, counterpartyName,
            memo, reference, taxCode, balanceAfterMinor, reviewState,
            counterpartyId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            transactionId,
            financialAccountId,
            nil,
            "bankStatement",
            "legacy-v13-row-9",
            "2026-05-13T00:00:00Z",
            "2026-05-13T00:00:00Z",
            -3_400,
            "CHF",
            "LegacyV13Vendor AG",
            "legacyv13payment ergonomic keyboard",
            "V13-SEARCH-9",
            "CH-VAT-INPUT-STD",
            45_600,
            "pending",
            counterpartyId,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO issues (
            id, fingerprint, workspaceId, entityId, taxYearId, issueCode,
            severity, status, summary, objectRef, relatedRef,
            firstDetectedAt, lastDetectedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            issueId,
            "legacy-v13-global-search-issue",
            workspaceId,
            entityId,
            taxYearId,
            "missingExpenseEvidence",
            "warning",
            "open",
            "legacyv13expense missing receipt for keyboard",
            "transaction|\(transactionId)",
            nil,
            createdAt,
            createdAt,
        ]
    )
}

private func installLegacyV14AgentProposalRows(
    into db: Database,
    workspaceId: String,
    proposalId: String,
    importJobId: String
) throws {
    let createdAt = "2026-05-30T08:00:00Z"
    try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
    for identifier in AlpenLedgerDatabaseMigrations.identifiers.prefix(while: {
        $0 != AlpenLedgerDatabaseMigrations.v15AgentProposalUncertaintyMetadata
    }) {
        try db.execute(
            sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
            arguments: [identifier]
        )
    }

    try db.execute(sql: """
    CREATE TABLE workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        storageVersion INTEGER NOT NULL,
        createdAt DATETIME NOT NULL,
        defaultCurrency TEXT NOT NULL,
        privacyMode TEXT NOT NULL,
        encryptionSaltRef TEXT NOT NULL
    )
    """)

    try db.execute(sql: """
    CREATE TABLE importJobs (
        id TEXT PRIMARY KEY,
        workspaceId TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        kind TEXT NOT NULL,
        source TEXT NOT NULL,
        parserKey TEXT NOT NULL,
        parserVersion TEXT NOT NULL,
        status TEXT NOT NULL,
        startedAt DATETIME NOT NULL,
        completedAt DATETIME,
        warningCount INTEGER NOT NULL
    )
    """)

    try db.execute(sql: """
    CREATE TABLE legalEntities (
        id TEXT PRIMARY KEY,
        workspaceId TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        kind TEXT NOT NULL,
        legalName TEXT NOT NULL,
        displayName TEXT NOT NULL,
        country TEXT NOT NULL,
        canton TEXT,
        taxIdOrUID TEXT,
        fiscalYearStartMonth INTEGER NOT NULL,
        fiscalYearStartDay INTEGER NOT NULL,
        parentEntityId TEXT
    )
    """)

    try db.execute(sql: """
    CREATE TABLE taxYears (
        id TEXT PRIMARY KEY,
        entityId TEXT NOT NULL REFERENCES legalEntities(id) ON DELETE CASCADE,
        year INTEGER NOT NULL,
        periodStart DATETIME NOT NULL,
        periodEnd DATETIME NOT NULL,
        canton TEXT,
        filingMode TEXT NOT NULL,
        rulesetVersion TEXT NOT NULL,
        status TEXT NOT NULL
    )
    """)

    try db.execute(sql: """
    CREATE TABLE agentProposals (
        id TEXT PRIMARY KEY,
        fingerprint TEXT NOT NULL,
        workspaceId TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        agentKind TEXT NOT NULL,
        proposalType TEXT NOT NULL,
        targetRef TEXT NOT NULL,
        relatedRef TEXT,
        summary TEXT NOT NULL,
        rationale TEXT NOT NULL,
        confidence DOUBLE NOT NULL,
        status TEXT NOT NULL,
        createdAt DATETIME NOT NULL,
        decidedAt DATETIME,
        decidedBy TEXT,
        decisionReason TEXT
    )
    """)

    try db.execute(
        sql: """
        INSERT INTO workspaces (
            id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            workspaceId,
            "Legacy Proposal Workspace",
            1,
            createdAt,
            "CHF",
            "localOnly",
            "workspace.json",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO importJobs (
            id, workspaceId, kind, source, parserKey, parserVersion,
            status, startedAt, completedAt, warningCount
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            importJobId,
            workspaceId,
            "document",
            "legacy-receipt.pdf",
            "document.text.v1",
            "1.0.0",
            "completed",
            createdAt,
            "2026-05-30T08:01:00Z",
            0,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO agentProposals (
            id, fingerprint, workspaceId, agentKind, proposalType, targetRef,
            relatedRef, summary, rationale, confidence, status, createdAt,
            decidedAt, decidedBy, decisionReason
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            proposalId,
            "legacy-proposal:receipt-match",
            workspaceId,
            "reconciliation",
            "documentMatch",
            "transaction:legacy-expense",
            "document:legacy-receipt",
            "Match receipt to imported expense.",
            "Legacy proposal created before uncertainty metadata existed.",
            0.82,
            "pending",
            createdAt,
            nil,
            nil,
            nil,
        ]
    )
}

private func installLegacyV17AgentAndImportRows(
    into db: Database,
    workspaceId: String,
    entityId: String,
    taxYearId: String,
    importJobId: String,
    conversationId: String,
    userMessageId: String,
    assistantMessageId: String,
    pendingApprovalId: String
) throws {
    let createdAt = "2026-05-30T09:00:00Z"
    try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
    for identifier in AlpenLedgerDatabaseMigrations.identifiers.prefix(while: {
        $0 != AlpenLedgerDatabaseMigrations.v18ImportJobSourceTracking
    }) {
        try db.execute(
            sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
            arguments: [identifier]
        )
    }

    try db.execute(sql: """
    CREATE TABLE workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        storageVersion INTEGER NOT NULL,
        createdAt DATETIME NOT NULL,
        defaultCurrency TEXT NOT NULL,
        privacyMode TEXT NOT NULL,
        encryptionSaltRef TEXT NOT NULL
    )
    """)

    try db.execute(sql: """
    CREATE TABLE legalEntities (
        id TEXT PRIMARY KEY,
        workspaceId TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        kind TEXT NOT NULL,
        legalName TEXT NOT NULL,
        displayName TEXT NOT NULL,
        country TEXT NOT NULL,
        canton TEXT,
        taxIdOrUID TEXT,
        fiscalYearStartMonth INTEGER NOT NULL,
        fiscalYearStartDay INTEGER NOT NULL,
        parentEntityId TEXT
    )
    """)

    try db.execute(sql: """
    CREATE TABLE taxYears (
        id TEXT PRIMARY KEY,
        entityId TEXT NOT NULL REFERENCES legalEntities(id) ON DELETE CASCADE,
        year INTEGER NOT NULL,
        periodStart DATETIME NOT NULL,
        periodEnd DATETIME NOT NULL,
        canton TEXT,
        filingMode TEXT NOT NULL,
        rulesetVersion TEXT NOT NULL,
        status TEXT NOT NULL
    )
    """)

    try db.execute(sql: """
    CREATE TABLE importJobs (
        id TEXT PRIMARY KEY,
        workspaceId TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        kind TEXT NOT NULL,
        source TEXT NOT NULL,
        parserKey TEXT NOT NULL,
        parserVersion TEXT NOT NULL,
        status TEXT NOT NULL,
        startedAt DATETIME NOT NULL,
        completedAt DATETIME,
        warningCount INTEGER NOT NULL
    )
    """)

    try db.execute(sql: """
    CREATE TABLE agentConversations (
        id TEXT PRIMARY KEY,
        workspaceId TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        activeEntityId TEXT REFERENCES legalEntities(id) ON DELETE SET NULL,
        activeTaxYearId TEXT REFERENCES taxYears(id) ON DELETE SET NULL,
        status TEXT NOT NULL,
        createdAt DATETIME NOT NULL,
        updatedAt DATETIME NOT NULL
    )
    """)

    try db.execute(sql: """
    CREATE TABLE agentMessages (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL REFERENCES agentConversations(id) ON DELETE CASCADE,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        sourceRefs TEXT NOT NULL DEFAULT '[]',
        unresolvedQuestions TEXT NOT NULL DEFAULT '[]',
        providerID TEXT,
        promptTemplateID TEXT,
        sentDataOffDevice BOOLEAN NOT NULL DEFAULT 0,
        createdAt DATETIME NOT NULL
    )
    """)

    try db.execute(sql: """
    CREATE TABLE agentPendingApprovals (
        id TEXT PRIMARY KEY,
        conversationId TEXT NOT NULL REFERENCES agentConversations(id) ON DELETE CASCADE,
        toolName TEXT NOT NULL,
        inputHash TEXT NOT NULL,
        inputSummary TEXT NOT NULL,
        requiredScopes TEXT NOT NULL DEFAULT '[]',
        targetRefs TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL,
        requestedBy TEXT NOT NULL,
        requestedAt DATETIME NOT NULL,
        decidedBy TEXT,
        decidedAt DATETIME,
        decisionReason TEXT
    )
    """)

    try db.execute(
        sql: """
        INSERT INTO workspaces (
            id, name, storageVersion, createdAt, defaultCurrency, privacyMode, encryptionSaltRef
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            workspaceId,
            "Legacy Agent Workspace",
            1,
            createdAt,
            "CHF",
            "localOnly",
            "workspace.json",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO legalEntities (
            id, workspaceId, kind, legalName, displayName, country, canton,
            taxIdOrUID, fiscalYearStartMonth, fiscalYearStartDay, parentEntityId
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            entityId,
            workspaceId,
            "naturalPerson",
            "Legacy Agent Taxpayer",
            "Legacy Agent Taxpayer",
            "CH",
            "ZH",
            nil,
            1,
            1,
            nil,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO taxYears (
            id, entityId, year, periodStart, periodEnd, canton,
            filingMode, rulesetVersion, status
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            taxYearId,
            entityId,
            2026,
            "2026-01-01T00:00:00Z",
            "2026-12-31T23:59:59Z",
            "ZH",
            "single",
            "ch-zh-2026-v1",
            "open",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO importJobs (
            id, workspaceId, kind, source, parserKey, parserVersion,
            status, startedAt, completedAt, warningCount
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            importJobId,
            workspaceId,
            "bankStatementCSV",
            "legacy-bank-statement.csv",
            "csv.generic",
            "1.0.0",
            "completed",
            createdAt,
            "2026-05-30T09:01:00Z",
            0,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO agentConversations (
            id, workspaceId, title, activeEntityId, activeTaxYearId,
            status, createdAt, updatedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            conversationId,
            workspaceId,
            "Legacy readiness question",
            entityId,
            taxYearId,
            "active",
            createdAt,
            "2026-05-30T09:01:00Z",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO agentMessages (
            id, conversationId, role, content, sourceRefs,
            unresolvedQuestions, providerID, promptTemplateID,
            sentDataOffDevice, createdAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            userMessageId,
            conversationId,
            "user",
            "What is missing for my Zurich return?",
            "[]",
            "[]",
            nil,
            nil,
            false,
            createdAt,
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO agentMessages (
            id, conversationId, role, content, sourceRefs,
            unresolvedQuestions, providerID, promptTemplateID,
            sentDataOffDevice, createdAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            assistantMessageId,
            conversationId,
            "assistant",
            "One draft journal entry still needs approval.",
            #"[{"kind":"taxYear","id":"\#(taxYearId)"}]"#,
            #"["Review JE-2026-099 before posting."]"#,
            "local.rules",
            "tax.readiness.answer.v1",
            false,
            "2026-05-30T09:01:00Z",
        ]
    )

    try db.execute(
        sql: """
        INSERT INTO agentPendingApprovals (
            id, conversationId, toolName, inputHash, inputSummary,
            requiredScopes, targetRefs, status, requestedBy, requestedAt
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        arguments: [
            pendingApprovalId,
            conversationId,
            "ledger.apply_draft_entry",
            AgentToolInputHash.hash(Data(#"{"entryNumber":"JE-2026-099"}"#.utf8)),
            "Post reviewed year-end journal entry JE-2026-099.",
            #"["ledger.write"]"#,
            #"[{"kind":"taxYear","id":"\#(taxYearId)"}]"#,
            "pending",
            "assistant",
            "2026-05-30T09:01:30Z",
        ]
    )
}
