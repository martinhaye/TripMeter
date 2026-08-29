import SwiftData
import SwiftUI
import UIKit

struct NoteDetailView: View {
    let trip: Trip
    let notes: [Note]
    @State private var selectedNoteID: PersistentIdentifier
    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isCurrentPageDirty = false
    @State private var saveCurrentPage: (() -> Bool)?
    @State private var showLeaveConfirm = false
    @State private var pendingReviewIDs: Set<PersistentIdentifier> = []
    @State private var reviewMarkWork: DispatchWorkItem?

    /// Long enough that the page swipe can finish before SwiftData observers rebuild.
    private static let reviewMarkDelay: TimeInterval = 0.45

    init(trip: Trip, note: Note) {
        self.trip = trip
        self.notes = TripNoteFilter.sortedNotes(in: trip)
        _selectedNoteID = State(initialValue: note.persistentModelID)
    }

    init(trip: Trip, notes: [Note], note: Note) {
        self.trip = trip
        self.notes = notes
        _selectedNoteID = State(initialValue: note.persistentModelID)
    }

    private var orderedNotes: [Note] {
        notes.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
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
                    NoteDetailPage(
                        note: note,
                        isActive: note.persistentModelID == selectedNoteID,
                        isDirty: $isCurrentPageDirty,
                        registerSaveHandler: { handler in
                            if note.persistentModelID == selectedNoteID {
                                saveCurrentPage = handler
                            }
                        },
                        onDelete: { dismiss() }
                    )
                    .tag(note.persistentModelID)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Thought")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    attemptDismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
        .onAppear {
            markCurrentAsReviewed()
        }
        .onChange(of: selectedNoteID) { _, _ in
            isCurrentPageDirty = false
            saveCurrentPage = nil
            // Defer the model write: saving `isReviewed` mid-swipe hitches the first page animation.
            scheduleMarkCurrentAsReviewed()
        }
        .onChange(of: trip.notes.count) { _, _ in
            if currentNote == nil, let first = orderedNotes.first {
                selectedNoteID = first.persistentModelID
            } else if orderedNotes.isEmpty {
                dismiss()
            }
        }
        .alert("You have unsaved changes", isPresented: $showLeaveConfirm) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Save") {
                if saveCurrentPage?() == true {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save before returning to the list of thoughts?")
        }
    }

    private func attemptDismiss() {
        if isCurrentPageDirty {
            showLeaveConfirm = true
        } else {
            dismiss()
        }
    }

    private func markCurrentAsReviewed() {
        guard let note = currentNote, !note.isReviewed else { return }
        commitReviews(ids: [note.persistentModelID], notes: orderedNotes, context: modelContext)
    }

    private func scheduleMarkCurrentAsReviewed() {
        guard let note = currentNote, !note.isReviewed else { return }
        pendingReviewIDs.insert(note.persistentModelID)
        reviewMarkWork?.cancel()
        let ids = pendingReviewIDs
        let snapshot = orderedNotes
        let context = modelContext
        let work = DispatchWorkItem {
            commitReviews(ids: ids, notes: snapshot, context: context)
        }
        reviewMarkWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.reviewMarkDelay, execute: work)
    }
}

private func commitReviews(
    ids: Set<PersistentIdentifier>,
    notes: [Note],
    context: ModelContext
) {
    guard !ids.isEmpty else { return }
    var changed = false
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
        for note in notes where ids.contains(note.persistentModelID) && !note.isReviewed {
            note.isReviewed = true
            changed = true
        }
    }
    guard changed else { return }
    do {
        try context.save()
    } catch {
        for note in notes where ids.contains(note.persistentModelID) {
            note.isReviewed = false
        }
    }
}

// MARK: - Single note page (swipe between these in TabView)

private struct NoteDetailPage: View {
    @Bindable var note: Note
    let isActive: Bool
    @Binding var isDirty: Bool
    let registerSaveHandler: (@escaping () -> Bool) -> Void
    let onDelete: () -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var modelContext

    @State private var text = ""
    @State private var originalText = ""
    @State private var source = "typed"
    @State private var loadError: String?
    @State private var saveError: String?
    @State private var showDeleteConfirm = false

    private var pageIsDirty: Bool {
        text != originalText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let loadError {
                Text(loadError).foregroundStyle(.red)
            }
            VerticallyLockedTextEditor(text: $text)
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

                Button {
                    _ = save()
                } label: {
                    Text("Save")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.unlockedPrivateKey == nil || !pageIsDirty)
            }

            Button {
                toggleContraband()
            } label: {
                Text(note.isContraband ? "Un-smuggle" : "Smuggle")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(session.unlockedPrivateKey == nil)
        }
        .padding()
        .onAppear(perform: load)
        .onChange(of: isActive) { _, active in
            if active {
                syncDirtyState()
                registerSaveHandler { save() }
            }
        }
        .onChange(of: text) { _, _ in
            if isActive {
                syncDirtyState()
            }
        }
        .onChange(of: session.isUnlocked) { _, isUnlocked in
            if !isUnlocked {
                text = ""
                originalText = ""
                source = "typed"
                if isActive {
                    isDirty = false
                }
            }
        }
        .alert("Delete this thought?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteNote()
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func syncDirtyState() {
        isDirty = pageIsDirty
    }

    private func load() {
        loadError = nil
        guard let key = session.unlockedPrivateKey else {
            loadError = "Session is locked."
            return
        }
        do {
            let payload = try NoteEncryptor.decrypt(blob: note.encryptedPayload, privateKey: key)
            session.noteTextCache.store(
                payload.text,
                for: note.id,
                payloadHash: note.encryptedPayload.hashValue
            )
            text = payload.text
            originalText = payload.text
            source = payload.source
            if isActive {
                syncDirtyState()
                registerSaveHandler { save() }
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func toggleContraband() {
        saveError = nil
        note.isContraband.toggle()
        do {
            try modelContext.save()
        } catch {
            note.isContraband.toggle()
            saveError = error.localizedDescription
        }
    }

    @discardableResult
    private func save() -> Bool {
        saveError = nil
        guard session.unlockedPrivateKey != nil else {
            saveError = "Session is locked."
            return false
        }
        do {
            let publicKey = try KeyManager.publicKeyForAgreement()
            let payload = NotePayload(text: text, editedAt: .now, source: source)
            let blob = try NoteEncryptor.encrypt(payload: payload, recipientPublic: publicKey)
            note.encryptedPayload = blob
            try modelContext.save()
            session.noteTextCache.store(text, for: note.id, payloadHash: blob.hashValue)
            originalText = text
            if isActive {
                isDirty = false
            }
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    private func deleteNote() {
        saveError = nil
        do {
            let noteID = note.id
            modelContext.delete(note)
            try modelContext.save()
            session.noteTextCache.invalidate(noteID: noteID)
            onDelete()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Text editor that leaves horizontal swipes to the page TabView

private struct VerticallyLockedTextEditor: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isDirectionalLockEnabled = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 5, bottom: 8, right: 5)
        textView.text = text
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}
