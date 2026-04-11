import SwiftData
import SwiftUI

@main
struct TripMeterApp: App {
    @State private var session = AppSession()

    init() {
        TripMeterShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootCoordinatorView()
                .environment(session)
        }
        .modelContainer(try! Persistence.makeContainer())
    }
}
