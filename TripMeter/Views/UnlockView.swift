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
                    SecureField("Passphrase", text: $passphrase)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
            passphrase = ""
            dismiss()
        } catch {
            session.recordFailedUnlock()
            errorMessage = error.localizedDescription
        }
    }
}
