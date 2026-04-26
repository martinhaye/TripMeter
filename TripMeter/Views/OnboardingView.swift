import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var passphrase = ""
    @State private var confirm = ""
    @State private var hint = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        "Trip Meter encrypts your notes on this device. Your passphrase wraps the private key. If you lose it, your notes cannot be recovered."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("Passphrase") {
                    TelephonePasscodeEntry(
                        title: "Passphrase",
                        text: $passphrase,
                        isBusy: isSaving
                    )
                    TelephonePasscodeEntry(
                        title: "Confirm passphrase",
                        text: $confirm,
                        isBusy: isSaving
                    )
                }

                Section("Optional") {
                    TextField("Passphrase hint (stored on device)", text: $hint)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Set Up")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Keys") {
                        Task { await createKeys() }
                    }
                    .disabled(passphrase.isEmpty || passphrase != confirm || isSaving)
                }
            }
            .interactiveDismissDisabled()
        }
    }

    @MainActor
    private func createKeys() async {
        errorMessage = nil
        guard passphrase == confirm else {
            errorMessage = "Passphrases do not match."
            return
        }
        guard passphrase.count >= 8 else {
            errorMessage = "Use at least 8 characters."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try KeyManager.createKeys(passphrase: passphrase)
            try KeyManager.savePassphraseHint(hint.isEmpty ? nil : hint)
            passphrase = ""
            confirm = ""
            hint = ""
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
