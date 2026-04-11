import Foundation
import SwiftData

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    /// Ephemeral pub (32) ‖ AES-GCM combined
    var encryptedPayload: Data
    var trip: Trip

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        encryptedPayload: Data,
        trip: Trip
    ) {
        self.id = id
        self.createdAt = createdAt
        self.encryptedPayload = encryptedPayload
        self.trip = trip
    }
}
