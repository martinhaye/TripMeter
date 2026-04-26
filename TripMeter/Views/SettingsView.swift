import EventKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSession.self) private var session

    @State private var lockSeconds: Double = UserSettings.backgroundLockSeconds
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var isBusy = false

    @State private var showChangePassword = false
    @State private var showDeleteAll = false
    @State private var showRestorePasswordPrompt = false
    @State private var showReminderListPicker = false
    @State private var showBackupExporter = false
    @State private var showBackupImporter = false

    @State private var reminderCalendars: [EKCalendar] = []
    @State private var backupDocument: TripMeterBackupDocument?
    @State private var pendingRestoreEnvelope: BackupEnvelope?
    @State private var restorePassword = ""

    var body: some View {
        Form {
            Section {
                Text(
                    "After leaving the app, your review session locks automatically. Capture stays available without a passphrase."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Auto-lock (review)") {
                Picker("Delay after backgrounding", selection: $lockSeconds) {
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("2 minutes").tag(120.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                }
                .onChange(of: lockSeconds) { _, new in
                    UserSettings.backgroundLockSeconds = new
                }
            }

            if session.isUnlocked {
                Section("Data & Security") {
                    Button("Change Password") {
                        showChangePassword = true
                    }
                    .disabled(isBusy)

                    Button("Import from Reminders") {
                        Task { await chooseReminderList() }
                    }
                    .disabled(isBusy)

                    Button("Backup") {
                        Task { await prepareBackup() }
                    }
                    .disabled(isBusy)

                    Button("Restore") {
                        showBackupImporter = true
                    }
                    .disabled(isBusy)

                    Button("Delete All", role: .destructive) {
                        showDeleteAll = true
                    }
                    .disabled(isBusy)
                }
            }

            Section("About") {
                LabeledContent("App Group") {
                    Text(AppConstants.appGroupId).font(.caption2).textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            lockSeconds = UserSettings.backgroundLockSeconds
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet(
                isBusy: $isBusy,
                onDone: { infoMessage = $0 },
                onError: { errorMessage = $0 }
            )
        }
        .confirmationDialog(
            "Import which Reminders list?",
            isPresented: $showReminderListPicker,
            titleVisibility: .visible
        ) {
            ForEach(reminderCalendars, id: \.calendarIdentifier) { calendar in
                Button(calendar.title) {
                    Task { await importFromReminders(calendar: calendar) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showDeleteAll) {
            DeleteAllSheet(
                isBusy: $isBusy,
                onCancel: { showDeleteAll = false },
                onDelete: { Task { await deleteAllData() } }
            )
        }
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error.")
        }
        .alert("Done", isPresented: infoAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage ?? "")
        }
        .fileExporter(
            isPresented: $showBackupExporter,
            document: backupDocument,
            contentType: .json,
            defaultFilename: BackupEnvelope.defaultFilename
        ) { result in
            switch result {
            case .success:
                UserSettings.lastBackupAt = .now
                infoMessage = "Backup saved."
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportSelection(result)
        }
        .sheet(isPresented: $showRestorePasswordPrompt) {
            RestorePasswordSheet(
                password: $restorePassword,
                isBusy: $isBusy,
                onCancel: {
                    restorePassword = ""
                    pendingRestoreEnvelope = nil
                    showRestorePasswordPrompt = false
                },
                onRestore: {
                    Task { await performRestore() }
                }
            )
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var infoAlertBinding: Binding<Bool> {
        Binding(
            get: { infoMessage != nil },
            set: { if !$0 { infoMessage = nil } }
        )
    }

    @MainActor
    private func chooseReminderList() async {
        isBusy = true
        defer { isBusy = false }
        do {
            reminderCalendars = try await RemindersImportService.fetchAvailableLists()
            if reminderCalendars.isEmpty {
                infoMessage = "No reminders lists available."
                return
            }
            showReminderListPicker = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func importFromReminders(calendar: EKCalendar) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let imported = try await RemindersImportService.importAllReminders(from: calendar, context: modelContext)
            infoMessage = "Imported \(imported) reminders from \"\(calendar.title)\"."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func prepareBackup() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let envelope = try BackupService.buildBackup(context: modelContext)
            backupDocument = try TripMeterBackupDocument(envelope: envelope)
            showBackupExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                pendingRestoreEnvelope = try BackupService.loadEnvelope(from: url)
                restorePassword = ""
                showRestorePasswordPrompt = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func performRestore() async {
        guard let envelope = pendingRestoreEnvelope else {
            errorMessage = "No backup selected."
            return
        }
        guard !restorePassword.isEmpty else {
            errorMessage = "Enter the backup password."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let count = try BackupService.restore(
                envelope: envelope,
                backupPassword: restorePassword,
                context: modelContext
            )
            restorePassword = ""
            pendingRestoreEnvelope = nil
            showRestorePasswordPrompt = false
            infoMessage = "Restored \(count) notes into the current key."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteAllData() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let notes = try modelContext.fetch(FetchDescriptor<Note>())
            for note in notes { modelContext.delete(note) }
            let trips = try modelContext.fetch(FetchDescriptor<Trip>())
            for trip in trips { modelContext.delete(trip) }
            try modelContext.save()
            infoMessage = "All trips and notes deleted."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isBusy: Bool
    var onDone: (String) -> Void
    var onError: (String) -> Void

    @State private var oldPassphrase = ""
    @State private var newPassphrase = ""
    @State private var confirmPassphrase = ""
    @State private var newHint = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TelephonePasscodeEntry(
                        title: "Current password",
                        text: $oldPassphrase,
                        isBusy: isBusy
                    )
                    TelephonePasscodeEntry(
                        title: "New password",
                        text: $newPassphrase,
                        isBusy: isBusy
                    )
                    TelephonePasscodeEntry(
                        title: "Confirm new password",
                        text: $confirmPassphrase,
                        isBusy: isBusy
                    )
                }
                Section("Optional") {
                    TextField("New password hint", text: $newHint)
                }
            }
            .navigationTitle("Change Password")
            .onAppear {
                newHint = KeyManager.loadPassphraseHint() ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard newPassphrase == confirmPassphrase else {
                            onError("New passwords do not match.")
                            return
                        }
                        guard newPassphrase.count >= 8 else {
                            onError("Use at least 8 characters.")
                            return
                        }
                        isBusy = true
                        defer { isBusy = false }
                        do {
                            try KeyManager.changePassphrase(
                                currentPassphrase: oldPassphrase,
                                newPassphrase: newPassphrase
                            )
                            try KeyManager.savePassphraseHint(
                                newHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? nil
                                    : newHint.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            onDone("Password changed.")
                            dismiss()
                        } catch {
                            onError(error.localizedDescription)
                        }
                    }
                    .disabled(isBusy || oldPassphrase.isEmpty || newPassphrase.isEmpty || confirmPassphrase.isEmpty)
                }
            }
        }
    }
}

private struct RestorePasswordSheet: View {
    @Binding var password: String
    @Binding var isBusy: Bool
    var onCancel: () -> Void
    var onRestore: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TelephonePasscodeEntry(
                        title: "Backup password",
                        text: $password,
                        isBusy: isBusy
                    )
                }
            }
            .navigationTitle("Restore Backup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restore") { onRestore() }
                        .disabled(password.isEmpty || isBusy)
                }
            }
        }
    }
}

