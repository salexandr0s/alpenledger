import Foundation
import GRDB
import ALDomain
import ALStorage
import ALAudit

public enum ImportCancellationError: LocalizedError, Sendable {
    case cancelled

    public var errorDescription: String? {
        "Import was cancelled before completion."
    }

    public var recoverySuggestion: String? {
        "Run the import again when you are ready. Cancelled imports do not post statement rows."
    }
}

public final class ImportPipeline: Sendable {
    private let storage: WorkspaceStorage
    private let auditLogger: AuditLogger
    private let importers: [any Importer]
    private let fileAccess: SecurityScopedResourceAccess

    public init(
        storage: WorkspaceStorage,
        auditLogger: AuditLogger,
        importers: [any Importer] = [
            CSVBankStatementImporter(),
            CAMTBankStatementImporter(format: .camt052),
            CAMTBankStatementImporter(format: .camt053),
            CAMTBankStatementImporter(format: .camt054),
        ],
        fileAccess: SecurityScopedResourceAccess = .live
    ) {
        self.storage = storage
        self.auditLogger = auditLogger
        self.importers = importers
        self.fileAccess = fileAccess
    }

    public func importStatement(from url: URL, accountId: FinancialAccountID) throws -> ParseLog {
        try importStatement(
            from: url,
            accountId: accountId,
            sourceName: nil,
            isCancellationRequested: { false }
        )
    }

    public func importStatement(
        from url: URL,
        accountId: FinancialAccountID,
        isCancellationRequested: @escaping @Sendable () -> Bool
    ) throws -> ParseLog {
        try importStatement(
            from: url,
            accountId: accountId,
            sourceName: nil,
            isCancellationRequested: isCancellationRequested
        )
    }

    func importStatement(
        from url: URL,
        accountId: FinancialAccountID,
        sourceName sourceNameOverride: String?,
        isCancellationRequested: @escaping @Sendable () -> Bool
    ) throws -> ParseLog {
        try fileAccess.withAccess(to: url) {
            let sourceName = normalizedSourceName(sourceNameOverride ?? url.lastPathComponent)
            try throwIfCancelled(isCancellationRequested)
            guard let importer = try importers.first(where: { try $0.canRecognize(url) }) else {
                throw DomainError.unsupportedImportFormat
            }

            let sourceBlobHash = try storage.blobStore.store(contentsOf: url)
            if try storage.importJobRepository.fetchCompletedImportJob(
                workspaceId: storage.manifest.workspace.id,
                kind: importer.importJobKind,
                parserKey: importer.parserKey,
                parserVersion: importer.parserVersion,
                sourceBlobHash: sourceBlobHash
            ) != nil {
                throw DomainError.duplicateStatementImport
            }

            let importJob = ImportJob(
                workspaceId: storage.manifest.workspace.id,
                kind: importer.importJobKind,
                source: sourceName,
                sourceBlobHash: sourceBlobHash,
                parserKey: importer.parserKey,
                parserVersion: importer.parserVersion
            )
            try storage.importJobRepository.saveImportJob(importJob)
            try auditLogger.log(
                eventType: .importJobCreated,
                objectRef: ObjectRef(kind: .importJob, id: importJob.id.rawValue),
                payload: sourceName
            )

            var parsedSourceFingerprint: String?
            do {
                try throwIfCancelled(isCancellationRequested)
                let payload = try importer.parse(url, accountId: accountId, importJobId: importJob.id, sourceBlobHash: sourceBlobHash)
                try throwIfCancelled(isCancellationRequested)
                parsedSourceFingerprint = payload.statementImport.sourceFingerprint
                try assertTransactionsDoNotTouchLockedPeriods(accountId: accountId, transactions: payload.transactions)
                if try storage.statementImportRepository.fetchStatementImport(accountId: accountId, fingerprint: payload.statementImport.sourceFingerprint) != nil {
                    throw DomainError.duplicateStatementImport
                }

                var completedImportJob = importJob
                completedImportJob.status = .completed
                completedImportJob.completedAt = .now
                completedImportJob.warningCount = payload.parseLog.warnings.count
                completedImportJob.sourceFingerprint = payload.statementImport.sourceFingerprint

                try storage.inTransaction { db in
                    try payload.statementImport.save(db)
                    for transaction in payload.transactions {
                        let linkedTransaction = try transactionByEnsuringCounterparty(transaction, in: db)
                        try linkedTransaction.save(db)
                    }
                    for diagnostic in payload.parseLog.diagnostics {
                        try diagnostic.save(db)
                    }
                    try completedImportJob.save(db)
                    try AuditEvent(
                        workspaceId: storage.manifest.workspace.id,
                        actorType: .system,
                        actorId: "system",
                        eventType: .importJobCompleted,
                        objectRef: ObjectRef(kind: .importJob, id: completedImportJob.id.rawValue),
                        payload: sourceName
                    ).save(db)
                    try AuditEvent(
                        workspaceId: storage.manifest.workspace.id,
                        actorType: .user,
                        actorId: "user",
                        eventType: .statementImported,
                        objectRef: ObjectRef(kind: .statementImport, id: payload.statementImport.id.rawValue),
                        payload: sourceName
                    ).save(db)
                }
                return payload.parseLog
            } catch {
                let isCancellation = isCancellation(error)
                var stoppedImportJob = importJob
                stoppedImportJob.status = isCancellation ? .cancelled : .failed
                stoppedImportJob.completedAt = .now
                stoppedImportJob.sourceFingerprint = parsedSourceFingerprint
                let diagnostic = ImportDiagnostic(
                    importJobId: importJob.id,
                    severity: isCancellation ? .warning : .error,
                    code: failureDiagnosticCode(for: error),
                    message: error.localizedDescription
                )
                try? storage.inTransaction { db in
                    try stoppedImportJob.save(db)
                    try diagnostic.save(db)
                    if isCancellation {
                        try AuditEvent(
                            workspaceId: storage.manifest.workspace.id,
                            actorType: .user,
                            actorId: "user",
                            eventType: .importJobCancelled,
                            objectRef: ObjectRef(kind: .importJob, id: importJob.id.rawValue),
                            payload: sourceName
                        ).save(db)
                    }
                }
                throw error
            }
        }
    }

