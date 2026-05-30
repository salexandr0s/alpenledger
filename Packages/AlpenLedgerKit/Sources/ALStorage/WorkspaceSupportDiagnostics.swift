import Foundation
import GRDB
import ALDomain

public struct WorkspaceSupportDiagnosticsReport: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public let formatVersion: Int
    public let generatedAt: Date
    public let workspace: WorkspaceSupportDiagnosticsWorkspace
    public let databaseHealth: WorkspaceDatabaseHealthReport
    public let tableCounts: [WorkspaceSupportDiagnosticsTableCount]
    public let filesystem: WorkspaceSupportDiagnosticsFilesystem
    public let privacy: WorkspaceSupportDiagnosticsPrivacy

    public init(
        formatVersion: Int = WorkspaceSupportDiagnosticsReport.currentFormatVersion,
        generatedAt: Date,
        workspace: WorkspaceSupportDiagnosticsWorkspace,
        databaseHealth: WorkspaceDatabaseHealthReport,
        tableCounts: [WorkspaceSupportDiagnosticsTableCount],
        filesystem: WorkspaceSupportDiagnosticsFilesystem,
        privacy: WorkspaceSupportDiagnosticsPrivacy = WorkspaceSupportDiagnosticsPrivacy()
    ) {
        self.formatVersion = formatVersion
        self.generatedAt = generatedAt
        self.workspace = workspace
        self.databaseHealth = databaseHealth
        self.tableCounts = tableCounts
        self.filesystem = filesystem
        self.privacy = privacy
    }
}

public struct WorkspaceSupportDiagnosticsWorkspace: Codable, Equatable, Sendable {
    public let workspaceId: WorkspaceID
    public let storageVersion: Int
    public let createdAt: Date
    public let defaultCurrency: CurrencyCode
    public let privacyMode: PrivacyMode
    public let workspaceDirectoryFingerprint: String

    public init(
        workspaceId: WorkspaceID,
        storageVersion: Int,
        createdAt: Date,
        defaultCurrency: CurrencyCode,
        privacyMode: PrivacyMode,
        workspaceDirectoryFingerprint: String
    ) {
        self.workspaceId = workspaceId
        self.storageVersion = storageVersion
        self.createdAt = createdAt
        self.defaultCurrency = defaultCurrency
        self.privacyMode = privacyMode
        self.workspaceDirectoryFingerprint = workspaceDirectoryFingerprint
    }
}

public struct WorkspaceSupportDiagnosticsTableCount: Codable, Equatable, Identifiable, Sendable {
    public var id: String { tableName }

    public let tableName: String
    public let rowCount: Int

    public init(tableName: String, rowCount: Int) {
        self.tableName = tableName
        self.rowCount = rowCount
    }
}

public struct WorkspaceSupportDiagnosticsFilesystem: Codable, Equatable, Sendable {
    public let databaseFiles: [WorkspaceSupportDiagnosticsFile]
    public let blobs: WorkspaceSupportDiagnosticsDirectory
    public let exports: WorkspaceSupportDiagnosticsDirectory
    public let temp: WorkspaceSupportDiagnosticsDirectory

    public init(
        databaseFiles: [WorkspaceSupportDiagnosticsFile],
        blobs: WorkspaceSupportDiagnosticsDirectory,
        exports: WorkspaceSupportDiagnosticsDirectory,
        temp: WorkspaceSupportDiagnosticsDirectory
    ) {
        self.databaseFiles = databaseFiles
        self.blobs = blobs
        self.exports = exports
        self.temp = temp
    }
}

public struct WorkspaceSupportDiagnosticsFile: Codable, Equatable, Identifiable, Sendable {
    public var id: String { relativePath }

    public let relativePath: String
    public let byteCount: Int
    public let exists: Bool

    public init(relativePath: String, byteCount: Int, exists: Bool) {
        self.relativePath = relativePath
        self.byteCount = byteCount
        self.exists = exists
    }
}

