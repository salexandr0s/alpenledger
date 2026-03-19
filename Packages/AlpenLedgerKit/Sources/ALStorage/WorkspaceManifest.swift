import Foundation
import ALDomain

public struct WorkspaceManifest: Codable, Hashable, Sendable {
    public let workspace: Workspace
    public let rootPath: String
    public let encryptionSalt: Data

    public init(workspace: Workspace, rootPath: String, encryptionSalt: Data) {
        self.workspace = workspace
        self.rootPath = rootPath
        self.encryptionSalt = encryptionSalt
    }
}

public struct WorkspacePaths: Hashable, Sendable {
    public let rootURL: URL
    public let manifestURL: URL
    public let databaseURL: URL
    public let blobsURL: URL
    public let exportsURL: URL
    public let tempURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
        manifestURL = rootURL.appendingPathComponent("workspace.json")
        databaseURL = rootURL.appendingPathComponent("workspace.sqlite")
        blobsURL = rootURL.appendingPathComponent("blobs", isDirectory: true)
        exportsURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        tempURL = rootURL.appendingPathComponent("temp", isDirectory: true)
    }
}
