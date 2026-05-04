import SwiftData
import SwiftUI

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

    private var todayName: String {
        NoteCaptureService.todayTripName()
    }

    private var canSave: Bool {
        !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $noteText)
                .focused($noteFocused)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.secondarySystemBackground))
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

                Button("Save") {
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
            if phase == .active {
                refreshRollingTripNameIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tripMeterFocusCapture)) { _ in
            noteFocused = true
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

    private func refreshRollingTripNameIfNeeded() {
        guard usesRollingCalendarDay else { return }
        let latest = NoteCaptureService.todayTripName()
        if selectedTripName != latest {
            selectedTripName = latest
        }
    }

    private func saveNote() {
        saveError = nil
        didSaveFlash = false
        do {
            try NoteCaptureService.saveNote(
                text: noteText,
                tripName: selectedTripName,
                source: "typed",
                context: modelContext
            )
            noteText = ""
            didSaveFlash = true
            DispatchQueue.main.async {
                noteFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                didSaveFlash = false
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
