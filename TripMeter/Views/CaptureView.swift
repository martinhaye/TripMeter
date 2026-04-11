import SwiftData
import SwiftUI

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @FocusState private var noteFocused: Bool

    @State private var noteText = ""
    @State private var selectedTripName: String = NoteCaptureService.todayTripName()
    @State private var showTripPicker = false
    @State private var saveError: String?
    @State private var didSaveFlash = false

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
        .navigationTitle("Capture")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showTripPicker = true
                } label: {
                    Label(selectedTripName, systemImage: "map")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityHint("Choose trip for this note")

                Button("Save") {
                    saveNote()
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    noteFocused = false
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            if selectedTripName.isEmpty {
                selectedTripName = todayName
            }
            noteFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .tripMeterFocusCapture)) { _ in
            noteFocused = true
        }
        .sheet(isPresented: $showTripPicker) {
            TripPickerSheet(selectedTripName: $selectedTripName, todayName: todayName)
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
            noteFocused = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                didSaveFlash = false
            }
        } catch {
            saveError = error.localizedDescription
        }
    }
}
