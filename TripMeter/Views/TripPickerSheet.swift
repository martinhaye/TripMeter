import SwiftData
import SwiftUI

struct TripPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTripName: String
    /// When true, the capture screen keeps `selectedTripName` aligned with the calendar day (see `CaptureView`).
    @Binding var usesRollingCalendarDay: Bool
    let todayName: String

    @State private var recentTrips: [Trip] = []
    @State private var newTripName = ""
    @State private var isCreatingNew = false

    var body: some View {
        NavigationStack {
            List {
                Section("Default") {
                    Button {
                        selectedTripName = todayName
                        usesRollingCalendarDay = true
                        dismiss()
                    } label: {
                        HStack {
                            Text("Today")
                            Spacer()
                            Text(todayName).foregroundStyle(.secondary)
                            if selectedTripName == todayName {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }

                if !recentTrips.isEmpty {
                    Section("Recent") {
                        ForEach(recentTrips, id: \.id) { trip in
                            Button {
                                selectedTripName = trip.name
                                usesRollingCalendarDay = false
                                dismiss()
                            } label: {
                                HStack {
                                    Text(trip.name)
                                    Spacer()
                                    if selectedTripName == trip.name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("New trip") {
                    if isCreatingNew {
                        TextField("Trip name", text: $newTripName)
                            .textInputAutocapitalization(.never)
                        Button("Use this name") {
                            let name = newTripName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            selectedTripName = name
                            usesRollingCalendarDay = false
                            dismiss()
                        }
                    } else {
                        Button("Create named trip…") {
                            isCreatingNew = true
                        }
                    }
                }
            }
            .navigationTitle("Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadRecent()
            }
        }
    }

    private func loadRecent() {
        var descriptor = FetchDescriptor<Trip>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 8
        recentTrips = (try? modelContext.fetch(descriptor)) ?? []
    }
}
