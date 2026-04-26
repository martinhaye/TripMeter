import SwiftUI

struct UnlockView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var passphrase = ""
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            Form {
                if let hint = KeyManager.loadPassphraseHint(), !hint.isEmpty {
                    Section {
                        Text("Hint: \(hint)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Passphrase") {
                    TelephonePasscodeEntry(
                        title: "Passphrase",
                        text: $passphrase,
                        isBusy: isBusy
                    )
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock") {
                        Task { await unlock() }
                    }
                    .disabled(passphrase.isEmpty || isBusy)
                }
            }
        }
    }

    @MainActor
    private func unlock() async {
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }

        let delay = session.unlockDelaySeconds
        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
        }

        do {
            try session.unlock(passphrase: passphrase)
            NotificationCenter.default.post(name: .tripMeterDidUnlock, object: nil)
            passphrase = ""
            dismiss()
        } catch {
            session.recordFailedUnlock()
            errorMessage = error.localizedDescription
        }
    }
}

struct TelephonePasscodeEntry: View {
    let title: String
    @Binding var text: String
    var isBusy: Bool = false

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Text(text.isEmpty ? "Tap keypad to enter" : String(repeating: "•", count: text.count))
                    .font(.title3.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(keys, id: \.self) { key in
                    Button(key) {
                        text.append(key)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isBusy)
                }
            }

            HStack(spacing: 10) {
                Button("Clear") {
                    text = ""
                }
                .buttonStyle(.bordered)
                .disabled(text.isEmpty || isBusy)

                Button("Delete") {
                    _ = text.popLast()
                }
                .buttonStyle(.bordered)
                .disabled(text.isEmpty || isBusy)
            }
        }
    }
}