private struct DeleteAllSheet: View {
    @Binding var isBusy: Bool
    var onCancel: () -> Void
    var onDelete: () -> Void
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Type DELETE to confirm permanent deletion of all trips and notes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Type DELETE", text: $confirmation)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Delete All Data")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        onCancel()
                    }
                    .disabled(isBusy || confirmation != "DELETE")
                }
            }
        }
    }
}

private enum RemindersImportServiceError: LocalizedError {
    case permissionDenied
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Reminders permission was denied."
        case .fetchFailed:
            return "Could not fetch reminders."
        }
    }
}

private enum RemindersImportService {
    private static let store = EKEventStore()

    static func fetchAvailableLists() async throws -> [EKCalendar] {
        let granted = try await store.requestFullAccessToReminders()
        guard granted else {
            throw RemindersImportServiceError.permissionDenied
        }
        return store.calendars(for: .reminder).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    @MainActor
    static func importAllReminders(from calendar: EKCalendar, context: ModelContext) async throws -> Int {
        let reminders = try await fetchReminders(from: calendar)
            .sorted { lhs, rhs in
                let left = lhs.creationDate ?? lhs.lastModifiedDate ?? .distantPast
                let right = rhs.creationDate ?? rhs.lastModifiedDate ?? .distantPast
                if left == right {
                    let leftID = lhs.calendarItemIdentifier
                    let rightID = rhs.calendarItemIdentifier
                    return leftID.localizedCaseInsensitiveCompare(rightID) == .orderedAscending
                }
                return left < right
            }
        var imported = 0
        var previousCreatedAt: Date?
        for reminder in reminders {
            guard !reminder.isCompleted else { continue }
            let title = reminder.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let notes = reminder.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let text = sanitizeImportedText([title, notes].filter { !$0.isEmpty }.joined(separator: "\n\n"))
            guard !text.isEmpty, !isDashOnlyText(text) else { continue }
            let baseCreatedAt = reminder.creationDate ?? reminder.lastModifiedDate ?? .now
            let createdAt: Date
            if let previousCreatedAt, baseCreatedAt <= previousCreatedAt {
                createdAt = previousCreatedAt.addingTimeInterval(1)
            } else {
                createdAt = baseCreatedAt
            }
            try NoteCaptureService.saveNote(
                text: text,
                tripName: NoteCaptureService.todayTripName(referenceDate: createdAt),
                source: "reminders",
                createdAt: createdAt,
                editedAt: reminder.lastModifiedDate ?? createdAt,
                context: context
            )
            previousCreatedAt = createdAt
            imported += 1
        }
        return imported
    }

    private static func sanitizeImportedText(_ raw: String) -> String {
        var lines = raw.components(separatedBy: .newlines)
        while let first = lines.first, isDashOnlyLine(first) {
            lines.removeFirst()
        }
        while let last = lines.last, isDashOnlyLine(last) {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isDashOnlyLine(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.allSatisfy { $0 == "-" || $0 == "–" || $0 == "—" }
    }

    private static func isDashOnlyText(_ value: String) -> Bool {
        let lines = value
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return false }
        return lines.allSatisfy(isDashOnlyLine)
    }

    private static func fetchReminders(from calendar: EKCalendar) async throws -> [EKReminder] {
        let predicate = store.predicateForReminders(in: [calendar])
        return try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                guard let reminders else {
                    continuation.resume(throwing: RemindersImportServiceError.fetchFailed)
                    return
                }
                continuation.resume(returning: reminders)
            }
        }
    }
}

