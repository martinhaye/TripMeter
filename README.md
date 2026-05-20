# Trip Meter

Personal iPhone app for fast **encrypted** thought capture organized by **trips** (local-first, single-user).

## Open in Xcode

1. Open `TripMeter.xcodeproj`.
2. Select the **TripMeter** target → **Signing & Capabilities**:
   - Choose your **Team**.
   - Add capability **App Groups** → `group.com.tripmeter.TripMeter` (must match `AppConstants.appGroupId` / widget entitlements).
   - Add capability **Siri** (for App Intents / “Add a thought to Trip Meter”).
3. Build & run on a device or simulator (**iOS 18+**).

## Control Center / Lock Screen

1. Install the app once.
2. Edit **Control Center** (or Lock Screen controls) → add **Trip Meter Capture**.
3. Tap the control → app switches to capture and focuses the text field (via the pending flag and capture tab selection).

## Siri

After enabling Siri for the app (Shortcuts / Siri settings), try phrases like:

- “Add a thought to Trip Meter”
- “Log thought in Trip Meter”

Siri runs the **Add Trip Thought** intent (you may need to confirm parameters in the Siri UI). For dictated text in one shot, build a **Shortcuts** shortcut that uses **Ask for Input** (or **Dictate Text**) and passes it into **Add Trip Thought**—registered app-shortcut phrases cannot embed a freeform `String` parameter under current App Intents metadata rules.

## URL scheme

- `tripmeter://capture` — opens the Capture tab, focuses the thought field.

## Security notes

- Thought bodies are encrypted with a **Curve25519** public key; the private key is **PBKDF2-wrapped** (600k iterations) with your passphrase.
- Trip names and timestamps are **plaintext** by design so you can pick a trip without unlocking.
- Review sessions **auto-lock** after the delay in **Settings** when the app backgrounds.
- Changing password re-wraps the same private key; stored ciphertext is not re-encrypted.
- Passphrase entry uses an in-app telephone keypad (`1-9`, `*`, `0`, `#`) instead of the system keyboard.

## Unlocked utilities

When Review is unlocked, **Settings** includes a **Data & Security** section:

- **Change Password**: asks for current password, new password, confirmation, and a new optional hint, then re-wraps your private key.
- **Import from Reminders**: requests Reminders access, lets you pick a reminders list, and imports all items in chronological order.
- **Backup**: exports a versioned JSON backup file named `tripmeter-backup-YYYY-MM-DD.json`.
- **Restore**: validates backup format/version, asks for backup password, decrypts backup entries, and re-encrypts to your current key.
- **Delete All**: requires typing `DELETE` and permanently removes all trips and thoughts.
- **Backup Reminder**: after unlock, shows a reminder once per unlock session when no backup exists or the last backup is 30+ days old.

## Capture and unlock UX

- The capture screen navigation title is **TripMeter**. The tab label remains **Capture**.
- The editor refocuses when the app becomes active on the Capture tab, when opening from the widget/URL/pending flag (which also selects the Capture tab), and after a successful save so you can keep typing without an extra tap.
- Capture auto-saves entered text after **2 minutes** without typing, or when the device is **locked**—whichever comes first—using the same save path as the **Save** button. While the app is inactive or in the background, the capture editor is obscured so lock-screen snapshots and unlock transitions never flash draft text.
- Capture includes persistent bottom controls for **Hide Keyboard** and **Unlock** (when locked), so unlock is always reachable.
- Successful unlock switches to the **Review** tab.

In **Review**, each thought in a trip’s list shows a short preview (a few lines). Newlines in the stored text are replaced by ` / ` so more segments fit in the preview. A trip’s detail screen has an **Add** button that opens **Capture** with that trip selected. Swipe left or right on a trip’s thought list to move between trips (within the current search results), and swipe left or right on a thought to move between thoughts in that trip.

In a thought detail screen, **Save** is enabled only when the text has changed. After a successful save, it becomes disabled again until you edit more. If you go back to the thoughts list with unsaved edits, the app prompts you to choose **Discard** or **Save**.

### Backup format (v1)

Backup JSON includes:

- `version` (currently `1`)
- `createdAt` (backup timestamp)
- current public key (base64)
- wrapped private key package JSON (base64)
- all trips + per-trip thought records with encrypted payload bytes (base64)

Backups are intentionally unreadable without the backup password needed to unwrap the backed-up private key.

### Decode backup JSON with Python

If you want to inspect backup contents outside the app, use `scripts/decode_backup.py`.

The script includes inline dependency metadata, so `uv` can run it in one step.

1. Decode a backup file:
   - `uv run scripts/decode_backup.py /path/to/tripmeter-backup-YYYY-MM-DD.json --password "your-backup-password" --output decoded-backup.json`
2. Or just validate/decrypt and print counts:
   - `uv run scripts/decode_backup.py /path/to/tripmeter-backup-YYYY-MM-DD.json --password "your-backup-password" --summary-only`

Output format includes trips and decrypted thought payloads (`text`, `editedAt`, `source`). JSON keys still use `notes` for backward compatibility with existing backups.

## App icon

Add a 1024×1024 image under **Assets** → **AppIcon** before shipping to a device (optional for Simulator).
