import AppIntents

struct TripMeterShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .navy

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddNoteIntent(),
            phrases: [
                "Add a note to \(.applicationName)",
                "Log note in \(.applicationName)",
            ],
            shortTitle: "Add Trip Note",
            systemImageName: "note.text.badge.plus"
        )
    }
}
