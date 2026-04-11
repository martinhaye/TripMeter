# Trip Meter

Personal iPhone app for fast **encrypted** note capture organized by **trips** (local-first, single-user).

## Open in Xcode

1. Open `TripMeter.xcodeproj`.
2. Select the **TripMeter** target → **Signing & Capabilities**:
   - Choose your **Team**.
   - Add capability **App Groups** → `group.com.tripmeter.TripMeter` (must match `AppConstants.appGroupId` / widget entitlements).
   - Add capability **Siri** (for App Intents / “Add a note to Trip Meter”).
3. Build & run on a device or simulator (**iOS 18+**).

## Control Center / Lock Screen

1. Install the app once.
2. Edit **Control Center** (or Lock Screen controls) → add **Trip Meter Capture**.
3. Tap the control → app opens to capture; the text field is focused when the pending flag is consumed.

## Siri

After enabling Siri for the app (Shortcuts / Siri settings), try phrases like:

- “Add a note to Trip Meter”
- “Log note in Trip Meter”

Siri runs the **Add Trip Note** intent (you may need to confirm parameters in the Siri UI). For dictated text in one shot, build a **Shortcuts** shortcut that uses **Ask for Input** (or **Dictate Text**) and passes it into **Add Trip Note**—registered app-shortcut phrases cannot embed a freeform `String` parameter under current App Intents metadata rules.

## URL scheme

- `tripmeter://capture` — opens capture and focuses the note field.

## Security notes

- Note bodies are encrypted with a **Curve25519** public key; the private key is **PBKDF2-wrapped** (600k iterations) with your passphrase.
- Trip names and timestamps are **plaintext** by design so you can pick a trip without unlocking.
- Review sessions **auto-lock** after the delay in **Settings** when the app backgrounds.

## App icon

Add a 1024×1024 image under **Assets** → **AppIcon** before shipping to a device (optional for Simulator).