public struct WorkspaceSupportDiagnosticsDirectory: Codable, Equatable, Sendable {
    public let relativePath: String
    public let exists: Bool
    public let fileCount: Int
    public let directoryCount: Int
    public let byteCount: Int

    public init(
        relativePath: String,
        exists: Bool,
        fileCount: Int,
        directoryCount: Int,
        byteCount: Int
    ) {
        self.relativePath = relativePath
        self.exists = exists
        self.fileCount = fileCount
        self.directoryCount = directoryCount
        self.byteCount = byteCount
    }
}

public struct WorkspaceSupportDiagnosticsPrivacy: Codable, Equatable, Sendable {
    public let includesWorkspaceName: Bool
    public let includesAbsolutePaths: Bool
    public let includesWorkspaceMasterKey: Bool
    public let includesDocumentContents: Bool
    public let includesDocumentFilenames: Bool
    public let includesTransactionDescriptions: Bool
    public let includesTransactionAmounts: Bool

    public init(
        includesWorkspaceName: Bool = false,
        includesAbsolutePaths: Bool = false,
        includesWorkspaceMasterKey: Bool = false,
        includesDocumentContents: Bool = false,
        includesDocumentFilenames: Bool = false,
        includesTransactionDescriptions: Bool = false,
        includesTransactionAmounts: Bool = false
    ) {
        self.includesWorkspaceName = includesWorkspaceName
        self.includesAbsolutePaths = includesAbsolutePaths
        self.includesWorkspaceMasterKey = includesWorkspaceMasterKey
        self.includesDocumentContents = includesDocumentContents
        self.includesDocumentFilenames = includesDocumentFilenames
        self.includesTransactionDescriptions = includesTransactionDescriptions
        self.includesTransactionAmounts = includesTransactionAmounts
    }
}

public struct WorkspaceSupportBundle: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public let formatVersion: Int
    public let generatedAt: Date
    public let diagnostics: WorkspaceSupportDiagnosticsReport
    public let auditLog: WorkspaceSupportAuditLogSummary
    public let privacy: WorkspaceSupportBundlePrivacy

    public init(
        formatVersion: Int = WorkspaceSupportBundle.currentFormatVersion,
        generatedAt: Date,
        diagnostics: WorkspaceSupportDiagnosticsReport,
        auditLog: WorkspaceSupportAuditLogSummary,
        privacy: WorkspaceSupportBundlePrivacy = WorkspaceSupportBundlePrivacy()
    ) {
        self.formatVersion = formatVersion
        self.generatedAt = generatedAt
        self.diagnostics = diagnostics
        self.auditLog = auditLog
        self.privacy = privacy
    }
}

public struct WorkspaceSupportAuditLogSummary: Codable, Equatable, Sendable {
    public let totalEventCount: Int
    public let firstOccurredAt: Date?
    public let lastOccurredAt: Date?
    public let eventsByType: [WorkspaceSupportAuditEventTypeCount]
    public let eventsByActorType: [WorkspaceSupportAuditActorTypeCount]
    public let objectsByKind: [WorkspaceSupportAuditObjectKindCount]
    public let recentEventLimit: Int
    public let recentEvents: [WorkspaceSupportAuditEventSummary]

    public init(
        totalEventCount: Int,
        firstOccurredAt: Date?,
        lastOccurredAt: Date?,
        eventsByType: [WorkspaceSupportAuditEventTypeCount],
        eventsByActorType: [WorkspaceSupportAuditActorTypeCount],
        objectsByKind: [WorkspaceSupportAuditObjectKindCount],
        recentEventLimit: Int,
        recentEvents: [WorkspaceSupportAuditEventSummary]
    ) {
        self.totalEventCount = totalEventCount
        self.firstOccurredAt = firstOccurredAt
        self.lastOccurredAt = lastOccurredAt
        self.eventsByType = eventsByType
        self.eventsByActorType = eventsByActorType
        self.objectsByKind = objectsByKind
        self.recentEventLimit = recentEventLimit
        self.recentEvents = recentEvents
    }
}

public struct WorkspaceSupportAuditEventTypeCount: Codable, Equatable, Identifiable, Sendable {
    public var id: AuditEventType { eventType }

