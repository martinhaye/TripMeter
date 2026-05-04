import AppIntents

struct TripMeterShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .navy

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddNoteIntent(),
            phrases: [
                "Add a thought to \(.applicationName)",
                "Log thought in \(.applicationName)",
            ],
            shortTitle: "Add Trip Thought",
            systemImageName: "note.text.badge.plus"
        )
    }
}
