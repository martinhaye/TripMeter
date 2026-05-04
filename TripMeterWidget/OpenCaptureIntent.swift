import AppIntents

/// Opens the host app; main app consumes `WidgetSharedCaptureFlag` on activation.
struct OpenCaptureIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Capture"
    static var description = IntentDescription("Open Trip Meter to capture a thought.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        WidgetSharedCaptureFlag.setPending()
        return .result()
    }
}
