import SwiftData
import SwiftUI

struct RootCoordinatorView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSession.self) private var session

    @State private var needsOnboarding = false
    @State private var lockWorkItem: DispatchWorkItem?
    @State private var showBackupReminder = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                CaptureView()
            }
            .tabItem {
                Label("Capture", systemImage: "square.and.pencil")
            }
            .tag(0)

            NavigationStack {
                ReviewView()
            }
            .tabItem {
                Label("Review", systemImage: "lock.open")
            }
            .tag(1)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(2)
        }
        .onAppear {
            needsOnboarding = !KeyManager.hasKeys()
            evaluateBackupReminder()
            if SharedCaptureFlag.consumePending() {
                selectedTab = 0
                NotificationCenter.default.post(name: .tripMeterFocusCapture, object: nil)
            }
        }
        .onChange(of: session.isUnlocked) { _, _ in
            evaluateBackupReminder()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                scheduleBackgroundLock()
            case .active:
                cancelBackgroundLock()
                if SharedCaptureFlag.consumePending() {
                    selectedTab = 0
                    NotificationCenter.default.post(name: .tripMeterFocusCapture, object: nil)
                } else if selectedTab == 0 {
                    NotificationCenter.default.post(name: .tripMeterFocusCapture, object: nil)
                }
            default:
                break
            }
        }
        .fullScreenCover(isPresented: $needsOnboarding) {
            OnboardingView(onComplete: { needsOnboarding = false })
        }
        .onOpenURL { url in
            guard url.scheme == AppConstants.captureURLScheme, url.host == "capture" else { return }
            selectedTab = 0
            NotificationCenter.default.post(name: .tripMeterFocusCapture, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .tripMeterOpenCapture)) { notification in
            selectedTab = 0
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .tripMeterFocusCapture,
                    object: nil,
                    userInfo: notification.userInfo
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tripMeterDidUnlock)) { _ in
            selectedTab = 1
        }
        .overlay {
            if scenePhase != .active {
                Color(.systemBackground)
                    .ignoresSafeArea()
            }
        }
        .alert("Backup Reminder", isPresented: $showBackupReminder) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupReminderMessage)
        }
    }

    private func scheduleBackgroundLock() {
        lockWorkItem?.cancel()
        guard session.isUnlocked else { return }
        let seconds = UserSettings.backgroundLockSeconds
        let work = DispatchWorkItem {
            Task { @MainActor in
                session.lock()
            }
        }
        lockWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func cancelBackgroundLock() {
        lockWorkItem?.cancel()
        lockWorkItem = nil
    }

    private func evaluateBackupReminder() {
        guard session.shouldShowBackupReminder() else { return }
        session.markBackupReminderShown()
        showBackupReminder = true
    }

    private var backupReminderMessage: String {
        if let lastBackup = UserSettings.lastBackupAt {
            let f = DateFormatter()
            f.dateStyle = .medium
            return "Your last backup was \(f.string(from: lastBackup)). Consider creating a new backup in Settings > Data & Security."
        }
        return "No backup recorded yet. Create one in Settings > Data & Security."
    }
}
