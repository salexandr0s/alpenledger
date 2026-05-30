import Foundation
import GRDB
import ALDomain

public struct WorkspaceBackupManifest: Codable, Hashable, Sendable {
    public static let currentFormatVersion = 2
    public static let supportedFormatVersions: Set<Int> = [1, 2]

    public let formatVersion: Int
    public let createdAt: Date
    public let workspaceId: WorkspaceID
    public let workspaceName: String
    public let storageVersion: Int
    public let workspaceDirectoryName: String
    public let keyFilename: String
    public let containsWorkspaceMasterKey: Bool
    public let excludedPaths: [String]
    public let fileHashes: [WorkspaceBackupFileHash]

    public init(
        formatVersion: Int = WorkspaceBackupManifest.currentFormatVersion,
        createdAt: Date,
        workspaceId: WorkspaceID,
        workspaceName: String,
        storageVersion: Int,
        workspaceDirectoryName: String = "workspace",
        keyFilename: String = "workspace.key",
        containsWorkspaceMasterKey: Bool = true,
        excludedPaths: [String] = ["temp"],
        fileHashes: [WorkspaceBackupFileHash] = []
    ) {
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.workspaceId = workspaceId
        self.workspaceName = workspaceName
        self.storageVersion = storageVersion
        self.workspaceDirectoryName = workspaceDirectoryName
        self.keyFilename = keyFilename
        self.containsWorkspaceMasterKey = containsWorkspaceMasterKey
        self.excludedPaths = excludedPaths
        self.fileHashes = fileHashes
    }

    private enum CodingKeys: String, CodingKey {
        case formatVersion
        case createdAt
        case workspaceId
        case workspaceName
        case storageVersion
        case workspaceDirectoryName
        case keyFilename
        case containsWorkspaceMasterKey
        case excludedPaths
        case fileHashes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        workspaceId = try container.decode(WorkspaceID.self, forKey: .workspaceId)
        workspaceName = try container.decode(String.self, forKey: .workspaceName)
        storageVersion = try container.decode(Int.self, forKey: .storageVersion)
        workspaceDirectoryName = try container.decode(String.self, forKey: .workspaceDirectoryName)
        keyFilename = try container.decode(String.self, forKey: .keyFilename)
        containsWorkspaceMasterKey = try container.decode(Bool.self, forKey: .containsWorkspaceMasterKey)
        excludedPaths = try container.decode([String].self, forKey: .excludedPaths)
        fileHashes = try container.decodeIfPresent([WorkspaceBackupFileHash].self, forKey: .fileHashes) ?? []
    }
}

public struct WorkspaceBackupFileHash: Codable, Hashable, Sendable {
    public let relativePath: String
    public let sha256Hex: String
    public let byteCount: Int

    public init(relativePath: String, sha256Hex: String, byteCount: Int) {
        self.relativePath = relativePath
        self.sha256Hex = sha256Hex
        self.byteCount = byteCount
    }
}

public enum WorkspaceBackupIntegritySeverity: String, Codable, Hashable, Sendable {
    case blocker
    case warning
}

public struct WorkspaceBackupIntegrityIssue: Codable, Hashable, Sendable {
    public let severity: WorkspaceBackupIntegritySeverity
    public let code: String
    public let message: String
    public let relativePath: String?

    public init(
        severity: WorkspaceBackupIntegritySeverity,
        code: String,
        message: String,
        relativePath: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.relativePath = relativePath
    }
}

public struct WorkspaceBackupIntegrityReport: Codable, Hashable, Sendable {
    public let manifest: WorkspaceBackupManifest?
    public let issues: [WorkspaceBackupIntegrityIssue]

    public init(manifest: WorkspaceBackupManifest?, issues: [WorkspaceBackupIntegrityIssue]) {
        self.manifest = manifest
        self.issues = issues
    }

    public var isRestorable: Bool {
        issues.contains { $0.severity == .blocker } == false
    }
}

