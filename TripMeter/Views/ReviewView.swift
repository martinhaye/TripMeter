import SwiftData
import SwiftUI

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSession.self) private var session

    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var search = ""
    @State private var showUnlock = false

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
            description: Text("Unlock to browse trips and read encrypted notes.")
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
                    description: Text("Capture notes to create trips.")
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total notes: \(totalVisibleNotes)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 4)

                    List {
                        ForEach(filteredTrips, id: \.id) { trip in
                            NavigationLink {
                                TripDetailView(trip: trip)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(trip.name).font(.headline)
                                    Text("\(trip.notes.count) notes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "Trip name or note text")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Lock") {
                    session.lock()
                }
            }
        }
    }

    private var filteredTrips: [Trip] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, let key = session.unlockedPrivateKey else {
            return trips
        }
        if q.isEmpty { return trips }

        return trips.filter { trip in
            if trip.name.localizedCaseInsensitiveContains(q) { return true }
            return trip.notes.contains { note in
                (try? NoteEncryptor.decrypt(blob: note.encryptedPayload, privateKey: key))?
                    .text.localizedCaseInsensitiveContains(q) ?? false
            }
        }
    }

    private var totalVisibleNotes: Int {
        filteredTrips.reduce(into: 0) { total, trip in
            total += trip.notes.count
        }
    }
}
