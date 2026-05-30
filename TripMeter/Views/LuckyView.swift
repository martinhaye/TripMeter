import SwiftData
import SwiftUI

struct LuckyView: View {
    let notes: [Note]
    let privateKey: SecureBytes
    @Environment(\.dismiss) private var dismiss

    @State private var displayedText = ""
    @State private var showPickAnother = false
    @State private var showReturn = false
    @State private var lastPickedID: PersistentIdentifier?

    private var decryptedNotes: [(note: Note, text: String)] {
        notes.compactMap { note in
            guard let payload = try? NoteEncryptor.decrypt(blob: note.encryptedPayload, privateKey: privateKey),
                  !payload.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return (note, payload.text)
        }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if decryptedNotes.isEmpty {
                ContentUnavailableView(
                    "No thoughts to show",
                    systemImage: "sparkles",
                    description: Text("Capture some thoughts first.")
                )
            } else {
                ScrollView {
                    Text(displayedText)
                        .font(.system(.title2, design: .serif))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .padding(.horizontal, 28)
                        .padding(.top, 48)
                        .frame(maxWidth: .infinity)
                }

                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        if showPickAnother {
                            Button("Pick another") {
                                pickRandom()
                            }
                            .buttonStyle(.borderedProminent)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        if showReturn {
                            Button("Return to reality") {
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Lucky")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            pickRandom()
            scheduleButtonReveal()
        }
    }

    private func pickRandom() {
        let pool = decryptedNotes
        guard !pool.isEmpty else { return }

        var candidates = pool
        if pool.count > 1, let lastID = lastPickedID {
            candidates = pool.filter { $0.note.persistentModelID != lastID }
        }

        let pick = candidates.randomElement() ?? pool[0]
        lastPickedID = pick.note.persistentModelID

        withAnimation(.easeInOut(duration: 0.35)) {
            displayedText = pick.text
        }
    }

    private func scheduleButtonReveal() {
        showPickAnother = false
        showReturn = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeIn(duration: 0.5)) {
                showPickAnother = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeIn(duration: 0.5)) {
                showReturn = true
            }
        }
    }
}
