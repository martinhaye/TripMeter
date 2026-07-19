import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSession.self) private var session

    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var search = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceWork: DispatchWorkItem?
    @State private var showUnlock = false
    @State private var showLucky = false

    private var trimmedSearch: String {
        debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if session.isUnlocked {
                unlockedContent
            } else {
                lockedPlaceholder
            }
        }
        .navigationTitle("Review")
        .sheet(isPresented: $showUnlock) {
            UnlockView()
        }
    }

    private var lockedPlaceholder: some View {
        ContentUnavailableView(
            "Locked",
            systemImage: "lock.fill",
            description: Text("Unlock to browse trips and read encrypted thoughts.")
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Unlock") { showUnlock = true }
            }
        }
    }

    private var unlockedContent: some View {
        Group {
            if filteredTrips.isEmpty {
                ContentUnavailableView(
                    "No trips yet",
                    systemImage: "map",
                    description: Text(
                        trimmedSearch.isEmpty
                            ? "Capture thoughts to create trips."
                            : "No trips or thoughts match that search."
                    )
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total thoughts: \(totalVisibleNotes)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 4)

                    Button("Feeling Lucky Punk?") {
                        showLucky = true
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)

                    List {
                        ForEach(filteredTrips, id: \.id) { trip in
                            NavigationLink {
                                TripDetailView(
                                    trips: filteredTrips,
                                    trip: trip,
                                    searchQuery: trimmedSearch
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trip.name).font(.headline)
                                    Text("\(visibleNotes(in: trip).count) thoughts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Trip name or thought text")
        .onChange(of: search) { _, newValue in
            scheduleSearchUpdate(newValue)
        }
        .onChange(of: trips.count) { _, _ in
            rebuildSearchIndexIfNeeded()
        }
        .onDisappear {
            searchDebounceWork?.cancel()
        }
        .navigationDestination(isPresented: $showLucky) {
            LuckyView(notes: allVisibleNotes)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Lock") {
                    session.lock()
                }
            }
        }
    }

    private var filteredTrips: [Trip] {
        let q = trimmedSearch
        guard !q.isEmpty else { return trips }

        let lowered = q.lowercased()
        return trips.filter { trip in
            if trip.name.localizedCaseInsensitiveContains(q) { return true }
            return trip.notes.contains { note in
                session.noteSearchIndex.matches(noteID: note.id, lowercaseQuery: lowered)
            }
        }
    }

    private var totalVisibleNotes: Int {
        filteredTrips.reduce(into: 0) { total, trip in
            total += visibleNotes(in: trip).count
        }
    }

    private var allVisibleNotes: [Note] {
        filteredTrips.flatMap { visibleNotes(in: $0) }
    }

    /// Notes shown for a trip under the current search (all notes when idle; matches only while searching).
    private func visibleNotes(in trip: Trip) -> [Note] {
        TripNoteFilter.visibleNotes(
            in: trip,
            searchQuery: trimmedSearch,
            matchesText: { note in
                session.noteSearchIndex.matches(
                    noteID: note.id,
                    lowercaseQuery: trimmedSearch.lowercased()
                )
            }
        )
    }

    private func scheduleSearchUpdate(_ raw: String) {
        searchDebounceWork?.cancel()
        let work = DispatchWorkItem {
            applySearch(raw)
        }
        searchDebounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    private func applySearch(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            endSearchCaching()
            debouncedSearch = ""
            return
        }

        rebuildSearchIndex()
        debouncedSearch = q
    }

    private func rebuildSearchIndexIfNeeded() {
        guard !trimmedSearch.isEmpty else { return }
        rebuildSearchIndex()
    }

    private func rebuildSearchIndex() {
        session.noteSearchIndex.ensureBuilt(notes: trips.flatMap(\.notes)) { note in
            session.decryptedText(for: note)
        }
    }

    private func endSearchCaching() {
        session.noteSearchIndex.clear()
    }
}

enum TripNoteFilter {
    static func sortedNotes(in trip: Trip) -> [Note] {
        trip.notes.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    /// When `searchQuery` is empty, all notes. While searching, only notes whose text matches
    /// (trip-name matches still only list matching thoughts — possibly zero).
    static func visibleNotes(
        in trip: Trip,
        searchQuery: String,
        matchesText: (Note) -> Bool
    ) -> [Note] {
        let sorted = sortedNotes(in: trip)
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }

        return sorted.filter(matchesText)
    }
}
