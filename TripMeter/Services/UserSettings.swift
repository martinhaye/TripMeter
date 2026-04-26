import Foundation

enum UserSettings {
    private static let lockKey = "tripmeter.backgroundLockSeconds"
    private static let lastBackupKey = "tripmeter.lastBackupAt"

    /// Seconds before locking review session after app backgrounds (default 120).
    static var backgroundLockSeconds: TimeInterval {
        get {
            let v = UserDefaults.standard.object(forKey: lockKey) as? Double
            if let v, v > 0 { return v }
            return 120
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lockKey)
        }
    }

    static var lastBackupAt: Date? {
        get {
            UserDefaults.standard.object(forKey: lastBackupKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastBackupKey)
        }
    }

    static var needsBackupReminder: Bool {
        guard let lastBackupAt else { return true }
        guard let days = Calendar.current.dateComponents([.day], from: lastBackupAt, to: .now).day else {
            return true
        }
        return days >= 30
    }
}