    public let eventType: AuditEventType
    public let count: Int

    public init(eventType: AuditEventType, count: Int) {
        self.eventType = eventType
        self.count = count
    }
}

public struct WorkspaceSupportAuditActorTypeCount: Codable, Equatable, Identifiable, Sendable {
    public var id: AuditActorType { actorType }

    public let actorType: AuditActorType
    public let count: Int

    public init(actorType: AuditActorType, count: Int) {
        self.actorType = actorType
        self.count = count
    }
}

public struct WorkspaceSupportAuditObjectKindCount: Codable, Equatable, Identifiable, Sendable {
    public var id: ObjectKind { objectKind }

    public let objectKind: ObjectKind
    public let count: Int

    public init(objectKind: ObjectKind, count: Int) {
        self.objectKind = objectKind
        self.count = count
    }
}

public struct WorkspaceSupportAuditEventSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: String { eventFingerprint }

    public let eventFingerprint: String
    public let occurredAt: Date
    public let actorType: AuditActorType
    public let actorFingerprint: String
    public let eventType: AuditEventType
    public let objectKind: ObjectKind
    public let objectFingerprint: String
    public let payloadPresent: Bool
    public let payloadByteCount: Int

    public init(
        eventFingerprint: String,
        occurredAt: Date,
        actorType: AuditActorType,
        actorFingerprint: String,
        eventType: AuditEventType,
        objectKind: ObjectKind,
        objectFingerprint: String,
        payloadPresent: Bool,
        payloadByteCount: Int
    ) {
        self.eventFingerprint = eventFingerprint
        self.occurredAt = occurredAt
        self.actorType = actorType
        self.actorFingerprint = actorFingerprint
        self.eventType = eventType
        self.objectKind = objectKind
        self.objectFingerprint = objectFingerprint
        self.payloadPresent = payloadPresent
        self.payloadByteCount = payloadByteCount
    }
}

public struct WorkspaceSupportBundlePrivacy: Codable, Equatable, Sendable {
    public let includesRawAuditEventIds: Bool
    public let includesRawAuditActorIds: Bool
    public let includesRawAuditObjectIds: Bool
    public let includesRawAuditPayloads: Bool
    public let includesWorkspaceName: Bool
    public let includesAbsolutePaths: Bool
    public let includesWorkspaceMasterKey: Bool
    public let includesDocumentContents: Bool
    public let includesDocumentFilenames: Bool
    public let includesTransactionDescriptions: Bool
    public let includesTransactionAmounts: Bool

    public init(
        includesRawAuditEventIds: Bool = false,
        includesRawAuditActorIds: Bool = false,
        includesRawAuditObjectIds: Bool = false,
        includesRawAuditPayloads: Bool = false,
        includesWorkspaceName: Bool = false,
        includesAbsolutePaths: Bool = false,
        includesWorkspaceMasterKey: Bool = false,
        includesDocumentContents: Bool = false,
        includesDocumentFilenames: Bool = false,
        includesTransactionDescriptions: Bool = false,
        includesTransactionAmounts: Bool = false
    ) {
        self.includesRawAuditEventIds = includesRawAuditEventIds
        self.includesRawAuditActorIds = includesRawAuditActorIds
        self.includesRawAuditObjectIds = includesRawAuditObjectIds
        self.includesRawAuditPayloads = includesRawAuditPayloads
        self.includesWorkspaceName = includesWorkspaceName
        self.includesAbsolutePaths = includesAbsolutePaths
        self.includesWorkspaceMasterKey = includesWorkspaceMasterKey
        self.includesDocumentContents = includesDocumentContents
        self.includesDocumentFilenames = includesDocumentFilenames
        self.includesTransactionDescriptions = includesTransactionDescriptions
        self.includesTransactionAmounts = includesTransactionAmounts
    }
}

