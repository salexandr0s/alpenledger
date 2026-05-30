import AppKit
import Foundation

struct BackupPanelClient {
    var createBackupDestination: @MainActor (_ defaultFilename: String) -> URL?
    var backupValidationSource: @MainActor () -> URL?
    var backupRestoreSource: @MainActor () -> URL?

    static let live = BackupPanelClient(
        createBackupDestination: { defaultFilename in
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.prompt = "Create Backup"
            panel.nameFieldStringValue = defaultFilename
            panel.message = "Backup bundles include the workspace encryption key. Store them in a protected local location."

            guard panel.runModal() == .OK else { return nil }
            return panel.url
        },
        backupValidationSource: {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.prompt = "Check Backup"
            panel.message = "Choose an AlpenLedger backup bundle to verify before restoring."

            guard panel.runModal() == .OK else { return nil }
            return panel.url
        },
        backupRestoreSource: {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.prompt = "Restore Backup"
            panel.message = "Choose an AlpenLedger backup bundle created from a trusted local workspace."

            guard panel.runModal() == .OK else { return nil }
            return panel.url
        }
    )

#if DEBUG
    static func debugAutomation(from environment: [String: String]) -> BackupPanelClient? {
        let createURL = environment.urlValue(for: "ALPENLEDGER_UI_TEST_CREATE_BACKUP_URL")
        let validateURL = environment.urlValue(for: "ALPENLEDGER_UI_TEST_VALIDATE_BACKUP_URL")
        let restoreURL = environment.urlValue(for: "ALPENLEDGER_UI_TEST_RESTORE_BACKUP_URL")

        guard createURL != nil || validateURL != nil || restoreURL != nil else {
            return nil
        }

        return BackupPanelClient(
            createBackupDestination: { defaultFilename in
                createURL ?? BackupPanelClient.live.createBackupDestination(defaultFilename)
            },
            backupValidationSource: {
                validateURL ?? BackupPanelClient.live.backupValidationSource()
            },
            backupRestoreSource: {
                restoreURL ?? BackupPanelClient.live.backupRestoreSource()
            }
        )
    }
#endif
}

#if DEBUG
private extension Dictionary where Key == String, Value == String {
    func urlValue(for key: String) -> URL? {
        guard let path = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
              path.isEmpty == false
        else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
}
#endif
