import SwiftData
import SwiftUI

struct LuckyView: View {
    let notes: [Note]
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var displayedText = ""
    @State private var showPickAnother = false
    @State private var showReturn = false
    @State private var lastPickedID: PersistentIdentifier?
    @State private var pickAnotherRevealWork: DispatchWorkItem?
    @State private var returnRevealWork: DispatchWorkItem?

    private var decryptedNotes: [(note: Note, text: String)] {
        notes.compactMap { note in
            guard let text = session.decryptedText(for: note),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return (note, text)
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
                                pickAnother()
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
        .onDisappear {
            cancelButtonReveal()
            displayedText = ""
        }
    }

    private func pickAnother() {
        withAnimation(.easeOut(duration: 0.15)) {
            showPickAnother = false
            showReturn = false
        }
        pickRandom()
        scheduleButtonReveal()
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

    private func cancelButtonReveal() {
        pickAnotherRevealWork?.cancel()
        returnRevealWork?.cancel()
        pickAnotherRevealWork = nil
        returnRevealWork = nil
    }

    private func scheduleButtonReveal() {
        cancelButtonReveal()
        showPickAnother = false
        showReturn = false

        let pickWork = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.5)) {
                showPickAnother = true
            }
        }
        let returnWork = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.5)) {
                showReturn = true
            }
        }
        pickAnotherRevealWork = pickWork
        returnRevealWork = returnWork

        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: pickWork)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: returnWork)
    }
}
