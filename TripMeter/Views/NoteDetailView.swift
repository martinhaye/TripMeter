import SwiftData
import SwiftUI

struct NoteDetailView: View {
    let trip: Trip
    @State private var selectedNoteID: PersistentIdentifier
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    init(trip: Trip, note: Note) {
        self.trip = trip
        _selectedNoteID = State(initialValue: note.persistentModelID)
    }

    private var orderedNotes: [Note] {
        trip.notes.sorted { $0.createdAt < $1.createdAt }
    }

    private var currentNote: Note? {
        orderedNotes.first { $0.persistentModelID == selectedNoteID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let n = currentNote {
                Text(n.createdAt.formatted(date: .long, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            TabView(selection: $selectedNoteID) {
                ForEach(orderedNotes, id: \.persistentModelID) { note in
                    NoteDetailPage(note: note)
                        .tag(note.persistentModelID)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: trip.notes.count) { _, _ in
            if currentNote == nil, let first = orderedNotes.first {
                selectedNoteID = first.persistentModelID
            } else if orderedNotes.isEmpty {
                dismiss()
            }
        }
    }
}

// MARK: - Single note page (swipe between these in TabView)

private struct NoteDetailPage: View {
    @Bindable var note: Note
    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var text = ""
    @State private var source = "typed"
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let loadError {
                Text(loadError).foregroundStyle(.red)
            }
            TextEditor(text: $text)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if let saveError {
                Text(saveError).foregroundStyle(.red).font(.caption)
            }
            HStack(spacing: 10) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text("Delete")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(session.unlockedPrivateKey == nil)

                Button(action: save) {
                    Text("Save")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.unlockedPrivateKey == nil)
            }
        }
        .padding()
        .onAppear(perform: load)
        .onChange(of: session.isUnlocked) { _, isUnlocked in
            if !isUnlocked {
                text = ""
                source = "typed"
            }
        }
        .alert("Delete this note?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func load() {
        loadError = nil
        guard let key = session.unlockedPrivateKey else {
            loadError = "Session is locked."
            return
        }
        do {
            let payload = try NoteEncryptor.decrypt(blob: note.encryptedPayload, privateKey: key)
            text = payload.text
            source = payload.source
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func save() {
        saveError = nil
        guard session.unlockedPrivateKey != nil else {
            saveError = "Session is locked."
            return
        }
        do {
            let publicKey = try KeyManager.publicKeyForAgreement()
            let payload = NotePayload(text: text, editedAt: .now, source: source)
            let blob = try NoteEncryptor.encrypt(payload: payload, recipientPublic: publicKey)
            note.encryptedPayload = blob
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func deleteNote() {
        saveError = nil
        do {
            modelContext.delete(note)
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
