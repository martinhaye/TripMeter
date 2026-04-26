import Foundation
import Observation

@Observable
@MainActor
final class AppSession {
    private(set) var unlockedPrivateKey: SecureBytes?
    private(set) var failedUnlockAttempts: Int = 0
    private(set) var backupReminderShownForCurrentUnlock = false

    var isUnlocked: Bool { unlockedPrivateKey != nil }

    func unlock(passphrase: String) throws {
        let key = try KeyManager.unwrapPrivateKey(passphrase: passphrase)
        unlockedPrivateKey = key
        failedUnlockAttempts = 0
        backupReminderShownForCurrentUnlock = false
    }

    func lock() {
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