    private func normalizedSourceName(_ sourceName: String) -> String {
        let lastPathComponent = URL(fileURLWithPath: sourceName).lastPathComponent
        return lastPathComponent.isEmpty ? "import-source" : lastPathComponent
    }

    private func throwIfCancelled(_ isCancellationRequested: () -> Bool) throws {
        if isCancellationRequested() {
            throw ImportCancellationError.cancelled
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is ImportCancellationError || error is CancellationError
    }

    private func failureDiagnosticCode(for error: Error) -> String {
        if isCancellation(error) {
            return "import.cancelled"
        }
        guard let domainError = error as? DomainError else {
            return "import.failed"
        }
        switch domainError {
        case .csvParseError, .statementParseError:
            return "import.corrupt_file"
        case .unsupportedImportFormat:
            return "import.unsupported_format"
        case .duplicateStatementImport:
            return "import.duplicate"
        case .lockedPeriod:
            return "import.locked_period"
        default:
            return "import.failed"
        }
    }

    private func assertTransactionsDoNotTouchLockedPeriods(
        accountId: FinancialAccountID,
        transactions: [Transaction]
    ) throws {
        let account = try storage.requireFinancialAccount(accountId: accountId)
        let lockedTaxYears = try storage.taxYearRepository
            .fetchTaxYears(entityId: account.entityId)
            .filter { $0.status != .open }
        let lockedVATPeriods = try storage.vatPeriodRepository
            .fetchVATPeriods(entityId: account.entityId)
            .filter { $0.status == .locked }
        guard lockedTaxYears.isEmpty == false || lockedVATPeriods.isEmpty == false else { return }

        for transaction in transactions {
            if lockedTaxYears.contains(where: { taxYear in
                taxYear.periodStart <= transaction.bookingDate &&
                    transaction.bookingDate <= taxYear.periodEnd
            }) {
                throw DomainError.lockedPeriod
            }
            if lockedVATPeriods.contains(where: { $0.contains(transaction.bookingDate) }) {
                throw DomainError.lockedPeriod
            }
        }
    }
}
