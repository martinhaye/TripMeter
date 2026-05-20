import Foundation

extension Notification.Name {
    static let tripMeterFocusCapture = Notification.Name("tripMeterFocusCapture")
    /// Switch to Capture and focus the editor; optional `AppConstants.captureTripNameUserInfoKey` in `userInfo`.
    static let tripMeterOpenCapture = Notification.Name("tripMeterOpenCapture")
    static let tripMeterDidUnlock = Notification.Name("tripMeterDidUnlock")
}
