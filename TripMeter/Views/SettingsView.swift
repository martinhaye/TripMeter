import SwiftUI

struct SettingsView: View {
    @State private var lockSeconds: Double = UserSettings.backgroundLockSeconds

    var body: some View {
        Form {
            Section {
                Text(
                    "After leaving the app, your review session locks automatically. Capture stays available without a passphrase."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Auto-lock (review)") {
                Picker("Delay after backgrounding", selection: $lockSeconds) {
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("2 minutes").tag(120.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                }
                .onChange(of: lockSeconds) { _, new in
                    UserSettings.backgroundLockSeconds = new
                }
            }

            Section("About") {
                LabeledContent("App Group") {
                    Text(AppConstants.appGroupId).font(.caption2).textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            lockSeconds = UserSettings.backgroundLockSeconds
        }
    }
}
