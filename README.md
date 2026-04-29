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
- Changing password re-wraps the same private key; notes are not re-encrypted.
- Passphrase entry uses an in-app telephone keypad (`1-9`, `*`, `0`, `#`) instead of the system keyboard.

## Unlocked utilities

When Review is unlocked, **Settings** includes a **Data & Security** section:

- **Change Password**: asks for current password, new password, confirmation, and a new optional hint, then re-wraps your private key.
- **Import from Reminders**: requests Reminders access, lets you pick a reminders list, and imports all items in chronological order.
- **Backup**: exports a versioned JSON backup file named `tripmeter-backup-YYYY-MM-DD.json`.
- **Restore**: validates backup format/version, asks for backup password, decrypts backup entries, and re-encrypts to your current key.
- **Delete All**: requires typing `DELETE` and permanently removes all trips and notes.
- **Backup Reminder**: after unlock, shows a reminder once per unlock session when no backup exists or the last backup is 30+ days old.

## Capture and unlock UX

- Capture includes persistent bottom controls for **Hide Keyboard** and **Unlock** (when locked), so unlock is always reachable.
- Successful unlock switches to the **Review** tab.

### Backup format (v1)

Backup JSON includes:

- `version` (currently `1`)
- `createdAt` (backup timestamp)
- current public key (base64)
- wrapped private key package JSON (base64)
- all trips + notes with encrypted payload bytes (base64)

Backups are intentionally unreadable without the backup password needed to unwrap the backed-up private key.

### Decode backup JSON with Python

If you want to inspect backup contents outside the app, use `scripts/decode_backup.py`.

The script includes inline dependency metadata, so `uv` can run it in one step.

1. Decode a backup file:
   - `uv run scripts/decode_backup.py /path/to/tripmeter-backup-YYYY-MM-DD.json --password "your-backup-password" --output decoded-backup.json`
2. Or just validate/decrypt and print counts:
   - `uv run scripts/decode_backup.py /path/to/tripmeter-backup-YYYY-MM-DD.json --password "your-backup-password" --summary-only`

Output format includes trips/notes and each decrypted note payload (`text`, `editedAt`, `source`).

## App icon

Add a 1024×1024 image under **Assets** → **AppIcon** before shipping to a device (optional for Simulator).