public extension WorkspaceStorageManager {
    func validateBackup(at backupURL: URL) throws -> WorkspaceBackupIntegrityReport {
        let backupURL = backupURL.standardizedFileURL
        var issues: [WorkspaceBackupIntegrityIssue] = []
        let backupManifestURL = backupURL.appendingPathComponent("backup.json")
        guard fileManager.fileExists(atPath: backupManifestURL.path) else {
            return WorkspaceBackupIntegrityReport(
                manifest: nil,
                issues: [
                    WorkspaceBackupIntegrityIssue(
                        severity: .blocker,
                        code: "missing_manifest",
                        message: "Backup manifest is missing.",
                        relativePath: "backup.json"
                    ),
                ]
            )
        }

        let manifest: WorkspaceBackupManifest
        do {
            manifest = try JSONDecoder.alpenLedger.decode(
                WorkspaceBackupManifest.self,
                from: Data(contentsOf: backupManifestURL)
            )
        } catch {
            return WorkspaceBackupIntegrityReport(
                manifest: nil,
                issues: [
                    WorkspaceBackupIntegrityIssue(
                        severity: .blocker,
                        code: "invalid_manifest",
                        message: "Backup manifest could not be decoded.",
                        relativePath: "backup.json"
                    ),
                ]
            )
        }

        if WorkspaceBackupManifest.supportedFormatVersions.contains(manifest.formatVersion) == false {
            issues.append(
                WorkspaceBackupIntegrityIssue(
                    severity: .blocker,
                    code: "unsupported_format_version",
                    message: "Backup format version \(manifest.formatVersion) is not supported.",
                    relativePath: "backup.json"
                )
            )
        }
        if manifest.containsWorkspaceMasterKey == false {
            issues.append(
                WorkspaceBackupIntegrityIssue(
                    severity: .blocker,
                    code: "missing_declared_key",
                    message: "Backup manifest does not declare a workspace master key.",
                    relativePath: "backup.json"
                )
            )
        }

        let keyURL = backupURL.appendingPathComponent(manifest.keyFilename)
        if fileManager.fileExists(atPath: keyURL.path) == false {
            issues.append(
                WorkspaceBackupIntegrityIssue(
                    severity: .blocker,
                    code: "missing_key_file",
                    message: "Workspace master key file is missing.",
                    relativePath: manifest.keyFilename
                )
            )
        }

        let sourceWorkspaceURL = backupURL.appendingPathComponent(
            manifest.workspaceDirectoryName,
            isDirectory: true
        )
        if fileManager.fileExists(atPath: sourceWorkspaceURL.path) == false {
            issues.append(
                WorkspaceBackupIntegrityIssue(
                    severity: .blocker,
                    code: "missing_workspace_directory",
                    message: "Workspace directory is missing.",
                    relativePath: manifest.workspaceDirectoryName
                )
            )
        }

        let sourceWorkspaceManifestRelativePath = "\(manifest.workspaceDirectoryName)/workspace.json"
        let sourceWorkspaceManifestURL = sourceWorkspaceURL.appendingPathComponent("workspace.json")
        if fileManager.fileExists(atPath: sourceWorkspaceManifestURL.path) {
            do {
                let sourceWorkspaceManifest = try JSONDecoder.alpenLedger.decode(
                    WorkspaceManifest.self,
                    from: Data(contentsOf: sourceWorkspaceManifestURL)
                )
                if sourceWorkspaceManifest.workspace.id != manifest.workspaceId {
                    issues.append(
                        WorkspaceBackupIntegrityIssue(
                            severity: .blocker,
                            code: "workspace_id_mismatch",
                            message: "Workspace manifest ID does not match the backup manifest.",
                            relativePath: sourceWorkspaceManifestRelativePath
                        )
                    )
                }
            } catch {
                issues.append(
                    WorkspaceBackupIntegrityIssue(
                        severity: .blocker,
                        code: "invalid_workspace_manifest",
                        message: "Workspace manifest could not be decoded.",
                        relativePath: sourceWorkspaceManifestRelativePath
                    )
                )
            }
        } else {
            issues.append(
                WorkspaceBackupIntegrityIssue(
                    severity: .blocker,
                    code: "missing_workspace_manifest",
                    message: "Workspace manifest is missing.",
                    relativePath: sourceWorkspaceManifestRelativePath
                )
            )
        }

        for excludedPath in manifest.excludedPaths {
            let excludedURL = sourceWorkspaceURL.appendingPathComponent(excludedPath)
            if fileManager.fileExists(atPath: excludedURL.path) {
                issues.append(
                    WorkspaceBackupIntegrityIssue(
                        severity: .warning,
                        code: "excluded_path_present",
                        message: "Backup contains an excluded workspace path.",
                        relativePath: "\(manifest.workspaceDirectoryName)/\(excludedPath)"
                    )
                )
            }
        }

        if manifest.fileHashes.isEmpty {
            issues.append(
                WorkspaceBackupIntegrityIssue(
                    severity: .warning,
                    code: "missing_file_hashes",
                    message: "Backup manifest does not include per-file hashes.",
                    relativePath: "backup.json"
                )
            )
        } else {
            for expectedHash in manifest.fileHashes {
                let fileURL = backupURL.appendingPathComponent(expectedHash.relativePath)
                guard fileManager.fileExists(atPath: fileURL.path) else {
                    issues.append(
                        WorkspaceBackupIntegrityIssue(
                            severity: .blocker,
                            code: "missing_hashed_file",
                            message: "A hashed backup file is missing.",
                            relativePath: expectedHash.relativePath
                        )
                    )
                    continue
                }

                let data = try Data(contentsOf: fileURL)
                let actualHash = WorkspaceCrypto.sha256Hex(for: data)
                if actualHash != expectedHash.sha256Hex || data.count != expectedHash.byteCount {
                    issues.append(
                        WorkspaceBackupIntegrityIssue(
                            severity: .blocker,
                            code: "file_hash_mismatch",
                            message: "A backup file does not match its recorded hash.",
                            relativePath: expectedHash.relativePath
                        )
                    )
                }
            }
        }

        return WorkspaceBackupIntegrityReport(manifest: manifest, issues: issues)
    }

