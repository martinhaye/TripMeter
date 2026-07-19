import Foundation
import Observation

@Observable
@MainActor
final class AppSession {
    private(set) var unlockedPrivateKey: SecureBytes?
    private(set) var failedUnlockAttempts: Int = 0
    private(set) var backupReminderShownForCurrentUnlock = false
    /// Decrypted thought text for the current unlock session; zeroed on `lock()`.
    let noteTextCache = NotePlaintextCache()
    /// Lowercase search index; built while Review search is active, zeroed when search ends or on `lock()`.
    let noteSearchIndex = NoteSearchIndex()

    var isUnlocked: Bool { unlockedPrivateKey != nil }

    /// Cached decrypt of a note's plaintext, or `nil` when locked / decrypt fails.
    func decryptedText(for note: Note) -> String? {
        guard let key = unlockedPrivateKey else { return nil }
        return noteTextCache.text(for: note, privateKey: key)
    }

    func unlock(passphrase: String) throws {
        noteTextCache.clear()
        noteSearchIndex.clear()
        let key = try KeyManager.unwrapPrivateKey(passphrase: passphrase)
        unlockedPrivateKey = key
        failedUnlockAttempts = 0
        backupReminderShownForCurrentUnlock = false
    }

    func unlockAsync(
        passphrase: String,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        noteTextCache.clear()
        noteSearchIndex.clear()
        let key = try await Task.detached(priority: .userInitiated) {
            try KeyManager.unwrapPrivateKey(passphrase: passphrase, progress: progress)
        }.value
        unlockedPrivateKey = key
        failedUnlockAttempts = 0
        backupReminderShownForCurrentUnlock = false
    }

    func lock() {
        noteTextCache.clear()
        noteSearchIndex.clear()
        unlockedPrivateKey = nil
        backupReminderShownForCurrentUnlock = false
    }

    func recordFailedUnlock() {
        failedUnlockAttempts += 1
    }

    /// Throttle after failed attempts: 0.5s, 1s, 2s, … (capped).
    var unlockDelaySeconds: Double {
        guard failedUnlockAttempts > 0 else { return 0 }
        let exp = min(failedUnlockAttempts - 1, 6)
        return 0.5 * pow(2.0, Double(exp))
    }

    func shouldShowBackupReminder() -> Bool {
        guard isUnlocked else { return false }
        guard !backupReminderShownForCurrentUnlock else { return false }
        return UserSettings.needsBackupReminder
    }

    func markBackupReminderShown() {
        backupReminderShownForCurrentUnlock = true
    }
}
