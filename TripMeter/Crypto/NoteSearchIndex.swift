import Darwin
import Foundation

/// Ephemeral lowercase plaintext index for Review search.
/// Built when search becomes active; zeroed when search ends or the session locks.
@MainActor
final class NoteSearchIndex {
    private struct Entry {
        var utf8: [UInt8]
    }

    private var entries: [UUID: Entry] = [:]
    private(set) var isBuilt = false

    /// Ensures every note has a lowercase searchable entry (decrypts via `textFor` as needed).
    func ensureBuilt(notes: [Note], textFor: (Note) -> String?) {
        var seen = Set<UUID>()
        for note in notes {
            seen.insert(note.id)
            if entries[note.id] != nil { continue }
            guard let text = textFor(note) else { continue }
            store(text.lowercased(), for: note.id)
        }

        // Drop entries for notes that no longer exist.
        for id in entries.keys where !seen.contains(id) {
            invalidate(noteID: id)
        }
        isBuilt = true
    }

    func matches(noteID: UUID, lowercaseQuery: String) -> Bool {
        guard !lowercaseQuery.isEmpty,
              let entry = entries[noteID]
        else { return false }
        return String(bytes: entry.utf8, encoding: .utf8)?.contains(lowercaseQuery) ?? false
    }

    /// Zeroes all indexed plaintext and empties the index.
    func clear() {
        for id in Array(entries.keys) {
            invalidate(noteID: id)
        }
        entries.removeAll(keepingCapacity: false)
        isBuilt = false
    }

    private func store(_ lowercaseText: String, for noteID: UUID) {
        invalidate(noteID: noteID)
        entries[noteID] = Entry(utf8: Array(lowercaseText.utf8))
    }

    private func invalidate(noteID: UUID) {
        guard var entry = entries.removeValue(forKey: noteID) else { return }
        zeroize(&entry.utf8)
    }

    private func zeroize(_ bytes: inout [UInt8]) {
        bytes.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            _ = memset_s(base, raw.count, 0, raw.count)
        }
        bytes.removeAll(keepingCapacity: false)
    }
}
