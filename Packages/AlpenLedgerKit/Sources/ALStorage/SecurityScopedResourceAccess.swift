import Foundation

public struct SecurityScopedResourceAccess: Sendable {
    private let startAccessing: @Sendable (URL) -> Bool
    private let stopAccessing: @Sendable (URL) -> Void

    public init(
        startAccessing: @escaping @Sendable (URL) -> Bool,
        stopAccessing: @escaping @Sendable (URL) -> Void
    ) {
        self.startAccessing = startAccessing
        self.stopAccessing = stopAccessing
    }

    public static let live = SecurityScopedResourceAccess(
        startAccessing: { $0.startAccessingSecurityScopedResource() },
        stopAccessing: { $0.stopAccessingSecurityScopedResource() }
    )

    public func withAccess<T>(to url: URL, _ operation: () throws -> T) rethrows -> T {
        let didStartAccessing = startAccessing(url)
        defer {
            if didStartAccessing {
                stopAccessing(url)
            }
        }
        return try operation()
    }
}
