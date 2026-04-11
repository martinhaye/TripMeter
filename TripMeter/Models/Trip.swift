import Foundation
import SwiftData

@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Note.trip)
    var notes: [Note]

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, notes: [Note] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.notes = notes
    }
}
