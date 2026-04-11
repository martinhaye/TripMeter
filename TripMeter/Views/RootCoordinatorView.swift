import SwiftData
import SwiftUI

struct RootCoordinatorView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSession.self) private var session

    @State private var needsOnboarding = false
    @State private var lockWorkItem: DispatchWorkItem?

    var body: some View {
        TabView {
            NavigationStack {
                CaptureView()
            }
            .tabItem {
                Label("Capture", systemImage: "square.and.pencil")
            }

            NavigationStack {
                ReviewView()
            }
            .tabItem {
                Label("Review", systemImage: "lock.open")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .onAppear {
            needsOnboarding = !KeyManager.hasKeys()
            if SharedCaptureFlag.consumePending() {
                NotificationCenter.default.post(name: .tripMeterFocusCapture, object: nil)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                scheduleBackgroundLock()
            case .active:
                cancelBackgroundLock()
                if SharedCaptureFlag.consumePending() {
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
            NotificationCenter.default.post(name: .tripMeterFocusCapture, object: nil)
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
}
