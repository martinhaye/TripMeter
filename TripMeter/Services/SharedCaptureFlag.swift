import Foundation

/// Lets the widget extension signal the main app to focus capture after launch.
enum SharedCaptureFlag {
    private static let key = "pendingCaptureFocus"

    static func setPending() {
        UserDefaults(suiteName: AppConstants.appGroupId)?.set(true, forKey: key)
    }

    static func consumePending() -> Bool {
        guard let d = UserDefaults(suiteName: AppConstants.appGroupId) else { return false }
        let v = d.bool(forKey: key)
        if v { d.set(false, forKey: key) }
        return v
    }
}
