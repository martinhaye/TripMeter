import CryptoKit
import Foundation
import SwiftData

enum NoteCaptureService {
    static func todayTripName(referenceDate: Date = .now) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f.string(from: referenceDate)
    }

    @MainActor
    static func fetchOrCreateTrip(named name: String, context: ModelContext) throws -> Trip {
        try fetchOrCreateTrip(named: name, createdAt: .now, context: context)
    }

    @MainActor
    static func fetchOrCreateTrip(named name: String, createdAt: Date, context: ModelContext) throws -> Trip {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? todayTripName() : trimmed
        var descriptor = FetchDescriptor<Trip>(
            predicate: #Predicate<Trip> { trip in trip.name == finalName }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let trip = Trip(name: finalName, createdAt: createdAt)
        context.insert(trip)
        return trip
    }

    @MainActor
    static func saveNote(
        text: String,
        tripName: String?,
        source: String,
        context: ModelContext
    ) throws {
        try saveNote(
            text: text,
            tripName: tripName,
            source: source,
            createdAt: .now,
            editedAt: .now,
            context: context
        )
    }

    @MainActor
    static func saveNote(
        text: String,
        tripName: String?,
        source: String,
        createdAt: Date,
        editedAt: Date,
        context: ModelContext
    ) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = tripName.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        let noteDate = createdAt
        let trip = try fetchOrCreateTrip(
            named: name ?? todayTripName(referenceDate: noteDate),
            createdAt: noteDate,
            context: context
        )
        let publicKey = try KeyManager.publicKeyForAgreement()
        let note = try makeEncryptedNote(
            text: trimmed,
            editedAt: editedAt,
            source: source,
            createdAt: noteDate,
            trip: trip,
            recipientPublic: publicKey
        )
        context.insert(note)
        try context.save()
    }

    static func makeEncryptedNote(
        text: String,
        editedAt: Date,
        source: String,
        createdAt: Date,
        trip: Trip,
        recipientPublic: Curve25519.KeyAgreement.PublicKey
    ) throws -> Note {
        let payload = NotePayload(text: text, editedAt: editedAt, source: source)
        let blob = try NoteEncryptor.encrypt(payload: payload, recipientPublic: recipientPublic)
        return Note(createdAt: createdAt, encryptedPayload: blob, trip: trip)
    }
}
