import SwiftData
import SwiftUI
import UIKit

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var noteFocused: Bool

    @State private var noteText = ""
    @State private var selectedTripName: String = NoteCaptureService.todayTripName()
    /// When true, trip name follows the local calendar day (avoids stale `yyyy-MM-dd` after midnight while this tab stays alive).
    @State private var usesRollingCalendarDay = true
    @State private var showTripPicker = false
    @State private var saveError: String?
    @State private var didSaveFlash = false
    @State private var showUnlock = false
    @State private var idleAutoSaveWorkItem: DispatchWorkItem?
    /// Forces TextEditor recreation so cached glyphs cannot flash after lock/unlock.
    @State private var editorIdentity = UUID()

    private static let autoSaveIdleInterval: TimeInterval = 120

    private var isCaptureVisible: Bool {
        scenePhase == .active
    }

    private var todayName: String {
        NoteCaptureService.todayTripName()
    }

    private var canSave: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))

                TextEditor(text: $noteText)
                    .focused($noteFocused)
                    .id(editorIdentity)
                    .padding(8)
                    .opacity(isCaptureVisible ? 1 : 0)

                if !isCaptureVisible {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                }
            }
            .frame(minHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if didSaveFlash {
                Text("Saved (encrypted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let saveError {
                Text(saveError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("TripMeter")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showTripPicker = true
                } label: {
                    Label(selectedTripName, systemImage: "map")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityHint("Choose trip for this thought")

                Button("Another") {
                    saveNote()
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .onAppear {
            refreshRollingTripNameIfNeeded()
            if selectedTripName.isEmpty {
                selectedTripName = todayName
            }
            DispatchQueue.main.async {
                noteFocused = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                refreshRollingTripNameIfNeeded()
            case .inactive:
                noteFocused = false
            default:
                break
            }
        }
        .onChange(of: noteText) { _, _ in
            rescheduleIdleAutoSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
            autoSaveOnDeviceLock()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tripMeterFocusCapture)) { notification in
            applyCaptureFocus(from: notification)
        }
        .onDisappear {
            cancelIdleAutoSave()
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                if !session.isUnlocked {
                    Button {
                        showUnlock = true
                    } label: {
                        Label("Unlock", systemImage: "lock.open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    noteFocused = false
                } label: {
                    Label("Hide Keyboard", systemImage: "keyboard.chevron.compact.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!noteFocused)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showTripPicker) {
            TripPickerSheet(
                selectedTripName: $selectedTripName,
                usesRollingCalendarDay: $usesRollingCalendarDay,
                todayName: todayName
            )
        }
        .sheet(isPresented: $showUnlock) {
            UnlockView()
        }
    }

    private func applyCaptureFocus(from notification: Notification) {
        if let tripName = notification.userInfo?[AppConstants.captureTripNameUserInfoKey] as? String,
           !tripName.isEmpty {
            selectedTripName = tripName
            usesRollingCalendarDay = false
        }
        DispatchQueue.main.async {
            noteFocused = true
        }
    }

    private func refreshRollingTripNameIfNeeded() {
        guard usesRollingCalendarDay else { return }
        let latest = NoteCaptureService.todayTripName()
        if selectedTripName != latest {
            selectedTripName = latest
        }
    }

    private func rescheduleIdleAutoSave() {
        idleAutoSaveWorkItem?.cancel()
        guard canSave else { return }
        let work = DispatchWorkItem {
            autoSaveIfNeeded()
        }
        idleAutoSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoSaveIdleInterval, execute: work)
    }

    private func cancelIdleAutoSave() {
        idleAutoSaveWorkItem?.cancel()
        idleAutoSaveWorkItem = nil
    }

    private func autoSaveIfNeeded() {
        guard canSave else { return }
        saveNote()
    }

    private func autoSaveOnDeviceLock() {
        let textToSave = noteText
        clearCaptureEditor()
        guard !textToSave.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        performSave(text: textToSave, showConfirmation: false)
    }

    private func clearCaptureEditor() {
        noteText = ""
        editorIdentity = UUID()
        cancelIdleAutoSave()
    }

    private func saveNote() {
        performSave(text: noteText, showConfirmation: true)
    }

    private func performSave(text: String, showConfirmation: Bool) {
        saveError = nil
        didSaveFlash = false
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if showConfirmation {
            clearCaptureEditor()
        }

        do {
            try NoteCaptureService.saveNote(
                text: trimmed,
                tripName: selectedTripName,
                source: "typed",
                context: modelContext
            )
            HapticFeedback.savePulse()
            if showConfirmation {
                didSaveFlash = true
                DispatchQueue.main.async {
                    noteFocused = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    didSaveFlash = false
                }
            }
        } catch {
            saveError = error.localizedDescription
            if showConfirmation {
                noteText = text
                editorIdentity = UUID()
            }
        }
    }
}