    func createBackup(
        for storage: WorkspaceStorage,
        at backupURL: URL,
        now: Date = .now
    ) throws -> WorkspaceBackupManifest {
        let backupURL = backupURL.standardizedFileURL
        guard backupURL.path != storage.paths.rootURL.standardizedFileURL.path,
              backupURL.path.hasPrefix(storage.paths.rootURL.standardizedFileURL.path + "/") == false
        else {
            throw DomainError.invalidWorkspaceBackup
        }

        guard fileManager.fileExists(atPath: backupURL.path) == false else {
            throw DomainError.workspaceBackupAlreadyExists
        }

        let parentURL = backupURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        let stagingURL = backupStagingURL(for: backupURL)
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: false)

        do {
            try storage.blobStore.cleanupMaterialized()
            try storage.dbPool.writeWithoutTransaction { db in
                _ = try db.checkpoint(.truncate)
            }

            var manifest = WorkspaceBackupManifest(
                createdAt: now,
                workspaceId: storage.manifest.workspace.id,
                workspaceName: storage.manifest.workspace.name,
                storageVersion: storage.manifest.workspace.storageVersion
            )

            try copyDirectoryContents(
                from: storage.paths.rootURL,
                to: stagingURL.appendingPathComponent(
                    manifest.workspaceDirectoryName,
                    isDirectory: true
                ),
                excludingDirectChildren: Set(manifest.excludedPaths)
            )

            let masterKey = try secretStore.loadWorkspaceMasterKey(workspaceId: storage.manifest.workspace.id)
            try masterKey.write(to: stagingURL.appendingPathComponent(manifest.keyFilename), options: .atomic)
            manifest = WorkspaceBackupManifest(
                createdAt: manifest.createdAt,
                workspaceId: manifest.workspaceId,
                workspaceName: manifest.workspaceName,
                storageVersion: manifest.storageVersion,
                workspaceDirectoryName: manifest.workspaceDirectoryName,
                keyFilename: manifest.keyFilename,
                containsWorkspaceMasterKey: manifest.containsWorkspaceMasterKey,
                excludedPaths: manifest.excludedPaths,
                fileHashes: try fileHashEntries(in: stagingURL, manifest: manifest)
            )

            try JSONEncoder.alpenLedger
                .encode(manifest)
                .write(to: stagingURL.appendingPathComponent("backup.json"), options: .atomic)
            try fileManager.moveItem(at: stagingURL, to: backupURL)

            return manifest
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    func restoreBackup(from backupURL: URL) throws -> WorkspaceStorage {
        let backupURL = backupURL.standardizedFileURL
        let integrityReport = try validateBackup(at: backupURL)
        guard integrityReport.isRestorable,
              let backupManifest = integrityReport.manifest
        else {
            throw DomainError.invalidWorkspaceBackup
        }

        let sourceWorkspaceURL = backupURL.appendingPathComponent(
            backupManifest.workspaceDirectoryName,
            isDirectory: true
        )
        let sourceWorkspaceManifestURL = sourceWorkspaceURL.appendingPathComponent("workspace.json")
        let sourceWorkspaceManifest = try JSONDecoder.alpenLedger.decode(
            WorkspaceManifest.self,
            from: Data(contentsOf: sourceWorkspaceManifestURL)
        )
        guard sourceWorkspaceManifest.workspace.id == backupManifest.workspaceId else {
            throw DomainError.invalidWorkspaceBackup
        }

        let masterKey = try Data(contentsOf: backupURL.appendingPathComponent(backupManifest.keyFilename))
        let masterKeyAlreadyStored: Bool
        do {
            let existingKey = try secretStore.loadWorkspaceMasterKey(workspaceId: backupManifest.workspaceId)
            guard existingKey == masterKey else {
                throw DomainError.workspaceBackupKeyConflict
            }
            masterKeyAlreadyStored = true
        } catch DomainError.missingWorkspaceKey {
            masterKeyAlreadyStored = false
        }

        let destinationRoot = try defaultWorkspacesRoot()
            .appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
        var didStoreRestoredMasterKey = false

        do {
            try copyDirectoryContents(
                from: sourceWorkspaceURL,
                to: destinationRoot,
                excludingDirectChildren: []
            )

            let destinationPaths = WorkspacePaths(rootURL: destinationRoot)
            let restoredManifest = WorkspaceManifest(
                workspace: sourceWorkspaceManifest.workspace,
                rootPath: destinationRoot.path,
                encryptionSalt: sourceWorkspaceManifest.encryptionSalt
            )
            try JSONEncoder.alpenLedger
                .encode(restoredManifest)
                .write(to: destinationPaths.manifestURL, options: .atomic)
            try fileManager.createDirectory(at: destinationPaths.tempURL, withIntermediateDirectories: true)
            if masterKeyAlreadyStored == false {
                try secretStore.storeWorkspaceMasterKey(masterKey, workspaceId: restoredManifest.workspace.id)
                didStoreRestoredMasterKey = true
            }

            return try openWorkspace(at: destinationRoot)
        } catch {
            try? fileManager.removeItem(at: destinationRoot)
            if didStoreRestoredMasterKey {
                try? secretStore.deleteWorkspaceMasterKey(workspaceId: sourceWorkspaceManifest.workspace.id)
            }
            throw error
        }
    }

    private func fileHashEntries(in backupURL: URL, manifest: WorkspaceBackupManifest) throws -> [WorkspaceBackupFileHash] {
        var urls: [URL] = [
            backupURL.appendingPathComponent(manifest.keyFilename),
        ]
        let workspaceURL = backupURL.appendingPathComponent(
            manifest.workspaceDirectoryName,
            isDirectory: true
        )
        if let enumerator = fileManager.enumerator(
            at: workspaceURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if values.isRegularFile == true {
                    urls.append(fileURL)
                }
            }
        }

        return try urls
            .sorted { relativePath(for: $0, baseURL: backupURL) < relativePath(for: $1, baseURL: backupURL) }
            .map { url in
                let data = try Data(contentsOf: url)
                return WorkspaceBackupFileHash(
                    relativePath: relativePath(for: url, baseURL: backupURL),
                    sha256Hex: WorkspaceCrypto.sha256Hex(for: data),
                    byteCount: data.count
                )
            }
    }

    private func relativePath(for url: URL, baseURL: URL) -> String {
        let basePath = baseURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(basePath + "/") else {
            return url.lastPathComponent
        }
        return String(path.dropFirst(basePath.count + 1))
    }

    private func backupStagingURL(for backupURL: URL) -> URL {
        backupURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                ".\(backupURL.lastPathComponent).partial-\(UUID().uuidString.lowercased())",
                isDirectory: true
            )
    }

    private func copyDirectoryContents(
        from sourceURL: URL,
        to destinationURL: URL,
        excludingDirectChildren excludedNames: Set<String>
    ) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw DomainError.invalidWorkspaceBackup
        }
        guard fileManager.fileExists(atPath: destinationURL.path) == false else {
            throw DomainError.workspaceBackupAlreadyExists
        }

        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        let contents = try fileManager.contentsOfDirectory(
            at: sourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for sourceChild in contents where excludedNames.contains(sourceChild.lastPathComponent) == false {
            let destinationChild = destinationURL.appendingPathComponent(
                sourceChild.lastPathComponent,
                isDirectory: sourceChild.hasDirectoryPath
            )
            try fileManager.copyItem(at: sourceChild, to: destinationChild)
        }
    }
}