private enum BackupServiceError: LocalizedError {
    case unsupportedVersion(Int)
    case invalidKeyData

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported backup version \(version)."
        case .invalidKeyData:
            return "Backup key data is invalid."
        }
    }
}

private struct BackupEnvelope: Codable {
    static let version = 1

    var version: Int
    var createdAt: Date
    var publicKeyBase64: String
    var wrappedPrivateKeyJSONBase64: String
    var trips: [BackupTrip]

    static var defaultFilename: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return "tripmeter-backup-\(f.string(from: .now)).json"
    }
}

private struct BackupTrip: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var notes: [BackupNote]
}

private struct BackupNote: Codable {
    var id: UUID
    var createdAt: Date
    var encryptedPayloadBase64: String
}

private struct TripMeterBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(envelope: BackupEnvelope) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.data = try encoder.encode(envelope)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum BackupService {
    @MainActor
    static func buildBackup(context: ModelContext) throws -> BackupEnvelope {
        let trips = try context.fetch(FetchDescriptor<Trip>())
        let wrappedPrivateJSON = try KeyManager.exportWrappedPrivateKeyJSON()
        let publicKeyRaw = try KeyManager.exportPublicKeyRaw()

        let payloadTrips = trips.map { trip in
            BackupTrip(
                id: trip.id,
                name: trip.name,
                createdAt: trip.createdAt,
                notes: trip.notes.map { note in
                    BackupNote(
                        id: note.id,
                        createdAt: note.createdAt,
                        encryptedPayloadBase64: note.encryptedPayload.base64EncodedString()
                    )
                }
            )
        }
        return BackupEnvelope(
            version: BackupEnvelope.version,
            createdAt: .now,
            publicKeyBase64: publicKeyRaw.base64EncodedString(),
            wrappedPrivateKeyJSONBase64: wrappedPrivateJSON.base64EncodedString(),
            trips: payloadTrips
        )
    }

    static func loadEnvelope(from url: URL) throws -> BackupEnvelope {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(BackupEnvelope.self, from: data)
        guard envelope.version == BackupEnvelope.version else {
            throw BackupServiceError.unsupportedVersion(envelope.version)
        }
        return envelope
    }

    @MainActor
    static func restore(envelope: BackupEnvelope, backupPassword: String, context: ModelContext) throws -> Int {
        guard envelope.version == BackupEnvelope.version else {
            throw BackupServiceError.unsupportedVersion(envelope.version)
        }
        guard let wrappedJSON = Data(base64Encoded: envelope.wrappedPrivateKeyJSONBase64),
              let _ = Data(base64Encoded: envelope.publicKeyBase64)
        else {
            throw BackupServiceError.invalidKeyData
        }

        let backupPrivate = try KeyManager.unwrapPrivateKey(passphrase: backupPassword, wrappedJSON: wrappedJSON)
        let currentPublic = try KeyManager.publicKeyForAgreement()

        let existingTrips = try context.fetch(FetchDescriptor<Trip>())
        let existingTripIDs = Set(existingTrips.map(\.id))
        let existingNotes = try context.fetch(FetchDescriptor<Note>())
        let existingNoteIDs = Set(existingNotes.map(\.id))

        var usedTripIDs = existingTripIDs
        var usedNoteIDs = existingNoteIDs
        var restoredCount = 0

        for trip in envelope.trips {
            let tripID = uniqueID(preferred: trip.id, used: &usedTripIDs)
            let restoredTrip = Trip(id: tripID, name: trip.name, createdAt: trip.createdAt)
            context.insert(restoredTrip)

            for note in trip.notes {
                guard let oldBlob = Data(base64Encoded: note.encryptedPayloadBase64) else { continue }
                let payload = try NoteEncryptor.decrypt(blob: oldBlob, privateKey: backupPrivate)
                let newBlob = try NoteEncryptor.encrypt(payload: payload, recipientPublic: currentPublic)
                let noteID = uniqueID(preferred: note.id, used: &usedNoteIDs)
                context.insert(
                    Note(
                        id: noteID,
                        createdAt: note.createdAt,
                        encryptedPayload: newBlob,
                        trip: restoredTrip
                    )
                )
                restoredCount += 1
            }
        }
        try context.save()
        return restoredCount
    }

    private static func uniqueID(preferred: UUID, used: inout Set<UUID>) -> UUID {
        if !used.contains(preferred) {
            used.insert(preferred)
            return preferred
        }
        var value = UUID()
        while used.contains(value) {
            value = UUID()
        }
        used.insert(value)
        return value
    }
}