public extension WorkspaceStorage {
    func supportDiagnosticsReport(generatedAt: Date = .now) throws -> WorkspaceSupportDiagnosticsReport {
        let databaseHealth = try databaseHealthReport()
        let tableCounts = try supportDiagnosticsTableCounts()
        let filesystem = supportDiagnosticsFilesystem()
        return WorkspaceSupportDiagnosticsReport(
            generatedAt: generatedAt,
            workspace: WorkspaceSupportDiagnosticsWorkspace(
                workspaceId: manifest.workspace.id,
                storageVersion: manifest.workspace.storageVersion,
                createdAt: manifest.workspace.createdAt,
                defaultCurrency: manifest.workspace.defaultCurrency,
                privacyMode: manifest.workspace.privacyMode,
                workspaceDirectoryFingerprint: paths.rootURL.lastPathComponent
            ),
            databaseHealth: databaseHealth,
            tableCounts: tableCounts,
            filesystem: filesystem
        )
    }

    @discardableResult
    func exportSupportDiagnostics(to destinationURL: URL, generatedAt: Date = .now) throws -> WorkspaceSupportDiagnosticsReport {
        let report = try supportDiagnosticsReport(generatedAt: generatedAt)
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder.alpenLedger.encode(report).write(to: destinationURL, options: .atomic)
        return report
    }

    func supportBundle(
        generatedAt: Date = .now,
        recentAuditEventLimit: Int = 100
    ) throws -> WorkspaceSupportBundle {
        WorkspaceSupportBundle(
            generatedAt: generatedAt,
            diagnostics: try supportDiagnosticsReport(generatedAt: generatedAt),
            auditLog: try supportAuditLogSummary(recentEventLimit: recentAuditEventLimit)
        )
    }

    @discardableResult
    func exportSupportBundle(
        to destinationURL: URL,
        generatedAt: Date = .now,
        recentAuditEventLimit: Int = 100
    ) throws -> WorkspaceSupportBundle {
        let bundle = try supportBundle(
            generatedAt: generatedAt,
            recentAuditEventLimit: recentAuditEventLimit
        )
        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder.alpenLedger.encode(bundle).write(to: destinationURL, options: .atomic)
        return bundle
    }
}

private extension WorkspaceStorage {
    func supportAuditLogSummary(recentEventLimit: Int) throws -> WorkspaceSupportAuditLogSummary {
        let events = try auditEventRepository.fetchAuditEvents(
            workspaceId: manifest.workspace.id,
            objectRef: nil
        )
        let sortedEvents = events.sorted { $0.occurredAt > $1.occurredAt }
        let boundedRecentLimit = max(0, recentEventLimit)

        return WorkspaceSupportAuditLogSummary(
            totalEventCount: sortedEvents.count,
            firstOccurredAt: sortedEvents.map(\.occurredAt).min(),
            lastOccurredAt: sortedEvents.map(\.occurredAt).max(),
            eventsByType: supportAuditEventTypeCounts(for: sortedEvents),
            eventsByActorType: supportAuditActorTypeCounts(for: sortedEvents),
            objectsByKind: supportAuditObjectKindCounts(for: sortedEvents),
            recentEventLimit: boundedRecentLimit,
            recentEvents: sortedEvents.prefix(boundedRecentLimit).map(supportAuditEventSummary)
        )
    }

    func supportAuditEventTypeCounts(for events: [AuditEvent]) -> [WorkspaceSupportAuditEventTypeCount] {
        Dictionary(grouping: events, by: \.eventType)
            .map { eventType, events in
                WorkspaceSupportAuditEventTypeCount(eventType: eventType, count: events.count)
            }
            .sorted { $0.eventType.rawValue < $1.eventType.rawValue }
    }

    func supportAuditActorTypeCounts(for events: [AuditEvent]) -> [WorkspaceSupportAuditActorTypeCount] {
        Dictionary(grouping: events, by: \.actorType)
            .map { actorType, events in
                WorkspaceSupportAuditActorTypeCount(actorType: actorType, count: events.count)
            }
            .sorted { $0.actorType.rawValue < $1.actorType.rawValue }
    }

