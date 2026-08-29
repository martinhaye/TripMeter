import Foundation
import SwiftData

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// Ephemeral pub (32) ‖ AES-GCM combined
    var encryptedPayload: Data
    /// Plaintext flag; thought text stays in `encryptedPayload`.
    var isContraband: Bool = false
    /// Set when the thought detail screen is actually shown (not the trip's thought list).
    var isReviewed: Bool = false
    var trip: Trip

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        encryptedPayload: Data,
        isContraband: Bool = false,
        isReviewed: Bool = false,
        trip: Trip
    ) {
        self.id = id
        self.createdAt = createdAt
        self.encryptedPayload = encryptedPayload
        self.isContraband = isContraband
        self.isReviewed = isReviewed
        self.trip = trip
    }
}
