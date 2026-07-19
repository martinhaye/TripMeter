import SwiftData
import SwiftUI

struct TripDetailView: View {
    let trips: [Trip]
    let searchQuery: String
    @State private var selectedTripID: PersistentIdentifier

    init(trips: [Trip], trip: Trip, searchQuery: String = "") {
        self.trips = trips
        self.searchQuery = searchQuery
        _selectedTripID = State(initialValue: trip.persistentModelID)
    }

    private var currentTrip: Trip? {
        trips.first { $0.persistentModelID == selectedTripID }
    }

    var body: some View {
        TabView(selection: $selectedTripID) {
            ForEach(trips, id: \.persistentModelID) { trip in
                TripNotesList(trip: trip, searchQuery: searchQuery)
                    .tag(trip.persistentModelID)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(currentTrip?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    guard let tripName = currentTrip?.name else { return }
                    NotificationCenter.default.post(
                        name: .tripMeterOpenCapture,
                        object: nil,
                        userInfo: [AppConstants.captureTripNameUserInfoKey: tripName]
                    )
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .accessibilityHint("Add a thought to this trip")
            }
        }
        .onChange(of: trips.map(\.persistentModelID)) { _, ids in
            guard !ids.contains(selectedTripID) else { return }
            selectedTripID = ids.first ?? selectedTripID
        }
    }
}

// MARK: - Thought list for one trip

private struct TripNotesList: View {
    @Bindable var trip: Trip
    let searchQuery: String
    @Environment(AppSession.self) private var session

    private var sortedNotes: [Note] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return TripNoteFilter.visibleNotes(in: trip, searchQuery: searchQuery) { note in
            session.decryptedText(for: note)?.localizedCaseInsensitiveContains(q) ?? false
        }
    }

    var body: some View {
        List {
            ForEach(sortedNotes, id: \.persistentModelID) { note in
                NavigationLink {
                    NoteDetailView(trip: trip, notes: sortedNotes, note: note)
                } label: {
                    NotePreviewLabel(note: note)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Preview (first ~3 lines)

private struct NotePreviewLabel: View {
    let note: Note
    @Environment(AppSession.self) private var session

    private var decrypted: String? {
        session.decryptedText(for: note)
    }

    /// Collapses newlines so `lineLimit` shows more distinct segments in the preview.
    private func previewDisplayText(_ raw: String) -> String {
        raw
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
    }

    var body: some View {
        Group {
            if let text = decrypted {
                let shown = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "(empty thought)"
                    : previewDisplayText(text)
                Text(shown)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Unable to preview")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
