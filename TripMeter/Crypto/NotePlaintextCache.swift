import Darwin
import Foundation

/// Session-scoped cache of decrypted note text. Bytes are zeroed on removal and lock.
@MainActor
final class NotePlaintextCache {
    private struct Entry {
        var utf8: [UInt8]
        var payloadHash: Int
    }

    private var entries: [UUID: Entry] = [:]

    /// Returns cached plaintext, or decrypts and caches it.
    func text(for note: Note, privateKey: SecureBytes) -> String? {
        let hash = note.encryptedPayload.hashValue
        if let entry = entries[note.id], entry.payloadHash == hash {
            return String(bytes: entry.utf8, encoding: .utf8)
        }

        guard let payload = try? NoteEncryptor.decrypt(blob: note.encryptedPayload, privateKey: privateKey)
        else { return nil }

        store(payload.text, for: note.id, payloadHash: hash)
        return payload.text
    }

    func invalidate(noteID: UUID) {
        guard var entry = entries.removeValue(forKey: noteID) else { return }
        zeroize(&entry.utf8)
    }

    func store(_ text: String, for noteID: UUID, payloadHash: Int) {
        invalidate(noteID: noteID)
        entries[noteID] = Entry(utf8: Array(text.utf8), payloadHash: payloadHash)
    }

    /// Zeroes all cached plaintext and empties the cache. Call on lock.
    func clear() {
        for id in Array(entries.keys) {
            invalidate(noteID: id)
        }
        entries.removeAll(keepingCapacity: false)
    }

    private func zeroize(_ bytes: inout [UInt8]) {
        bytes.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            _ = memset_s(base, raw.count, 0, raw.count)
        }
        bytes.removeAll(keepingCapacity: false)
    }
}
