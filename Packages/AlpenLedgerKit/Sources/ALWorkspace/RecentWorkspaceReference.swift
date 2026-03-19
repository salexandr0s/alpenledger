import Foundation
import ALDomain

public struct RecentWorkspaceReference: Codable, Hashable, Sendable {
    public let workspaceId: WorkspaceID
    public let name: String
    public let path: String
    public let lastOpenedAt: Date

    public init(workspaceId: WorkspaceID, name: String, path: String, lastOpenedAt: Date = .now) {
        self.workspaceId = workspaceId
        self.name = name
        self.path = path
        self.lastOpenedAt = lastOpenedAt
    }
}

public final class RecentWorkspacesStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "alpenledger.recent-workspaces"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> [RecentWorkspaceReference] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }

        return (try? JSONDecoder.alpenLedger.decode([RecentWorkspaceReference].self, from: data)) ?? []
    }

    public func add(_ reference: RecentWorkspaceReference) {
        var items = load().filter { $0.workspaceId != reference.workspaceId }
        items.insert(reference, at: 0)
        items = Array(items.prefix(10))
        defaults.set(try? JSONEncoder.alpenLedger.encode(items), forKey: key)
    }
}
