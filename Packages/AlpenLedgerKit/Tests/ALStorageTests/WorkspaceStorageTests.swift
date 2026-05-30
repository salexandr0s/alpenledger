import Foundation
import GRDB
import Testing
@testable import ALAudit
@testable import ALDomain
@testable import ALTaxCore
@testable import ALWorkspace
@testable import ALStorage

private enum TestDateError: Error {
    case invalidDate(String)
}

private enum MigrationRecoveryTestError: Error {
    case injectedFailure
}

private extension Date {
    static func alpenLedgerTestDate(_ string: String) throws -> Date {
        guard let date = ISO8601DateFormatter().date(from: string) else {
            throw TestDateError.invalidDate(string)
        }
        return date
    }
}

@Test
func workspaceServiceCreatesEncryptedWorkspaceInTempDirectory() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)

    let storage = try workspaceService.createWorkspace(named: "Spec Workspace")

    #expect(FileManager.default.fileExists(atPath: storage.paths.databaseURL.path))
    #expect(FileManager.default.fileExists(atPath: storage.paths.manifestURL.path))
    #expect(try storage.workspaceRepository.fetchWorkspace()?.name == "Spec Workspace")
    #expect((try storage.auditEventRepository.fetchAuditEvents(workspaceId: storage.manifest.workspace.id, objectRef: nil)).isEmpty == false)
}

@Test
func workspaceDatabaseHealthReportPassesForFreshWorkspace() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)

    let storage = try workspaceService.createWorkspace(named: "Health Workspace")
    let report = try storage.databaseHealthReport()

    #expect(report.isHealthy)
    #expect(report.quickCheckResult == "ok")
    #expect(report.foreignKeysEnabled)
    #expect(report.foreignKeyViolationCount == 0)
    #expect(report.expectedMigrationIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)
    #expect(report.appliedMigrationIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)
    #expect(report.missingRequiredTables.isEmpty)
    #expect(report.missingRequiredViews.isEmpty)
    #expect(report.pageCount > 0)
    #expect(report.issues.isEmpty)
}

@Test
func workspaceDatabaseHealthReportFlagsMissingMigrationLedgerRows() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Migration Health Workspace")

    try storage.inTransaction { db in
        try db.execute(
            sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
            arguments: [AlpenLedgerDatabaseMigrations.v7AgentProposalRelatedRef]
        )
    }

    let report = try storage.databaseHealthReport()

    #expect(report.isHealthy == false)
    #expect(report.appliedMigrationIdentifiers.contains(AlpenLedgerDatabaseMigrations.v7AgentProposalRelatedRef) == false)
    #expect(report.issues.contains { issue in
        issue.code == "migrations-missing" &&
        issue.severity == .blocker &&
        issue.summary.contains(AlpenLedgerDatabaseMigrations.v7AgentProposalRelatedRef)
    })
}

@Test
func workspaceDatabaseHealthReportFlagsMissingRequiredViews() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Reporting View Health Workspace")

    try storage.inTransaction { db in
        try db.execute(sql: "DROP VIEW vw_cashflow_by_entity")
    }

    let report = try storage.databaseHealthReport()

    #expect(report.isHealthy == false)
    #expect(report.missingRequiredViews == ["vw_cashflow_by_entity"])
    #expect(report.issues.contains { issue in
        issue.code == "required-views-missing" &&
        issue.severity == .blocker &&
        issue.summary.contains("vw_cashflow_by_entity")
    })
}

@Test
func workspaceStorageManagerRestoresDatabaseSnapshotWhenMigrationFails() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let secretStore = InMemorySecretStore()
    let storageManager = WorkspaceStorageManager(
        secretStore: secretStore,
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Migration Recovery Workspace")
    let workspaceRootURL = storage.paths.rootURL
    let recoveryRootURL = workspaceRootURL.appendingPathComponent(".migration-recovery", isDirectory: true)

    try storage.inTransaction { db in
        try db.execute(
            sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
            arguments: [AlpenLedgerDatabaseMigrations.v21AccountOpeningBalances]
        )
    }
    try storage.dbPool.close()

    let failingStorageManager = WorkspaceStorageManager(
        secretStore: secretStore,
        databaseMigrator: { dbPool in
            try dbPool.writeWithoutTransaction { db in
                try db.execute(sql: "CREATE TABLE migrationFailureMarker (id TEXT PRIMARY KEY)")
            }
            throw MigrationRecoveryTestError.injectedFailure
        },
        workspacesRootURL: rootURL
    )

    #expect(throws: MigrationRecoveryTestError.self) {
        _ = try failingStorageManager.openWorkspace(at: workspaceRootURL)
    }
    #expect(FileManager.default.fileExists(atPath: recoveryRootURL.path))

    let reopenedStorage = try storageManager.openWorkspace(at: workspaceRootURL)
    #expect(try reopenedStorage.workspaceRepository.fetchWorkspace()?.name == "Migration Recovery Workspace")
    try reopenedStorage.dbPool.read { db in
        #expect(try db.tableExists("migrationFailureMarker") == false)
        let appliedIdentifiers = try String.fetchAll(
            db,
            sql: "SELECT identifier FROM grdb_migrations ORDER BY rowid"
        )
        #expect(appliedIdentifiers == AlpenLedgerDatabaseMigrations.identifiers)
    }
    #expect(FileManager.default.fileExists(atPath: recoveryRootURL.path) == false)
}

