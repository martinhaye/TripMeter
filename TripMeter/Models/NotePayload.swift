import Foundation

struct NotePayload: Codable, Equatable, Sendable {
    var text: String
    var editedAt: Date
    /// "typed" | "siri"
    var source: String

    init(text: String, editedAt: Date = .now, source: String = "typed") {
        self.text = text
        self.editedAt = editedAt
        self.source = source
    }
}
