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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? todayTripName() : trimmed
        var descriptor = FetchDescriptor<Trip>(
            predicate: #Predicate<Trip> { trip in trip.name == finalName }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let trip = Trip(name: finalName)
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let name = tripName.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        let trip = try fetchOrCreateTrip(named: name ?? todayTripName(), context: context)
        let publicKey = try KeyManager.publicKeyForAgreement()
        let payload = NotePayload(text: trimmed, source: source)
        let blob = try NoteEncryptor.encrypt(payload: payload, recipientPublic: publicKey)
        let note = Note(encryptedPayload: blob, trip: trip)
        context.insert(note)
        try context.save()
    }
}
