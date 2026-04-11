import AppIntents
import SwiftUI
import WidgetKit

struct CaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.tripmeter.capture") {
            ControlWidgetButton(action: OpenCaptureIntent()) {
                Label("Add Note", systemImage: "note.text.badge.plus")
            }
        }
        .displayName("Trip Meter Capture")
        .description("Open encrypted note capture.")
    }
}