@Test
func workspaceReportingViewsExposeReadOnlyScopedSummaries() throws {
    let fixedNow = try Date.alpenLedgerTestDate("2026-04-20T12:00:00Z")
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        nowProvider: { fixedNow }
    )
    let storage = try workspaceService.createWorkspace(named: "Reporting Views Workspace")
    let entity = try #require(
        try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first
    )
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)

    let importJob = ImportJob(
        workspaceId: storage.manifest.workspace.id,
        kind: .bankStatementCSV,
        source: "imports/reporting-april.csv",
        parserKey: "csv.bank.v1",
        parserVersion: "1.0",
        status: .completed,
        startedAt: fixedNow,
        completedAt: fixedNow,
        warningCount: 0
    )
    try storage.importJobRepository.saveImportJob(importJob)

    let statement = StatementImport(
        accountId: account.id,
        importJobId: importJob.id,
        sourceBlobHash: "reporting-view-statement",
        sourceFormat: "csv",
        sourceFingerprint: "reporting-views-2026-04",
        coverageStart: try Date.alpenLedgerTestDate("2026-04-01T00:00:00Z"),
        coverageEnd: try Date.alpenLedgerTestDate("2026-04-30T23:59:59Z"),
        openingBalanceMinor: 100_000,
        closingBalanceMinor: 577_655,
        parserVersion: "1.0"
    )
    try storage.statementImportRepository.saveStatementImport(statement)

    let incomeTransaction = Transaction(
        accountId: account.id,
        statementImportId: statement.id,
        sourceLineRef: "reporting-april.csv:2",
        bookingDate: try Date.alpenLedgerTestDate("2026-04-12T00:00:00Z"),
        amountMinor: 500_000,
        currency: .chf,
        counterpartyName: "Client GmbH",
        memo: "Client invoice RV-1",
        reference: "RV-1",
        taxCode: "CH-VAT-OUTPUT-STD",
        balanceAfterMinor: 600_000,
        reviewState: .reviewed
    )
    let missingEvidenceExpense = Transaction(
        accountId: account.id,
        statementImportId: statement.id,
        sourceLineRef: "reporting-april.csv:3",
        bookingDate: try Date.alpenLedgerTestDate("2026-04-13T00:00:00Z"),
        amountMinor: -12_345,
        currency: .chf,
        counterpartyName: "Supply AG",
        memo: "Office supplies",
        reference: "SUP-1",
        taxCode: "CH-VAT-INPUT-STD",
        balanceAfterMinor: 587_655
    )
    let matchedExpense = Transaction(
        accountId: account.id,
        statementImportId: statement.id,
        sourceLineRef: "reporting-april.csv:4",
        bookingDate: try Date.alpenLedgerTestDate("2026-04-14T00:00:00Z"),
        amountMinor: -10_000,
        currency: .chf,
        counterpartyName: "Receipt AG",
        memo: "Matched receipt",
        reference: "REC-1",
        taxCode: "CH-VAT-INPUT-STD",
        balanceAfterMinor: 577_655,
        reviewState: .reviewed
    )
    try storage.transactionRepository.saveTransactions([
        incomeTransaction,
        missingEvidenceExpense,
        matchedExpense,
    ])

    try storage.evidenceLinkRepository.saveEvidenceLink(
        EvidenceLink(
            sourceRef: ObjectRef(kind: .document, id: UUID()),
            targetRef: ObjectRef(kind: .transaction, id: matchedExpense.id.rawValue),
            status: .confirmed,
            confidence: 0.99,
            createdByKind: .agent,
            approvalRequired: false,
            reason: "Receipt amount and reference match."
        )
    )

    let issue = Issue(
        fingerprint: "reporting-view-missing-expense-evidence",
        workspaceId: storage.manifest.workspace.id,
        entityId: entity.id,
        taxYearId: taxYear.id,
        issueCode: .missingExpenseEvidence,
        severity: .warning,
        status: .open,
        summary: "Missing receipt for Supply AG",
        objectRef: ObjectRef(kind: .transaction, id: missingEvidenceExpense.id.rawValue),
        firstDetectedAt: fixedNow,
        lastDetectedAt: fixedNow
    )
    try storage.issueRepository.saveIssue(issue)

    let taxFact = TaxFact(
        fingerprint: "reporting-view-tax-fact",
        entityId: entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "personal.income.self_employment_gross",
        valueType: .money,
        moneyMinor: 500_000,
        currency: .chf,
        status: .observed,
        rulesetVersion: "zh-personal-2026-v1",
        provenanceRefs: [
            ObjectRef(kind: .transaction, id: incomeTransaction.id.rawValue),
        ],
        confidence: 1.0,
        createdAt: fixedNow,
        updatedAt: fixedNow
    )
    try storage.taxFactRepository.saveTaxFact(taxFact)

    let vatPeriod = VATPeriod(
        entityId: entity.id,
        periodStart: try Date.alpenLedgerTestDate("2026-04-01T00:00:00Z"),
        periodEnd: try Date.alpenLedgerTestDate("2026-06-30T23:59:59Z"),
        currency: .chf
    )
    try storage.vatPeriodRepository.saveVATPeriod(vatPeriod)

    try storage.dbPool.read { db in
        let fetchedSpendRow = try Row.fetchOne(
            db,
            sql: """
            SELECT spendMinor, transactionCount
            FROM vw_spend_by_month
            WHERE entityId = ? AND yearMonth = ? AND currency = ?
            """,
            arguments: [entity.id, "2026-04", "CHF"]
        )
        let spendRow = try #require(fetchedSpendRow)
        let spendMinor: Int64 = spendRow["spendMinor"]
        let spendTransactionCount: Int = spendRow["transactionCount"]
        #expect(spendMinor == 22_345)
        #expect(spendTransactionCount == 2)

        let fetchedCashflowRow = try Row.fetchOne(
            db,
            sql: """
            SELECT inflowMinor, outflowMinor, netMinor, transactionCount
            FROM vw_cashflow_by_entity
            WHERE entityId = ? AND yearMonth = ? AND currency = ?
            """,
            arguments: [entity.id, "2026-04", "CHF"]
        )
        let cashflowRow = try #require(fetchedCashflowRow)
        let inflowMinor: Int64 = cashflowRow["inflowMinor"]
        let outflowMinor: Int64 = cashflowRow["outflowMinor"]
        let netMinor: Int64 = cashflowRow["netMinor"]
        let cashflowTransactionCount: Int = cashflowRow["transactionCount"]
        #expect(inflowMinor == 500_000)
        #expect(outflowMinor == 22_345)
        #expect(netMinor == 477_655)
        #expect(cashflowTransactionCount == 3)

        let missingEvidenceCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_missing_evidence WHERE issueId = ?",
            arguments: [issue.id]
        )
        #expect(missingEvidenceCount == 1)

        let statementCoverageCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_statement_coverage WHERE statementImportId = ? AND accountId = ?",
            arguments: [statement.id, account.id]
        )
        #expect(statementCoverageCount == 1)

        let taxFactCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_tax_fact_status WHERE taxFactId = ? AND isCurrent = 1",
            arguments: [taxFact.id]
        )
        #expect(taxFactCount == 1)

        let unmatchedExpenseCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_unmatched_transactions WHERE transactionId = ?",
            arguments: [missingEvidenceExpense.id]
        )
        let matchedExpenseCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_unmatched_transactions WHERE transactionId = ?",
            arguments: [matchedExpense.id]
        )
        #expect(unmatchedExpenseCount == 1)
        #expect(matchedExpenseCount == 0)

        let fetchedVATRow = try Row.fetchOne(
            db,
            sql: """
            SELECT transactionCount, missingTaxCodeCount, outputBaseMinor, inputBaseMinor, netCashflowMinor
            FROM vw_vat_reconciliation
            WHERE vatPeriodId = ?
            """,
            arguments: [vatPeriod.id]
        )
        let vatRow = try #require(fetchedVATRow)
        let vatTransactionCount: Int = vatRow["transactionCount"]
        let missingTaxCodeCount: Int = vatRow["missingTaxCodeCount"]
        let outputBaseMinor: Int64 = vatRow["outputBaseMinor"]
        let inputBaseMinor: Int64 = vatRow["inputBaseMinor"]
        let netCashflowMinor: Int64 = vatRow["netCashflowMinor"]
        #expect(vatTransactionCount == 3)
        #expect(missingTaxCodeCount == 0)
        #expect(outputBaseMinor == 500_000)
        #expect(inputBaseMinor == 22_345)
        #expect(netCashflowMinor == 477_655)
    }

    try storage.inTransaction { db in
        do {
            try db.execute(
                sql: """
                INSERT INTO vw_cashflow_by_entity (
                    workspaceId,
                    entityId,
                    yearMonth,
                    currency,
                    inflowMinor,
                    outflowMinor,
                    netMinor,
                    transactionCount
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    storage.manifest.workspace.id,
                    entity.id,
                    "2026-04",
                    "CHF",
                    1,
                    0,
                    1,
                    1,
                ]
            )
            Issue.record("Expected reporting view inserts to be rejected.")
        } catch {}
    }
}

@Test
func workspaceGlobalSearchFindsDocumentsTransactionsCounterpartiesAndIssues() throws {
    let fixedNow = try Date.alpenLedgerTestDate("2026-04-22T12:00:00Z")
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        nowProvider: { fixedNow }
    )
    let storage = try workspaceService.createWorkspace(named: "Global Search Workspace")
    let entity = try #require(
        try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first
    )
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)

    let document = Document(
        workspaceId: storage.manifest.workspace.id,
        blobHash: "global-search-document-blob",
        originalFilename: "salary-certificate-global.pdf",
        mediaType: "application/pdf",
        documentType: .salaryCertificate,
        issueDate: fixedNow,
        detectedEntityId: entity.id,
        entityId: entity.id,
        extractedText: "alphapine salary certificate for Zurich filing readiness",
        metadataStatus: .confirmed
    )
    try storage.documentRepository.saveDocument(document)

    let transaction = Transaction(
        accountId: account.id,
        sourceLineRef: "global-search-row-1",
        bookingDate: fixedNow,
        amountMinor: -4_560,
        currency: .chf,
        counterpartyName: "Globex Search AG",
        memo: "ergomonitor subscription stand",
        reference: "GS-2026",
        taxCode: "CH-VAT-INPUT-STD"
    )
    try storage.transactionRepository.saveTransactions([transaction])
    let savedTransaction = try #require(try storage.transactionRepository.fetchTransactions(ids: [transaction.id]).first)
    let counterpartyId = try #require(savedTransaction.counterpartyId)

    let issue = Issue(
        fingerprint: "global-search-missing-ergomonitor-receipt",
        workspaceId: storage.manifest.workspace.id,
        entityId: entity.id,
        taxYearId: taxYear.id,
        issueCode: .missingExpenseEvidence,
        severity: .warning,
        status: .open,
        summary: "Missing receipt for ergomonitor stand",
        objectRef: ObjectRef(kind: .transaction, id: savedTransaction.id.rawValue),
        firstDetectedAt: fixedNow,
        lastDetectedAt: fixedNow
    )
    try storage.issueRepository.saveIssue(issue)
    try storage.issueRepository.saveIssue(
        Issue(
            fingerprint: "global-search-missing-second-ergomonitor-receipt",
            workspaceId: storage.manifest.workspace.id,
            entityId: entity.id,
            taxYearId: taxYear.id,
            issueCode: .missingExpenseEvidence,
            severity: .warning,
            status: .open,
            summary: "Second missing receipt for ergomonitor stand",
            objectRef: ObjectRef(kind: .transaction, id: savedTransaction.id.rawValue),
            firstDetectedAt: fixedNow,
            lastDetectedAt: fixedNow
        )
    )
    #expect(try storage.databaseHealthReport().isHealthy)

    let documentHits = try storage.searchIndex.search(
        workspaceId: storage.manifest.workspace.id,
        query: "alphapine",
        limit: 10
    )
    #expect(documentHits.contains { hit in
        hit.objectRef == ObjectRef(kind: .document, id: document.id.rawValue) &&
        hit.workspaceId == storage.manifest.workspace.id &&
        hit.entityId == entity.id &&
        hit.objectKind == .document &&
        hit.title == "salary-certificate-global.pdf" &&
        hit.snippet.isEmpty == false
    })

    let monitorHits = try storage.searchIndex.search(
        workspaceId: storage.manifest.workspace.id,
        query: "ergomonitor",
        limit: 10
    )
    #expect(monitorHits.contains {
        $0.objectRef == ObjectRef(kind: .transaction, id: savedTransaction.id.rawValue) &&
        $0.objectKind == .transaction &&
        $0.entityId == entity.id
    })
    #expect(monitorHits.contains {
        $0.objectRef == ObjectRef(kind: .issue, id: issue.id.rawValue) &&
        $0.objectKind == .issue &&
        $0.entityId == entity.id
    })

    let counterpartyHits = try storage.searchIndex.search(
        workspaceId: storage.manifest.workspace.id,
        query: "Globex",
        limit: 10
    )
    #expect(counterpartyHits.contains {
        $0.objectRef == ObjectRef(kind: .counterparty, id: counterpartyId.rawValue) &&
        $0.objectKind == .counterparty &&
        $0.title == "Globex Search AG" &&
        $0.entityId == entity.id
    })
    #expect(try storage.searchIndex.search(
        workspaceId: storage.manifest.workspace.id,
        query: "",
        limit: 10
    ).isEmpty)
}

@Test
func workspaceGlobalSearchStaysBoundedOnLargerWorkspace() throws {
    let fixedNow = try Date.alpenLedgerTestDate("2026-04-22T12:00:00Z")
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        nowProvider: { fixedNow }
    )
    let storage = try workspaceService.createWorkspace(named: "Large Global Search Workspace")
    let entity = try #require(
        try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first
    )
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)

    let documentCount = 1_500
    let transactionCount = 1_500
    let issueCount = 750
    let targetIndex = 1_234
    let needle = "needlezurichalpha"

    let expectedDocumentId = DocumentID()
    var expectedTransactionId: TransactionID?
    var expectedCounterpartyId: CounterpartyID?
    var expectedIssueId: IssueID?

    try storage.inTransaction { db in
        for index in 0..<documentCount {
            let isTarget = index == targetIndex
            let document = Document(
                id: isTarget ? expectedDocumentId : DocumentID(),
                workspaceId: storage.manifest.workspace.id,
                blobHash: "large-search-document-\(index)",
                originalFilename: "statement-\(index).pdf",
                mediaType: "application/pdf",
                documentType: index.isMultiple(of: 3) ? .bankStatement : .receipt,
                issueDate: fixedNow.addingTimeInterval(TimeInterval(index)),
                detectedEntityId: entity.id,
                entityId: entity.id,
                extractedText: isTarget
                    ? "\(needle) annual Zurich salary certificate and receipt bundle"
                    : "routine workspace document \(index) invoice receipt statement",
                metadataStatus: .confirmed
            )
            try document.insert(db)
        }

        for index in 0..<transactionCount {
            let isTarget = index == targetIndex
            let transaction = Transaction(
                accountId: account.id,
                sourceLineRef: "large-search-row-\(index)",
                bookingDate: fixedNow.addingTimeInterval(TimeInterval(index * 60)),
                amountMinor: Int64(index.isMultiple(of: 2) ? 10_000 + index : -2_500 - index),
                currency: .chf,
                counterpartyName: isTarget ? "\(needle) AG" : "Vendor \(index) AG",
                memo: isTarget
                    ? "\(needle) monitor subscription and business support"
                    : "office expense subscription \(index)",
                reference: "LS-\(index)",
                taxCode: index.isMultiple(of: 2) ? "CH-VAT-OUTPUT-STD" : "CH-VAT-INPUT-STD",
                reviewState: index.isMultiple(of: 2) ? .reviewed : .pending
            )
            let linkedTransaction = try transactionByEnsuringCounterparty(transaction, in: db)
            try linkedTransaction.insert(db)

            if isTarget {
                expectedTransactionId = linkedTransaction.id
                expectedCounterpartyId = linkedTransaction.counterpartyId
            }
        }

        let targetObjectRef = ObjectRef(kind: .transaction, id: try #require(expectedTransactionId).rawValue)
        for index in 0..<issueCount {
            let isTarget = index == issueCount - 1
            let issue = Issue(
                fingerprint: "large-search-issue-\(index)",
                workspaceId: storage.manifest.workspace.id,
                entityId: entity.id,
                taxYearId: taxYear.id,
                issueCode: .missingExpenseEvidence,
                severity: index.isMultiple(of: 5) ? .blocking : .warning,
                status: .open,
                summary: isTarget
                    ? "Missing evidence for \(needle) support subscription"
                    : "Missing evidence for routine workspace item \(index)",
                objectRef: targetObjectRef,
                firstDetectedAt: fixedNow,
                lastDetectedAt: fixedNow
            )
            if isTarget {
                expectedIssueId = issue.id
            }
            try issue.insert(db)
        }
    }

    let targetTransactionId = try #require(expectedTransactionId)
    let targetCounterpartyId = try #require(expectedCounterpartyId)
    let targetIssueId = try #require(expectedIssueId)

    let indexedRecordCount: Int = try storage.dbPool.read { db in
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM globalSearchRecords") ?? 0
    }
    #expect(indexedRecordCount >= documentCount + transactionCount + issueCount)

    let searchStart = Date()
    let hits = try storage.searchIndex.search(
        workspaceId: storage.manifest.workspace.id,
        query: needle,
        limit: 8
    )
    let elapsed = Date().timeIntervalSince(searchStart)

    if enforcePerformanceBudgets {
        #expect(elapsed < 1.0)
    }
    #expect(hits.count <= 8)
    #expect(hits.contains {
        $0.objectRef == ObjectRef(kind: .document, id: expectedDocumentId.rawValue) &&
        $0.objectKind == .document
    })
    #expect(hits.contains {
        $0.objectRef == ObjectRef(kind: .transaction, id: targetTransactionId.rawValue) &&
        $0.objectKind == .transaction
    })
    #expect(hits.contains {
        $0.objectRef == ObjectRef(kind: .counterparty, id: targetCounterpartyId.rawValue) &&
        $0.objectKind == .counterparty
    })
    #expect(hits.contains {
        $0.objectRef == ObjectRef(kind: .issue, id: targetIssueId.rawValue) &&
        $0.objectKind == .issue
    })
}

@Test
func workspaceReportingViewsScopedLookupsAndRestoreStayBoundedOnLargerWorkspace() throws {
    let fixedNow = try Date.alpenLedgerTestDate("2026-05-01T12:00:00Z")
    let periodStart = try Date.alpenLedgerTestDate("2026-01-01T00:00:00Z")
    let periodEnd = try Date.alpenLedgerTestDate("2026-12-31T23:59:59Z")
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("large-query-workspace.alpenledgerbackup", isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        nowProvider: { fixedNow }
    )
    let storage = try workspaceService.createWorkspace(named: "Large Query Workspace")
    let entity = try #require(
        try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first
    )
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
    let account = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: entity.id).first)

    let statementCount = 48
    let transactionCount = 3_600
    let matchedTransactionStride = 3
    let issueCount = 900
    let taxFactCount = 900
    var statementIds: [StatementImportID] = []
    var transactionIds: [TransactionID] = []
    var matchedTransactionIds: [TransactionID] = []

    try storage.inTransaction { db in
        let importJob = ImportJob(
            workspaceId: storage.manifest.workspace.id,
            kind: .bankStatementCSV,
            source: "imports/large-query-workspace.csv",
            parserKey: "csv.bank.v1",
            parserVersion: "1.0",
            status: .completed,
            startedAt: fixedNow,
            completedAt: fixedNow,
            warningCount: 0
        )
        try importJob.insert(db)

        for index in 0..<statementCount {
            let coverageStart = periodStart.addingTimeInterval(TimeInterval(index * 7 * 86_400))
            let statement = StatementImport(
                accountId: account.id,
                importJobId: importJob.id,
                sourceBlobHash: "large-query-statement-\(index)",
                sourceFormat: "csv",
                sourceFingerprint: "large-query-2026-\(index)",
                coverageStart: coverageStart,
                coverageEnd: coverageStart.addingTimeInterval(TimeInterval(6 * 86_400 + 86_399)),
                openingBalanceMinor: Int64(index * 10_000),
                closingBalanceMinor: Int64((index + 1) * 10_000),
                parserVersion: "1.0"
            )
            statementIds.append(statement.id)
            try statement.insert(db)
        }

        for index in 0..<transactionCount {
            let isIncome = index.isMultiple(of: 4)
            let transaction = Transaction(
                accountId: account.id,
                statementImportId: statementIds[index % statementIds.count],
                sourceLineRef: "large-query-row-\(index)",
                bookingDate: periodStart.addingTimeInterval(TimeInterval((index % 360) * 86_400)),
                amountMinor: isIncome ? Int64(50_000 + index) : -Int64(3_000 + index),
                currency: .chf,
                counterpartyName: "Performance Vendor \(index % 120) AG",
                memo: isIncome ? "Consulting invoice \(index)" : "Business expense \(index)",
                reference: "LQ-\(index)",
                taxCode: isIncome ? "CH-VAT-OUTPUT-STD" : "CH-VAT-INPUT-STD",
                balanceAfterMinor: Int64(index * 100),
                reviewState: index.isMultiple(of: 5) ? .reviewed : .pending
            )
            let linkedTransaction = try transactionByEnsuringCounterparty(transaction, in: db)
            try linkedTransaction.insert(db)
            transactionIds.append(linkedTransaction.id)

            if index.isMultiple(of: matchedTransactionStride) {
                matchedTransactionIds.append(linkedTransaction.id)
                try EvidenceLink(
                    sourceRef: ObjectRef(kind: .document, id: UUID()),
                    targetRef: ObjectRef(kind: .transaction, id: linkedTransaction.id.rawValue),
                    linkType: .documentToTransaction,
                    status: .confirmed,
                    confidence: 0.98,
                    createdByKind: .user,
                    approvalRequired: false,
                    reason: "Large workspace matched receipt \(index)."
                ).insert(db)
            }
        }

        for index in 0..<issueCount {
            try Issue(
                fingerprint: "large-query-issue-\(index)",
                workspaceId: storage.manifest.workspace.id,
                entityId: entity.id,
                taxYearId: taxYear.id,
                issueCode: index.isMultiple(of: 2) ? .missingExpenseEvidence : .missingStatementCoverage,
                severity: index.isMultiple(of: 7) ? .blocking : .warning,
                status: .open,
                summary: "Large workspace missing evidence item \(index)",
                objectRef: ObjectRef(kind: .transaction, id: transactionIds[index % transactionIds.count].rawValue),
                firstDetectedAt: fixedNow,
                lastDetectedAt: fixedNow
            ).insert(db)
        }

        for index in 0..<taxFactCount {
            try TaxFact(
                fingerprint: "large-query-tax-fact-\(index)",
                entityId: entity.id,
                taxYearId: taxYear.id,
                jurisdictionCode: "CH-ZH",
                conceptCode: "large.query.fact.\(index)",
                valueType: .money,
                moneyMinor: Int64(index * 100),
                currency: .chf,
                status: index.isMultiple(of: 11) ? .observed : .derived,
                rulesetVersion: "zh-personal-2026-v1",
                provenanceRefs: [
                    ObjectRef(kind: .transaction, id: transactionIds[index % transactionIds.count].rawValue),
                ],
                confidence: 1.0,
                createdAt: fixedNow,
                updatedAt: fixedNow
            ).insert(db)
        }

        try VATPeriod(
            entityId: entity.id,
            periodStart: periodStart,
            periodEnd: periodEnd,
            currency: .chf
        ).insert(db)
    }

    let expectedMatchedTransactionCount = matchedTransactionIds.count
    let expectedUnmatchedTransactionCount = transactionCount - expectedMatchedTransactionCount

    let reportingQueryStart = Date()
    try storage.dbPool.read { db in
        let cashflowRows = try Row.fetchAll(
            db,
            sql: """
            SELECT yearMonth, inflowMinor, outflowMinor, netMinor, transactionCount
            FROM vw_cashflow_by_entity
            WHERE entityId = ? AND currency = ?
            ORDER BY yearMonth
            """,
            arguments: [entity.id, "CHF"]
        )
        #expect(cashflowRows.count == 12)

        let spendRows = try Row.fetchAll(
            db,
            sql: """
            SELECT yearMonth, spendMinor, transactionCount
            FROM vw_spend_by_month
            WHERE entityId = ? AND currency = ?
            ORDER BY yearMonth
            """,
            arguments: [entity.id, "CHF"]
        )
        #expect(spendRows.count == 12)

        let statementCoverageCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_statement_coverage WHERE entityId = ? AND accountId = ?",
            arguments: [entity.id, account.id]
        )
        #expect(statementCoverageCount == statementCount)

        let currentTaxFactCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_tax_fact_status WHERE entityId = ? AND taxYearId = ?",
            arguments: [entity.id, taxYear.id]
        )
        #expect(currentTaxFactCount == taxFactCount)

        let missingEvidenceCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_missing_evidence WHERE entityId = ? AND taxYearId = ?",
            arguments: [entity.id, taxYear.id]
        )
        #expect(missingEvidenceCount == issueCount)

        let unmatchedTransactionCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM vw_unmatched_transactions WHERE entityId = ?",
            arguments: [entity.id]
        )
        #expect(unmatchedTransactionCount == expectedUnmatchedTransactionCount)

        let vatRow = try #require(try Row.fetchOne(
            db,
            sql: """
            SELECT transactionCount, missingTaxCodeCount, outputBaseMinor, inputBaseMinor
            FROM vw_vat_reconciliation
            WHERE entityId = ? AND currency = ?
            """,
            arguments: [entity.id, "CHF"]
        ))
        let vatTransactionCount: Int = vatRow["transactionCount"]
        let missingTaxCodeCount: Int = vatRow["missingTaxCodeCount"]
        let outputBaseMinor: Int64 = vatRow["outputBaseMinor"]
        let inputBaseMinor: Int64 = vatRow["inputBaseMinor"]
        #expect(vatTransactionCount == transactionCount)
        #expect(missingTaxCodeCount == 0)
        #expect(outputBaseMinor > 0)
        #expect(inputBaseMinor > 0)
    }
    if enforcePerformanceBudgets {
        #expect(Date().timeIntervalSince(reportingQueryStart) < 2.0)
    }

    let scopedLookupStart = Date()
    let fetchedTransactions = try storage.transactionRepository.fetchTransactions(
        entityId: entity.id,
        from: periodStart,
        through: periodEnd
    )
    let fetchedStatements = try storage.statementImportRepository.fetchStatementImports(accountId: account.id)
    let fetchedTaxFacts = try storage.taxFactRepository.fetchTaxFacts(
        entityId: entity.id,
        taxYearId: taxYear.id,
        currentOnly: true
    )
    let fetchedEvidenceLinks = try storage.evidenceLinkRepository.fetchEvidenceLinks(
        for: ObjectRef(kind: .transaction, id: try #require(matchedTransactionIds.first).rawValue)
    )
    #expect(fetchedTransactions.count == transactionCount)
    #expect(fetchedStatements.count == statementCount)
    #expect(fetchedTaxFacts.count == taxFactCount)
    #expect(fetchedEvidenceLinks.count == 1)
    if enforcePerformanceBudgets {
        #expect(Date().timeIntervalSince(scopedLookupStart) < 2.0)
    }

    _ = try workspaceService.createBackup(for: storage, at: backupURL)
    let backupIntegrityReport = try workspaceService.validateBackup(at: backupURL)
    #expect(backupIntegrityReport.isRestorable)
    #expect(backupIntegrityReport.issues.isEmpty)

    let restoredStorage = try workspaceService.restoreBackup(from: backupURL)
    let restoredCounts = try restoredStorage.dbPool.read { db in
        (
            transactions: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM transactions") ?? 0,
            statements: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM statementImports") ?? 0,
            evidenceLinks: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM evidenceLinks") ?? 0,
            taxFacts: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM taxFacts") ?? 0,
            issues: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM issues") ?? 0,
            unmatched: try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM vw_unmatched_transactions WHERE entityId = ?",
                arguments: [entity.id]
            ) ?? 0
        )
    }
    #expect(restoredCounts.transactions == transactionCount)
    #expect(restoredCounts.statements == statementCount)
    #expect(restoredCounts.evidenceLinks == expectedMatchedTransactionCount)
    #expect(restoredCounts.taxFacts == taxFactCount)
    #expect(restoredCounts.issues == issueCount)
    #expect(restoredCounts.unmatched == expectedUnmatchedTransactionCount)
}

@Test
func workspaceSupportDiagnosticsExportIsSanitizedAndIncludesHealthAndCounts() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let exportURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("diagnostics.json")
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Sensitive Diagnostics Workspace")
    let entity = try #require(
        try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first
    )
    let account = try #require(
        try storage.financialAccountRepository
            .fetchFinancialAccounts(entityId: entity.id)
            .first
    )

    let sensitiveDocumentData = Data("private document bytes that must not appear in diagnostics".utf8)
    let blobHash = try storage.blobStore.store(data: sensitiveDocumentData)
    let document = Document(
        workspaceId: storage.manifest.workspace.id,
        blobHash: blobHash,
        originalFilename: "private-receipt-secret.pdf",
        mediaType: "application/pdf",
        extractedText: "confidential salary evidence",
        metadataStatus: .confirmed
    )
    try storage.documentRepository.saveDocument(document)
    try storage.transactionRepository.saveTransactions([
        Transaction(
            accountId: account.id,
            sourceLineRef: "secret-row-1",
            bookingDate: try Date.alpenLedgerTestDate("2026-02-01T00:00:00Z"),
            amountMinor: -12_345,
            currency: .chf,
            counterpartyName: "Secret Counterparty AG",
            memo: "Confidential transaction memo",
            taxCode: "CH-VAT-INPUT-STD"
        ),
    ])
    let savedTransaction = try #require(try storage.transactionRepository.fetchTransactions(accountId: account.id).first)
    #expect(savedTransaction.taxCode == "CH-VAT-INPUT-STD")

    let report = try storage.exportSupportDiagnostics(
        to: exportURL,
        generatedAt: try Date.alpenLedgerTestDate("2026-03-19T12:00:00Z")
    )
    let exportedData = try Data(contentsOf: exportURL)
    let exportedText = String(decoding: exportedData, as: UTF8.self)
    let decoded = try JSONDecoder.alpenLedger.decode(WorkspaceSupportDiagnosticsReport.self, from: exportedData)

    #expect(decoded == report)
    #expect(report.formatVersion == WorkspaceSupportDiagnosticsReport.currentFormatVersion)
    #expect(report.databaseHealth.isHealthy)
    #expect(report.tableCounts.first(where: { $0.tableName == "documents" })?.rowCount == 1)
    #expect(report.tableCounts.first(where: { $0.tableName == "transactions" })?.rowCount == 1)
    #expect(report.filesystem.blobs.fileCount == 1)
    #expect(report.privacy.includesWorkspaceName == false)
    #expect(report.privacy.includesAbsolutePaths == false)
    #expect(report.privacy.includesWorkspaceMasterKey == false)
    #expect(report.privacy.includesDocumentContents == false)
    #expect(report.privacy.includesDocumentFilenames == false)
    #expect(report.privacy.includesTransactionDescriptions == false)
    #expect(report.privacy.includesTransactionAmounts == false)
    #expect(exportedText.contains("Sensitive Diagnostics Workspace") == false)
    #expect(exportedText.contains("private-receipt-secret.pdf") == false)
    #expect(exportedText.contains("private document bytes") == false)
    #expect(exportedText.contains("confidential salary evidence") == false)
    #expect(exportedText.contains("Secret Counterparty AG") == false)
    #expect(exportedText.contains("Confidential transaction memo") == false)
    #expect(exportedText.contains(rootURL.path) == false)
}

@Test
func workspaceSupportBundleExportIncludesSanitizedAuditLog() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let exportURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("support-bundle.json")
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Sensitive Support Bundle Workspace")
    let sensitiveActorId = "sensitive-user@example.com"
    let sensitiveObjectId = "private-document-object-id"
    let sensitivePayload = "Support payload for Very Private AG with account 1234"
    let fixedNow = try Date.alpenLedgerTestDate("2026-03-19T12:00:00Z")

    try storage.auditEventRepository.saveAuditEvent(
        AuditEvent(
            workspaceId: storage.manifest.workspace.id,
            actorType: .user,
            actorId: sensitiveActorId,
            eventType: .documentImported,
            objectRef: ObjectRef(kind: .document, id: sensitiveObjectId),
            payload: sensitivePayload,
            occurredAt: fixedNow
        )
    )

    let bundle = try storage.exportSupportBundle(to: exportURL, generatedAt: fixedNow)
    let exportedData = try Data(contentsOf: exportURL)
    let exportedText = String(decoding: exportedData, as: UTF8.self)
    let decoded = try JSONDecoder.alpenLedger.decode(WorkspaceSupportBundle.self, from: exportedData)
    let importedEvent = try #require(
        bundle.auditLog.recentEvents.first { $0.eventType == .documentImported }
    )

    #expect(decoded.formatVersion == bundle.formatVersion)
    #expect(decoded.generatedAt == bundle.generatedAt)
    #expect(decoded.auditLog.totalEventCount == bundle.auditLog.totalEventCount)
    #expect(bundle.formatVersion == WorkspaceSupportBundle.currentFormatVersion)
    #expect(bundle.generatedAt == fixedNow)
    #expect(bundle.diagnostics.databaseHealth.isHealthy)
    #expect(bundle.auditLog.totalEventCount >= 2)
    #expect(bundle.auditLog.eventsByType.contains { $0.eventType == .documentImported && $0.count == 1 })
    #expect(bundle.auditLog.eventsByActorType.contains { $0.actorType == .user && $0.count >= 1 })
    #expect(bundle.auditLog.objectsByKind.contains { $0.objectKind == .document && $0.count == 1 })
    #expect(importedEvent.actorType == .user)
    #expect(importedEvent.objectKind == .document)
    #expect(importedEvent.payloadPresent)
    #expect(importedEvent.payloadByteCount == Data(sensitivePayload.utf8).count)
    #expect(importedEvent.actorFingerprint.isEmpty == false)
    #expect(importedEvent.objectFingerprint.isEmpty == false)
    #expect(bundle.privacy.includesRawAuditEventIds == false)
    #expect(bundle.privacy.includesRawAuditActorIds == false)
    #expect(bundle.privacy.includesRawAuditObjectIds == false)
    #expect(bundle.privacy.includesRawAuditPayloads == false)
    #expect(bundle.privacy.includesWorkspaceName == false)
    #expect(bundle.privacy.includesAbsolutePaths == false)
    #expect(bundle.privacy.includesWorkspaceMasterKey == false)
    #expect(exportedText.contains("Sensitive Support Bundle Workspace") == false)
    #expect(exportedText.contains(sensitiveActorId) == false)
    #expect(exportedText.contains(sensitiveObjectId) == false)
    #expect(exportedText.contains(sensitivePayload) == false)
    #expect(exportedText.contains("Very Private AG") == false)
    #expect(exportedText.contains(rootURL.path) == false)
}

@Test
func workspaceBackupRestoreRoundTripsDatabaseBlobsKeyAndAuditTrail() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("workspace.alpenledgerbackup", isDirectory: true)
    let secretStore = InMemorySecretStore()
    let storageManager = WorkspaceStorageManager(
        secretStore: secretStore,
        workspacesRootURL: rootURL
    )
    let defaultsSuiteName = "WorkspaceBackupRestore.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
    defaults.removePersistentDomain(forName: defaultsSuiteName)
    let fixedNow = try #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: defaults),
        nowProvider: { fixedNow }
    )

    let storage = try workspaceService.createWorkspace(named: "Backup Workspace")
    let blobData = Data("receipt payload".utf8)
    let blobHash = try storage.blobStore.store(data: blobData)
    let document = Document(
        workspaceId: storage.manifest.workspace.id,
        blobHash: blobHash,
        originalFilename: "receipt.txt",
        mediaType: "text/plain",
        extractedText: "receipt payload",
        metadataStatus: .confirmed
    )
    try storage.documentRepository.saveDocument(document)
    let materializedURL = try storage.blobStore.materialize(hash: blobHash, fileExtension: "txt")
    #expect(fileManager.fileExists(atPath: materializedURL.path))

    let backupManifest = try workspaceService.createBackup(for: storage, at: backupURL)

    #expect(backupManifest.workspaceId == storage.manifest.workspace.id)
    #expect(backupManifest.containsWorkspaceMasterKey)
    #expect(backupManifest.formatVersion == WorkspaceBackupManifest.currentFormatVersion)
    #expect(backupManifest.fileHashes.isEmpty == false)
    #expect(backupManifest.fileHashes.contains { $0.relativePath == "workspace.key" })
    #expect(backupManifest.fileHashes.contains { $0.relativePath == "workspace/workspace.json" })
    #expect(backupManifest.fileHashes.contains { $0.relativePath == "workspace/workspace.sqlite" })
    #expect(fileManager.fileExists(atPath: backupURL.appendingPathComponent("backup.json").path))
    #expect(fileManager.fileExists(atPath: backupURL.appendingPathComponent("workspace.key").path))
    #expect(fileManager.fileExists(atPath: backupURL.appendingPathComponent("workspace/workspace.json").path))
    #expect(fileManager.fileExists(atPath: backupURL.appendingPathComponent("workspace/temp").path) == false)
    let backupIntegrityReport = try workspaceService.validateBackup(at: backupURL)
    #expect(backupIntegrityReport.isRestorable)
    #expect(backupIntegrityReport.issues.isEmpty)
    let backupEvents = try storage.auditEventRepository.fetchAuditEvents(
        workspaceId: storage.manifest.workspace.id,
        objectRef: nil
    )
    #expect(backupEvents.contains { $0.eventType == .workspaceBackupCreated })

    try secretStore.deleteWorkspaceMasterKey(workspaceId: storage.manifest.workspace.id)
    let restoredStorage = try workspaceService.restoreBackup(from: backupURL)

    #expect(restoredStorage.paths.rootURL != storage.paths.rootURL)
    #expect(restoredStorage.manifest.rootPath == restoredStorage.paths.rootURL.path)
    #expect(try restoredStorage.workspaceRepository.fetchWorkspace()?.name == "Backup Workspace")
    #expect(try restoredStorage.documentRepository.fetchDocument(id: document.id)?.originalFilename == "receipt.txt")
    #expect(try restoredStorage.blobStore.read(hash: blobHash) == blobData)
    #expect(fileManager.fileExists(atPath: restoredStorage.paths.tempURL.path))
    #expect(fileManager.fileExists(atPath: restoredStorage.paths.tempURL.appendingPathComponent("\(blobHash).txt").path) == false)
    let restoreEvents = try restoredStorage.auditEventRepository.fetchAuditEvents(
        workspaceId: restoredStorage.manifest.workspace.id,
        objectRef: nil
    )
    #expect(restoreEvents.contains { $0.eventType == .workspaceRestored })
    #expect(workspaceService.recentWorkspaces().first?.path == restoredStorage.paths.rootURL.path)
}

@Test
func workspaceDeletionRequiresExactWorkspaceNameAndRemovesLocalData() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let defaultsSuiteName = "WorkspaceDeletion.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: defaultsSuiteName))
    defaults.removePersistentDomain(forName: defaultsSuiteName)
    let secretStore = InMemorySecretStore()
    let storageManager = WorkspaceStorageManager(
        secretStore: secretStore,
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        recentStore: RecentWorkspacesStore(defaults: defaults)
    )
    let storage = try workspaceService.createWorkspace(named: "Reset Candidate")
    let workspaceURL = storage.paths.rootURL
    let workspaceId = storage.manifest.workspace.id

    do {
        try workspaceService.deleteWorkspace(storage, confirmingWorkspaceName: "Wrong Workspace")
        Issue.record("Expected deletion to require exact workspace-name confirmation.")
    } catch let error as DomainError {
        #expect(error == .workspaceDeletionConfirmationMismatch)
    }

    #expect(fileManager.fileExists(atPath: workspaceURL.path))
    #expect(try secretStore.loadWorkspaceMasterKey(workspaceId: workspaceId).isEmpty == false)
    #expect(workspaceService.recentWorkspaces().map(\.workspaceId) == [workspaceId])

    try workspaceService.deleteWorkspace(storage, confirmingWorkspaceName: " Reset Candidate ")

    #expect(fileManager.fileExists(atPath: workspaceURL.path) == false)
    #expect(workspaceService.recentWorkspaces().isEmpty)
    do {
        _ = try secretStore.loadWorkspaceMasterKey(workspaceId: workspaceId)
        Issue.record("Expected workspace deletion to remove the workspace master key.")
    } catch let error as DomainError {
        #expect(error == .missingWorkspaceKey)
    }
}

@Test
func workspaceBackupCreationCleansUpStagedBundleWhenKeyLoadFails() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupParentURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = backupParentURL.appendingPathComponent("workspace.alpenledgerbackup", isDirectory: true)
    let secretStore = InMemorySecretStore()
    let storageManager = WorkspaceStorageManager(
        secretStore: secretStore,
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Failed Backup Workspace")
    try secretStore.deleteWorkspaceMasterKey(workspaceId: storage.manifest.workspace.id)

    do {
        _ = try workspaceService.createBackup(for: storage, at: backupURL)
        Issue.record("Expected backup creation to fail when the workspace key is missing.")
    } catch let error as DomainError {
        #expect(error == .missingWorkspaceKey)
    }

    #expect(fileManager.fileExists(atPath: backupURL.path) == false)
    let remainingBackupArtifacts = try fileManager
        .contentsOfDirectory(at: backupParentURL, includingPropertiesForKeys: nil)
        .filter { url in
            url.lastPathComponent == backupURL.lastPathComponent ||
                url.lastPathComponent.contains(".partial-")
        }
    #expect(remainingBackupArtifacts.isEmpty)
}

@Test
func workspaceBackupRestoreRemovesInsertedKeyWhenOpenFails() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("workspace.alpenledgerbackup", isDirectory: true)
    let secretStore = InMemorySecretStore()
    let storageManager = WorkspaceStorageManager(
        secretStore: secretStore,
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Restore Failure Workspace")
    let workspaceId = storage.manifest.workspace.id

    _ = try workspaceService.createBackup(for: storage, at: backupURL)
    try secretStore.deleteWorkspaceMasterKey(workspaceId: workspaceId)
    let workspaceDirectoryCountBeforeRestore = try fileManager
        .contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
        .count
    let failingStorageManager = WorkspaceStorageManager(
        secretStore: secretStore,
        databaseMigrator: { _ in
            throw MigrationRecoveryTestError.injectedFailure
        },
        workspacesRootURL: rootURL
    )
    let failingWorkspaceService = WorkspaceService(storageManager: failingStorageManager)

    #expect(throws: MigrationRecoveryTestError.self) {
        _ = try failingWorkspaceService.restoreBackup(from: backupURL)
    }

    let workspaceDirectoryCountAfterRestore = try fileManager
        .contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
        .count
    #expect(workspaceDirectoryCountAfterRestore == workspaceDirectoryCountBeforeRestore)
    do {
        _ = try secretStore.loadWorkspaceMasterKey(workspaceId: workspaceId)
        Issue.record("Expected failed restore to remove the inserted workspace key.")
    } catch let error as DomainError {
        #expect(error == .missingWorkspaceKey)
    }
}

@Test
func workspaceBackupRestorePreservesRealisticWorkspaceGraph() throws {
    let fileManager = FileManager.default
    let fixedNow = try #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("realistic-workspace.alpenledgerbackup", isDirectory: true)
    let secretStore = InMemorySecretStore()
    let storageManager = WorkspaceStorageManager(
        secretStore: secretStore,
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        nowProvider: { fixedNow }
    )

    let storage = try workspaceService.createWorkspace(named: "Zurich Household + Studio")
    let auditLogger = AuditLogger(storage: storage)
    let entityService = LegalEntityService(
        storage: storage,
        auditLogger: auditLogger,
        nowProvider: { fixedNow }
    )
    let personalEntity = try #require(
        try storage.legalEntityRepository
            .fetchLegalEntities(workspaceId: storage.manifest.workspace.id)
            .first(where: { $0.kind == .naturalPerson })
    )
    let businessEntity = try entityService.createSoleProprietor(name: "Gipfel Consulting")
    let personalTaxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: personalEntity.id).first)
    let businessTaxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: businessEntity.id).first)
    let personalAccount = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: personalEntity.id).first)
    let businessAccount = try #require(try storage.financialAccountRepository.fetchFinancialAccounts(entityId: businessEntity.id).first)

    let personalStatementData = Data("date,amount,currency,memo\n2026-01-25,6500.00,CHF,Salary\n".utf8)
    let businessStatementData = Data("date,amount,currency,memo\n2026-02-04,2400.00,CHF,Client invoice\n2026-02-06,-320.50,CHF,Supplier invoice\n".utf8)
    let personalStatementBlob = try storage.blobStore.store(data: personalStatementData)
    let businessStatementBlob = try storage.blobStore.store(data: businessStatementData)
    let personalImportJob = ImportJob(
        workspaceId: storage.manifest.workspace.id,
        kind: .bankStatementCSV,
        source: "imports/personal-bank-january.csv",
        parserKey: "csv.bank.v1",
        parserVersion: "1.0",
        status: .completed,
        startedAt: fixedNow,
        completedAt: fixedNow,
        warningCount: 0
    )
    let businessImportJob = ImportJob(
        workspaceId: storage.manifest.workspace.id,
        kind: .bankStatementCSV,
        source: "imports/business-bank-february.csv",
        parserKey: "csv.bank.v1",
        parserVersion: "1.0",
        status: .completed,
        startedAt: fixedNow,
        completedAt: fixedNow,
        warningCount: 1
    )
    try storage.importJobRepository.saveImportJob(personalImportJob)
    try storage.importJobRepository.saveImportJob(businessImportJob)

    let personalStatement = StatementImport(
        accountId: personalAccount.id,
        importJobId: personalImportJob.id,
        sourceBlobHash: personalStatementBlob,
        sourceFormat: "csv",
        sourceFingerprint: "personal-2026-01",
        coverageStart: try Date.alpenLedgerTestDate("2026-01-01T00:00:00Z"),
        coverageEnd: try Date.alpenLedgerTestDate("2026-01-31T23:59:59Z"),
        openingBalanceMinor: 120_000,
        closingBalanceMinor: 770_000,
        parserVersion: "1.0"
    )
    let businessStatement = StatementImport(
        accountId: businessAccount.id,
        importJobId: businessImportJob.id,
        sourceBlobHash: businessStatementBlob,
        sourceFormat: "csv",
        sourceFingerprint: "business-2026-02",
        coverageStart: try Date.alpenLedgerTestDate("2026-02-01T00:00:00Z"),
        coverageEnd: try Date.alpenLedgerTestDate("2026-02-28T23:59:59Z"),
        openingBalanceMinor: 50_000,
        closingBalanceMinor: 257_950,
        parserVersion: "1.0"
    )
    try storage.statementImportRepository.saveStatementImport(personalStatement)
    try storage.statementImportRepository.saveStatementImport(businessStatement)

    let salaryTransaction = Transaction(
        accountId: personalAccount.id,
        statementImportId: personalStatement.id,
        sourceLineRef: "personal-bank-january.csv:2",
        bookingDate: try Date.alpenLedgerTestDate("2026-01-25T00:00:00Z"),
        amountMinor: 650_000,
        currency: .chf,
        counterpartyName: "Alpen AG",
        memo: "January salary",
        reference: "SAL-2026-01",
        balanceAfterMinor: 770_000,
        reviewState: .reviewed
    )
    let clientPaymentTransaction = Transaction(
        accountId: businessAccount.id,
        statementImportId: businessStatement.id,
        sourceLineRef: "business-bank-february.csv:2",
        bookingDate: try Date.alpenLedgerTestDate("2026-02-04T00:00:00Z"),
        amountMinor: 240_000,
        currency: .chf,
        counterpartyName: "Client GmbH",
        memo: "Invoice GC-2026-001",
        reference: "GC-2026-001",
        balanceAfterMinor: 290_000,
        reviewState: .reviewed
    )
    let supplierPaymentTransaction = Transaction(
        accountId: businessAccount.id,
        statementImportId: businessStatement.id,
        sourceLineRef: "business-bank-february.csv:3",
        bookingDate: try Date.alpenLedgerTestDate("2026-02-06T00:00:00Z"),
        amountMinor: -32_050,
        currency: .chf,
        counterpartyName: "Print & Paper AG",
        memo: "Supplier invoice PP-44",
        reference: "PP-44",
        balanceAfterMinor: 257_950,
        reviewState: .pending
    )
    try storage.transactionRepository.saveTransactions([
        salaryTransaction,
        clientPaymentTransaction,
        supplierPaymentTransaction,
    ])

    let documentImportJob = ImportJob(
        workspaceId: storage.manifest.workspace.id,
        kind: .documentIntake,
        source: "imports/documents",
        parserKey: "documents.v1",
        parserVersion: "1.0",
        status: .completed,
        startedAt: fixedNow,
        completedAt: fixedNow,
        warningCount: 0
    )
    try storage.importJobRepository.saveImportJob(documentImportJob)
    let salaryDocumentBlob = try storage.blobStore.store(data: Data("Salary certificate Alpen AG 2026".utf8))
    let invoiceDocumentBlob = try storage.blobStore.store(data: Data("Invoice PP-44 CHF 320.50".utf8))
    let salaryDocument = Document(
        workspaceId: storage.manifest.workspace.id,
        importJobId: documentImportJob.id,
        blobHash: salaryDocumentBlob,
        originalFilename: "salary-certificate-2026.pdf",
        mediaType: "application/pdf",
        origin: .importPipeline,
        documentType: .salaryCertificate,
        issueDate: try Date.alpenLedgerTestDate("2026-02-01T00:00:00Z"),
        detectedEntityId: personalEntity.id,
        entityId: personalEntity.id,
        detectedTaxYearId: personalTaxYear.id,
        extractedText: "Salary certificate Alpen AG gross CHF 78000",
        metadataStatus: .confirmed
    )
    let invoiceDocument = Document(
        workspaceId: storage.manifest.workspace.id,
        importJobId: documentImportJob.id,
        blobHash: invoiceDocumentBlob,
        originalFilename: "supplier-invoice-pp-44.pdf",
        mediaType: "application/pdf",
        origin: .importPipeline,
        documentType: .invoice,
        issueDate: try Date.alpenLedgerTestDate("2026-02-05T00:00:00Z"),
        detectedEntityId: businessEntity.id,
        entityId: businessEntity.id,
        detectedTaxYearId: businessTaxYear.id,
        extractedText: "Print & Paper AG invoice PP-44 CHF 320.50",
        metadataStatus: .confirmed
    )
    try storage.documentRepository.saveDocument(salaryDocument)
    try storage.documentRepository.saveDocument(invoiceDocument)

    let supplierLink = EvidenceLink(
        sourceRef: ObjectRef(kind: .document, id: invoiceDocument.id.rawValue),
        targetRef: ObjectRef(kind: .transaction, id: supplierPaymentTransaction.id.rawValue),
        status: .confirmed,
        confidence: 0.98,
        createdByKind: .agent,
        approvalRequired: false,
        reason: "Invoice number and amount match imported transaction."
    )
    try storage.evidenceLinkRepository.saveEvidenceLink(supplierLink)

    let businessCategory = TransactionCategory(
        entityId: businessEntity.id,
        code: "office-supplies",
        displayName: "Office Supplies",
        taxRole: "business.expense.office",
        isSystemDefined: false,
        createdAt: fixedNow,
        updatedAt: fixedNow
    )
    try storage.categoryRepository.saveTransactionCategory(businessCategory)
    let invoiceRecord = InvoiceRecord(
        documentId: invoiceDocument.id,
        entityId: businessEntity.id,
        invoiceNumber: "PP-44",
        counterpartyName: "Print & Paper AG",
        issueDate: try Date.alpenLedgerTestDate("2026-02-05T00:00:00Z"),
        dueDate: try Date.alpenLedgerTestDate("2026-03-07T00:00:00Z"),
        totalAmountMinor: 32_050,
        currency: .chf,
        direction: .payable,
        status: .paid,
        linkedTransactionId: supplierPaymentTransaction.id,
        createdAt: fixedNow,
        updatedAt: fixedNow
    )
    try storage.invoiceRecordRepository.saveInvoiceRecord(invoiceRecord)

    let requirement = Requirement(
        fingerprint: "business-statement-february-2026",
        entityId: businessEntity.id,
        taxYearId: businessTaxYear.id,
        requirementCode: .statementCoverage,
        subjectRef: ObjectRef(kind: .financialAccount, id: businessAccount.id.rawValue),
        summary: "Business bank statement coverage for February 2026",
        coverageStart: businessStatement.coverageStart,
        coverageEnd: businessStatement.coverageEnd,
        status: .satisfied,
        satisfiedByRef: ObjectRef(kind: .statementImport, id: businessStatement.id.rawValue),
        createdAt: fixedNow,
        updatedAt: fixedNow
    )
    try storage.requirementRepository.saveRequirement(requirement)
    let issue = Issue(
        fingerprint: "business-supplier-evidence-review",
        workspaceId: storage.manifest.workspace.id,
        entityId: businessEntity.id,
        taxYearId: businessTaxYear.id,
        issueCode: .missingExpenseEvidence,
        severity: .warning,
        status: .resolved,
        summary: "Supplier invoice was matched after review",
        objectRef: ObjectRef(kind: .transaction, id: supplierPaymentTransaction.id.rawValue),
        relatedRef: ObjectRef(kind: .document, id: invoiceDocument.id.rawValue),
        firstDetectedAt: fixedNow,
        lastDetectedAt: fixedNow
    )
    try storage.issueRepository.saveIssue(issue)

    let taxFact = TaxFact(
        fingerprint: "zh|2026|salary|gross",
        entityId: personalEntity.id,
        taxYearId: personalTaxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "personal.income.salary_gross",
        valueType: .money,
        moneyMinor: 7_800_000,
        currency: .chf,
        status: .observed,
        rulesetVersion: "zh-personal-2026-v1",
        provenanceRefs: [
            ObjectRef(kind: .document, id: salaryDocument.id.rawValue),
            ObjectRef(kind: .transaction, id: salaryTransaction.id.rawValue),
        ],
        confidence: 1.0,
        createdAt: fixedNow,
        updatedAt: fixedNow
    )
    try storage.taxFactRepository.saveTaxFact(taxFact)
    let filingPackage = FilingPackage(
        entityId: personalEntity.id,
        taxYearId: personalTaxYear.id,
        status: .generated,
        generatedAt: fixedNow,
        snapshotHash: "snapshot-\(taxFact.id.rawValue.uuidString.lowercased())",
        exportFormat: "review-bundle",
        createdAt: fixedNow,
        updatedAt: fixedNow
    )
    try storage.filingPackageRepository.saveFilingPackage(filingPackage)

    let proposal = AgentProposal(
        fingerprint: "agent-link-supplier-invoice-pp-44",
        workspaceId: storage.manifest.workspace.id,
        agentKind: .systemHeuristics,
        proposalType: .documentLinkReview,
        targetRef: ObjectRef(kind: .transaction, id: supplierPaymentTransaction.id.rawValue),
        summary: "Link supplier invoice PP-44 to business bank transaction",
        rationale: "Amount, reference, and counterparty match.",
        confidence: 0.98,
        status: .resolved,
        createdAt: fixedNow,
        decidedAt: fixedNow,
        decidedBy: "reviewer",
        decisionReason: "Confirmed during realistic backup drill."
    )
    try storage.agentProposalRepository.saveAgentProposal(proposal)

    _ = try workspaceService.createBackup(for: storage, at: backupURL)
    let backupIntegrityReport = try workspaceService.validateBackup(at: backupURL)
    #expect(backupIntegrityReport.isRestorable)
    #expect(backupIntegrityReport.issues.isEmpty)

    try secretStore.deleteWorkspaceMasterKey(workspaceId: storage.manifest.workspace.id)
    let restoredStorage = try workspaceService.restoreBackup(from: backupURL)

    let restoredEntities = try restoredStorage.legalEntityRepository
        .fetchLegalEntities(workspaceId: restoredStorage.manifest.workspace.id)
    #expect(restoredEntities.map(\.displayName).sorted() == ["Gipfel Consulting", "Personal"])
    let restoredEntityWorkspaces = try restoredStorage.entityWorkspaceRepository
        .fetchEntityWorkspaces(workspaceId: restoredStorage.manifest.workspace.id)
    #expect(restoredEntityWorkspaces.count == 2)
    #expect(restoredEntityWorkspaces.filter(\.isDefault).count == 1)
    #expect(try restoredStorage.blobStore.read(hash: personalStatementBlob) == personalStatementData)
    #expect(try restoredStorage.blobStore.read(hash: businessStatementBlob) == businessStatementData)
    #expect(try restoredStorage.blobStore.read(hash: invoiceDocumentBlob) == Data("Invoice PP-44 CHF 320.50".utf8))
    #expect(try restoredStorage.statementImportRepository.fetchStatementImports(accountId: personalAccount.id).count == 1)
    #expect(try restoredStorage.statementImportRepository.fetchStatementImports(accountId: businessAccount.id).count == 1)
    #expect(try restoredStorage.transactionRepository.fetchTransactions(accountId: businessAccount.id).count == 2)
    #expect(try restoredStorage.documentRepository.fetchDocument(id: salaryDocument.id)?.entityId == personalEntity.id)
    #expect(try restoredStorage.documentRepository.fetchDocument(id: invoiceDocument.id)?.entityId == businessEntity.id)
    #expect(try restoredStorage.evidenceLinkRepository.fetchEvidenceLinks(
        for: ObjectRef(kind: .transaction, id: supplierPaymentTransaction.id.rawValue)
    ) == [supplierLink])
    #expect(try restoredStorage.invoiceRecordRepository.fetchInvoiceRecord(documentId: invoiceDocument.id)?.linkedTransactionId == supplierPaymentTransaction.id)
    #expect(try restoredStorage.categoryRepository.fetchCategories(entityId: businessEntity.id).map(\.code) == ["office-supplies"])
    #expect(try restoredStorage.requirementRepository.fetchRequirement(fingerprint: requirement.fingerprint)?.status == .satisfied)
    #expect(try restoredStorage.issueRepository.fetchIssue(fingerprint: issue.fingerprint)?.status == .resolved)
    let restoredFact = try #require(try restoredStorage.taxFactRepository.fetchTaxFact(fingerprint: taxFact.fingerprint, isCurrent: true))
    #expect(restoredFact.moneyMinor == 7_800_000)
    #expect(restoredFact.provenanceRefs == taxFact.provenanceRefs)
    #expect(try restoredStorage.filingPackageRepository.fetchFilingPackage(id: filingPackage.id)?.status == .generated)
    let restoredProposal = try #require(
        try restoredStorage.agentProposalRepository.fetchAgentProposal(fingerprint: proposal.fingerprint)
    )
    #expect(restoredProposal.status == .resolved)
    #expect(restoredProposal.decisionReason == "Confirmed during realistic backup drill.")
}

@Test
func workspaceBackupValidationRejectsTamperedHashedFile() throws {
    let fileManager = FileManager.default
    let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let backupURL = fileManager.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent("workspace.alpenledgerbackup", isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Tamper Backup Workspace")

    _ = try workspaceService.createBackup(for: storage, at: backupURL)
    try Data("tampered key material".utf8)
        .write(to: backupURL.appendingPathComponent("workspace.key"), options: .atomic)

    let report = try workspaceService.validateBackup(at: backupURL)

    #expect(report.isRestorable == false)
    #expect(report.issues.contains {
        $0.severity == .blocker &&
            $0.code == "file_hash_mismatch" &&
            $0.relativePath == "workspace.key"
    })

    do {
        _ = try workspaceService.restoreBackup(from: backupURL)
        Issue.record("Expected tampered backup restore to be rejected.")
    } catch let error as DomainError {
        #expect(error == .invalidWorkspaceBackup)
    }
}

@Test
func evidenceTablesRoundTrip() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Round Trip Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)

    let requirement = Requirement(
        fingerprint: "requirement-roundtrip",
        entityId: entity.id,
        taxYearId: taxYear.id,
        requirementCode: .statementCoverage,
        subjectRef: ObjectRef(kind: .financialAccount, id: UUID()),
        summary: "Requirement round trip",
        status: .pending
    )
    try storage.requirementRepository.saveRequirement(requirement)

    let issue = Issue(
        fingerprint: "issue-roundtrip",
        workspaceId: storage.manifest.workspace.id,
        entityId: entity.id,
        taxYearId: taxYear.id,
        issueCode: .missingStatementCoverage,
        severity: .blocking,
        status: .open,
        summary: "Issue round trip",
        objectRef: ObjectRef(kind: .requirement, id: requirement.id.rawValue)
    )
    try storage.issueRepository.saveIssue(issue)

    let proposal = AgentProposal(
        fingerprint: "proposal-roundtrip",
        workspaceId: storage.manifest.workspace.id,
        agentKind: .systemHeuristics,
        proposalType: .documentLinkReview,
        targetRef: ObjectRef(kind: .document, id: UUID()),
        summary: "Proposal round trip",
        rationale: "Round trip",
        confidence: 0.25,
        status: .rejected,
        decidedAt: Date(timeIntervalSince1970: 100),
        decidedBy: "reviewer",
        decisionReason: "Round-trip decision metadata"
    )
    try storage.agentProposalRepository.saveAgentProposal(proposal)

    #expect(try storage.requirementRepository.fetchRequirement(fingerprint: "requirement-roundtrip")?.summary == "Requirement round trip")
    #expect(try storage.issueRepository.fetchIssue(fingerprint: "issue-roundtrip")?.summary == "Issue round trip")
    let loadedProposal = try #require(try storage.agentProposalRepository.fetchAgentProposal(fingerprint: "proposal-roundtrip"))
    #expect(loadedProposal.summary == "Proposal round trip")
    #expect(loadedProposal.status == .rejected)
    #expect(loadedProposal.decidedAt == Date(timeIntervalSince1970: 100))
    #expect(loadedProposal.decidedBy == "reviewer")
    #expect(loadedProposal.decisionReason == "Round-trip decision metadata")
}

@Test
func taxFactsRoundTripProvenanceAsJSON() throws {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(storageManager: storageManager)
    let storage = try workspaceService.createWorkspace(named: "Tax Storage Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)

    let fact = TaxFact(
        fingerprint: "zh|salary",
        entityId: entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        conceptCode: "personal.income.salary_gross",
        valueType: .money,
        moneyMinor: 9800000,
        currency: .chf,
        status: .observed,
        rulesetVersion: "zh-personal-2026-v1",
        provenanceRefs: [
            ObjectRef(kind: .document, id: UUID()),
            ObjectRef(kind: .transaction, id: UUID()),
        ]
    )
    try storage.taxFactRepository.saveTaxFact(fact)

    let loaded = try #require(try storage.taxFactRepository.fetchTaxFact(fingerprint: "zh|salary", isCurrent: true))
    #expect(loaded.moneyMinor == 9800000)
    #expect(loaded.provenanceRefs == fact.provenanceRefs)
}

@Test
func taxFactRepositoryPreservesSingleCurrentVersionAfterSupersession() throws {
    let fixedNow = try #require(ISO8601DateFormatter().date(from: "2026-03-19T12:00:00Z"))
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storageManager = WorkspaceStorageManager(
        secretStore: InMemorySecretStore(),
        workspacesRootURL: rootURL
    )
    let workspaceService = WorkspaceService(
        storageManager: storageManager,
        nowProvider: { fixedNow }
    )
    let storage = try workspaceService.createWorkspace(named: "Tax History Workspace")
    let entity = try #require(try storage.legalEntityRepository.fetchLegalEntities(workspaceId: storage.manifest.workspace.id).first)
    let taxYear = try #require(try storage.taxYearRepository.fetchTaxYears(entityId: entity.id).first)
    let factService = TaxFactService(storage: storage)
    let originalProvenanceRefs = [
        ObjectRef(kind: .document, id: UUID()),
        ObjectRef(kind: .transaction, id: UUID()),
    ]
    let replacementProvenanceRefs = [
        ObjectRef(kind: .document, id: UUID()),
    ]
    let replacementNow = fixedNow.addingTimeInterval(60)

    _ = try factService.syncFacts(
        [
            ComputedTaxFact(
                conceptCode: "personal.income.salary_gross",
                valueType: .money,
                moneyMinor: 9800000,
                currency: .chf,
                status: .observed,
                provenanceRefs: originalProvenanceRefs
            )
        ],
        entityId: entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        rulesetVersion: "zh-personal-2026-v1",
        now: fixedNow
    )

    _ = try factService.syncFacts(
        [
            ComputedTaxFact(
                conceptCode: "personal.income.salary_gross",
                valueType: .money,
                moneyMinor: 9900000,
                currency: .chf,
                status: .observed,
                provenanceRefs: replacementProvenanceRefs
            )
        ],
        entityId: entity.id,
        taxYearId: taxYear.id,
        jurisdictionCode: "CH-ZH",
        rulesetVersion: "zh-personal-2026-v1",
        now: replacementNow
    )

    let currentFacts = try storage.taxFactRepository.fetchTaxFacts(entityId: entity.id, taxYearId: taxYear.id, currentOnly: true)
    let allFacts = try storage.taxFactRepository.fetchTaxFacts(entityId: entity.id, taxYearId: taxYear.id, currentOnly: false)
    let currentFact = try #require(allFacts.first(where: { $0.isCurrent }))
    let supersededFact = try #require(allFacts.first(where: { !$0.isCurrent }))

    #expect(currentFacts.count == 1)
    #expect(currentFacts.first == currentFact)
    #expect(currentFact.moneyMinor == 9900000)
    #expect(currentFact.provenanceRefs == replacementProvenanceRefs)
    #expect(currentFact.supersedesFactId == supersededFact.id)
    #expect(supersededFact.moneyMinor == 9800000)
    #expect(supersededFact.provenanceRefs == originalProvenanceRefs)
    #expect(supersededFact.supersedesFactId == nil)
    #expect(allFacts.count == 2)
    #expect(allFacts.filter { $0.isCurrent }.count == 1)
}

private var enforcePerformanceBudgets: Bool {
    ProcessInfo.processInfo.environment["ALPENLEDGER_ENFORCE_PERFORMANCE_BUDGETS"] == "1"
}
