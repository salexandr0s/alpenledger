import Foundation
import Security
import ALDomain

public protocol SecretStore: Sendable {
    func storeWorkspaceMasterKey(_ data: Data, workspaceId: WorkspaceID) throws
    func loadWorkspaceMasterKey(workspaceId: WorkspaceID) throws -> Data
    func deleteWorkspaceMasterKey(workspaceId: WorkspaceID) throws
}

public final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service = "com.alpenledger.workspace.masterkey"

    public init() {}

    public func storeWorkspaceMasterKey(_ data: Data, workspaceId: WorkspaceID) throws {
        let account = workspaceId.description
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)

        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    public func loadWorkspaceMasterKey(workspaceId: WorkspaceID) throws -> Data {
        let account = workspaceId.description
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw DomainError.missingWorkspaceKey
        }
        return data
    }

    public func deleteWorkspaceMasterKey(workspaceId: WorkspaceID) throws {
        let account = workspaceId.description
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var keys: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func storeWorkspaceMasterKey(_ data: Data, workspaceId: WorkspaceID) throws {
        lock.lock()
        defer { lock.unlock() }
        keys[workspaceId.description] = data
    }

    public func loadWorkspaceMasterKey(workspaceId: WorkspaceID) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let data = keys[workspaceId.description] else {
            throw DomainError.missingWorkspaceKey
        }
        return data
    }

    public func deleteWorkspaceMasterKey(workspaceId: WorkspaceID) throws {
        lock.lock()
        defer { lock.unlock() }
        keys.removeValue(forKey: workspaceId.description)
    }
}

public final class FileSecretStore: SecretStore, @unchecked Sendable {
    private let directoryURL: URL
    private let fileManager: FileManager

    public init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    public func storeWorkspaceMasterKey(_ data: Data, workspaceId: WorkspaceID) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: keyURL(for: workspaceId), options: .atomic)
    }

    public func loadWorkspaceMasterKey(workspaceId: WorkspaceID) throws -> Data {
        let url = keyURL(for: workspaceId)
        guard fileManager.fileExists(atPath: url.path) else {
            throw DomainError.missingWorkspaceKey
        }
        return try Data(contentsOf: url)
    }

    public func deleteWorkspaceMasterKey(workspaceId: WorkspaceID) throws {
        let url = keyURL(for: workspaceId)
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }

    private func keyURL(for workspaceId: WorkspaceID) -> URL {
        directoryURL.appendingPathComponent("\(workspaceId.description).key")
    }
}
