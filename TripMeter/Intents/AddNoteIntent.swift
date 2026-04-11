import AppIntents
import SwiftData

struct AddNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Trip Note"
    static var description = IntentDescription("Save an encrypted note in Trip Meter.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Note text")
    var text: String

    @Parameter(title: "Trip name", default: "")
    var tripName: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmedName = tripName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameArg: String? = trimmedName.isEmpty ? nil : trimmedName
        let container = try Persistence.makeContainer()
        let context = ModelContext(container)
        try NoteCaptureService.saveNote(
            text: text,
            tripName: nameArg,
            source: "siri",
            context: context
        )
        return .result(dialog: "Note saved encrypted.")
    }
}
