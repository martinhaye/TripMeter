import SwiftUI

struct UnlockView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var passphrase = ""
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var unlockProgress: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
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
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage).foregroundStyle(.red)
                        }
                    }
                }
                .disabled(isBusy)

                if isBusy {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView(value: unlockProgress, total: 1.0)
                            .progressViewStyle(.linear)
                            .frame(width: 220)
                        Text("Decrypting key…")
                            .font(.headline)
                        Text("This may take a moment.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 12)
                }
            }
            .navigationTitle("Unlock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isBusy)
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
        unlockProgress = 0
        defer {
            isBusy = false
            unlockProgress = 0
        }

        let delay = session.unlockDelaySeconds
        if delay > 0 {
            try? await Task.sleep(for: .seconds(delay))
        }

        do {
            try await session.unlockAsync(passphrase: passphrase) { fraction in
                Task { @MainActor in
                    unlockProgress = fraction
                }
            }
            unlockProgress = 1.0
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
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    @State private var highlightedKey: String?
    @State private var highlightOpacity: Double = 0
    @State private var revealLastDigit = false
    @State private var revealTask: Task<Void, Never>?

    private var maskedDisplay: String {
        guard !text.isEmpty else { return "" }
        if revealLastDigit, let last = text.last {
            let maskedCount = max(0, text.count - 1)
            return String(repeating: "•", count: maskedCount) + String(last)
        }
        return String(repeating: "•", count: text.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Text(text.isEmpty ? "Tap keypad to enter" : maskedDisplay)
                    .font(.title3.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .animation(.easeOut(duration: 0.15), value: maskedDisplay)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(keys, id: \.self) { key in
                    Button {
                        appendKey(key)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemBackground))
                            if highlightedKey == key {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor.opacity(highlightOpacity))
                            }
                            Text(key)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                }
            }

            HStack(spacing: 10) {
                Button("Clear") {
                    text = ""
                    revealLastDigit = false
                    revealTask?.cancel()
                }
                .buttonStyle(.bordered)
                .disabled(text.isEmpty || isBusy)

                Button("Delete") {
                    _ = text.popLast()
                    revealLastDigit = false
                    revealTask?.cancel()
                }
                .buttonStyle(.bordered)
                .disabled(text.isEmpty || isBusy)
            }
        }
    }

    private func appendKey(_ key: String) {
        text.append(key)
        HapticFeedback.keyTap()
        flashKeyHighlight(key)
        flashLastDigit()
    }

    private func flashKeyHighlight(_ key: String) {
        highlightedKey = key
        highlightOpacity = 0.65
        withAnimation(.easeOut(duration: 0.4)) {
            highlightOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if highlightedKey == key {
                highlightedKey = nil
            }
        }
    }

    private func flashLastDigit() {
        revealLastDigit = true
        revealTask?.cancel()
        revealTask = Task {
            try? await Task.sleep(for: .milliseconds(750))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    revealLastDigit = false
                }
            }
        }
    }
}
