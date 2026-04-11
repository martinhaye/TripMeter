import SwiftData
import SwiftUI

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(AppSession.self) private var session

    private var sortedNotes: [Note] {
        trip.notes.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            ForEach(sortedNotes, id: \.persistentModelID) { note in
                NavigationLink {
                    NoteDetailView(trip: trip, note: note)
                } label: {
                    NotePreviewLabel(note: note, key: session.unlockedPrivateKey)
                }
            }
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview (first ~3 lines)

private struct NotePreviewLabel: View {
    let note: Note
    var key: SecureBytes?

    private var decrypted: String? {
        guard let key,
              let payload = try? NoteEncryptor.decrypt(blob: note.encryptedPayload, privateKey: key)
        else { return nil }
        return payload.text
    }

    var body: some View {
        Group {
            if let text = decrypted {
                Text(text.isEmpty ? "(empty note)" : text)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Unable to preview")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