    func supportAuditObjectKindCounts(for events: [AuditEvent]) -> [WorkspaceSupportAuditObjectKindCount] {
        Dictionary(grouping: events, by: \.objectRef.kind)
            .map { objectKind, events in
                WorkspaceSupportAuditObjectKindCount(objectKind: objectKind, count: events.count)
            }
            .sorted { $0.objectKind.rawValue < $1.objectKind.rawValue }
    }

    func supportAuditEventSummary(_ event: AuditEvent) -> WorkspaceSupportAuditEventSummary {
        let payloadByteCount = event.payload.map { Data($0.utf8).count } ?? 0
        return WorkspaceSupportAuditEventSummary(
            eventFingerprint: supportFingerprint(for: event.id.description),
            occurredAt: event.occurredAt,
            actorType: event.actorType,
            actorFingerprint: supportFingerprint(for: event.actorId),
            eventType: event.eventType,
            objectKind: event.objectRef.kind,
            objectFingerprint: supportFingerprint(for: event.objectRef.stringValue),
            payloadPresent: event.payload != nil,
            payloadByteCount: payloadByteCount
        )
    }

    func supportDiagnosticsTableCounts() throws -> [WorkspaceSupportDiagnosticsTableCount] {
        try dbPool.read { db in
            try AlpenLedgerDatabaseMigrations.requiredTables.compactMap { tableName in
                guard try db.tableExists(tableName) else { return nil }
                let count = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM \(quotedSQLIdentifier(tableName))"
                ) ?? 0
                return WorkspaceSupportDiagnosticsTableCount(tableName: tableName, rowCount: count)
            }
        }
    }

    func supportDiagnosticsFilesystem() -> WorkspaceSupportDiagnosticsFilesystem {
        WorkspaceSupportDiagnosticsFilesystem(
            databaseFiles: databaseFileSummaries(),
            blobs: directorySummary(at: paths.blobsURL, relativePath: "blobs"),
            exports: directorySummary(at: paths.exportsURL, relativePath: "exports"),
            temp: directorySummary(at: paths.tempURL, relativePath: "temp")
        )
    }

    func databaseFileSummaries() -> [WorkspaceSupportDiagnosticsFile] {
        let databaseFilename = paths.databaseURL.lastPathComponent
        return [
            databaseFilename,
            "\(databaseFilename)-wal",
            "\(databaseFilename)-shm",
        ].map { filename in
            let fileURL = paths.databaseURL.deletingLastPathComponent().appendingPathComponent(filename)
            return fileSummary(at: fileURL, relativePath: filename)
        }
    }

    func fileSummary(at url: URL, relativePath: String) -> WorkspaceSupportDiagnosticsFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return WorkspaceSupportDiagnosticsFile(relativePath: relativePath, byteCount: 0, exists: false)
        }
        let byteCount = (
            try? FileManager.default
                .attributesOfItem(atPath: url.path)[.size] as? NSNumber
        )?.intValue ?? 0
        return WorkspaceSupportDiagnosticsFile(relativePath: relativePath, byteCount: byteCount, exists: true)
    }

    func directorySummary(at url: URL, relativePath: String) -> WorkspaceSupportDiagnosticsDirectory {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return WorkspaceSupportDiagnosticsDirectory(
                relativePath: relativePath,
                exists: false,
                fileCount: 0,
                directoryCount: 0,
                byteCount: 0
            )
        }

        var fileCount = 0
        var directoryCount = 0
        var byteCount = 0
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey]
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try? fileURL.resourceValues(forKeys: resourceKeys)
            if values?.isRegularFile == true {
                fileCount += 1
                byteCount += values?.fileSize ?? 0
            } else if values?.isDirectory == true {
                directoryCount += 1
            }
        }

        return WorkspaceSupportDiagnosticsDirectory(
            relativePath: relativePath,
            exists: true,
            fileCount: fileCount,
            directoryCount: directoryCount,
            byteCount: byteCount
        )
    }
}

private func quotedSQLIdentifier(_ identifier: String) -> String {
    "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
}

private func supportFingerprint(for value: String) -> String {
    String(WorkspaceCrypto.sha256Hex(for: Data(value.utf8)).prefix(16))
}
