import Foundation

/// Duplicated for the widget extension target (no shared framework).
enum WidgetAppConstants {
    static let appGroupId = "group.com.tripmeter.TripMeter"
}

enum WidgetSharedCaptureFlag {
    private static let key = "pendingCaptureFocus"

    static func setPending() {
        UserDefaults(suiteName: WidgetAppConstants.appGroupId)?.set(true, forKey: key)
    }
}
