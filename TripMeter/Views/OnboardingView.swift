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
                        "Trip Meter encrypts your thoughts on this device. Your passphrase wraps the private key. If you lose it, your thoughts cannot be recovered."
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
                    Text("Hint is stored unencrypted on-device. Do not include parts of your passphrase.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
        guard passphrase.count >= 10 else {
            errorMessage = "Use at least 10 characters."
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
