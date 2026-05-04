import SwiftData
import SwiftUI

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(AppSession.self) private var session

    private var sortedNotes: [Note] {
        trip.notes.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
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

    /// Collapses newlines so `lineLimit` shows more distinct segments in the preview.
    private func previewDisplayText(_ raw: String) -> String {
        raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    var body: some View {
        Group {
            if let text = decrypted {
                let shown = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "(empty thought)"
                    : previewDisplayText(text)
                Text(shown)
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
