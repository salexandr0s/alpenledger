import CryptoKit
import Foundation
import ALDomain

public protocol BlobStore: Sendable {
    func store(data: Data) throws -> String
    func store(contentsOf url: URL) throws -> String
    func read(hash: String) throws -> Data
    func materialize(hash: String, fileExtension: String?) throws -> URL
    func cleanupMaterialized() throws
    func cleanupMaterialized(hash: String, fileExtension: String?) throws
}

public final class EncryptedBlobStore: BlobStore, @unchecked Sendable {
    private let paths: WorkspacePaths
    private let key: SymmetricKey
    private let fileManager: FileManager

    public init(paths: WorkspacePaths, key: SymmetricKey, fileManager: FileManager = .default) {
        self.paths = paths
        self.key = key
        self.fileManager = fileManager
    }

    public func store(data: Data) throws -> String {
        let hash = WorkspaceCrypto.sha256Hex(for: data)
        let destinationURL = encryptedBlobURL(for: hash)

        guard fileManager.fileExists(atPath: destinationURL.path) == false else {
            return hash
        }

        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let sealedBox = try AES.GCM.seal(data, using: key)
        try sealedBox.combined?.write(to: destinationURL, options: .atomic)
        return hash
    }

    public func store(contentsOf url: URL) throws -> String {
        try store(data: Data(contentsOf: url))
    }

    public func read(hash: String) throws -> Data {
        let encryptedData = try Data(contentsOf: encryptedBlobURL(for: hash))
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    public func materialize(hash: String, fileExtension: String?) throws -> URL {
        try fileManager.createDirectory(at: paths.tempURL, withIntermediateDirectories: true)
        let filename = fileExtension.map { "\(hash).\($0)" } ?? hash
        let destinationURL = paths.tempURL.appendingPathComponent(filename)
        try read(hash: hash).write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    public func cleanupMaterialized() throws {
        guard fileManager.fileExists(atPath: paths.tempURL.path) else { return }
        let contents = try fileManager.contentsOfDirectory(
            at: paths.tempURL,
            includingPropertiesForKeys: nil
        )
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }

    public func cleanupMaterialized(hash: String, fileExtension: String?) throws {
        let filename = fileExtension.map { "\(hash).\($0)" } ?? hash
        let url = paths.tempURL.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func encryptedBlobURL(for hash: String) -> URL {
        let first = String(hash.prefix(2))
        let second = String(hash.dropFirst(2).prefix(2))
        return paths.blobsURL
            .appendingPathComponent(first, isDirectory: true)
            .appendingPathComponent(second, isDirectory: true)
            .appendingPathComponent("\(hash).blob")
    }
}
