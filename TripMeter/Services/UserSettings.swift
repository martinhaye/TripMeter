import Foundation

enum UserSettings {
    private static let lockKey = "tripmeter.backgroundLockSeconds"

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
}
