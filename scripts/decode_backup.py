#!/usr/bin/env python3
# Run with uv: uv run scripts/decode_backup.py /path/to/backup.json [--output decoded.json]
# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "cryptography",
# ]
# ///
"""
Decode Trip Meter backup JSON files into plaintext note payloads.

Run with uv (installs dependency automatically):
    uv run scripts/decode_backup.py ...
"""

from __future__ import annotations

import argparse
import base64
import getpass
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import x25519
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from cryptography.hazmat.primitives.kdf.hkdf import HKDF
    from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
except ModuleNotFoundError:
    print("error: missing dependency 'cryptography'.")
    print("Install it with: python3 -m pip install cryptography")
    raise SystemExit(2)


BACKUP_VERSION = 1
NOTE_HKDF_SALT = b"TripMeterNote"
PBKDF2_ITERATIONS = 600_000
AES_GCM_NONCE_LEN = 12
NOTE_EPHEMERAL_PUB_LEN = 32


class DecodeError(Exception):
    """Raised when the backup cannot be decoded."""


@dataclass
class WrappedPrivateKey:
    salt: bytes
    wrapped_private_key: bytes


def b64decode(value: str, label: str) -> bytes:
    try:
        return base64.b64decode(value, validate=True)
    except Exception as exc:  # noqa: BLE001
        raise DecodeError(f"Invalid base64 for {label}") from exc


def split_nonce_combined(combined: bytes, label: str) -> tuple[bytes, bytes]:
    if len(combined) <= AES_GCM_NONCE_LEN:
        raise DecodeError(f"{label} is too short to contain AES-GCM data")
    nonce = combined[:AES_GCM_NONCE_LEN]
    ciphertext_and_tag = combined[AES_GCM_NONCE_LEN:]
    return nonce, ciphertext_and_tag


def parse_wrapped_private(wrapped_private_key_json_b64: str) -> WrappedPrivateKey:
    wrapped_json_raw = b64decode(wrapped_private_key_json_b64, "wrappedPrivateKeyJSONBase64")
    try:
        wrapped_obj = json.loads(wrapped_json_raw.decode("utf-8"))
    except Exception as exc:  # noqa: BLE001
        raise DecodeError("wrappedPrivateKeyJSONBase64 does not contain valid JSON") from exc

    salt_b64 = wrapped_obj.get("salt")
    wrapped_key_b64 = wrapped_obj.get("wrappedPrivateKey")
    if not isinstance(salt_b64, str) or not isinstance(wrapped_key_b64, str):
        raise DecodeError("Wrapped private key JSON is missing required fields")

    return WrappedPrivateKey(
        salt=b64decode(salt_b64, "wrapped.salt"),
        wrapped_private_key=b64decode(wrapped_key_b64, "wrapped.wrappedPrivateKey"),
    )


def unwrap_private_key(passphrase: str, wrapped: WrappedPrivateKey) -> x25519.X25519PrivateKey:
    pbkdf2 = PBKDF2HMAC(
        algorithm=hashes.SHA256(),
        length=32,
        salt=wrapped.salt,
        iterations=PBKDF2_ITERATIONS,
    )
    wrapping_key = pbkdf2.derive(passphrase.encode("utf-8"))

    nonce, ciphertext_and_tag = split_nonce_combined(wrapped.wrapped_private_key, "wrappedPrivateKey")
    try:
        private_raw = AESGCM(wrapping_key).decrypt(nonce, ciphertext_and_tag, associated_data=None)
    except Exception as exc:  # noqa: BLE001
        raise DecodeError("Failed to unwrap private key. Check backup password.") from exc

    try:
        return x25519.X25519PrivateKey.from_private_bytes(private_raw)
    except Exception as exc:  # noqa: BLE001
        raise DecodeError("Unwrapped private key is invalid") from exc


def decrypt_note_blob(blob_b64: str, backup_private_key: x25519.X25519PrivateKey) -> dict[str, Any]:
    blob = b64decode(blob_b64, "note.encryptedPayloadBase64")
    if len(blob) <= NOTE_EPHEMERAL_PUB_LEN + AES_GCM_NONCE_LEN:
        raise DecodeError("Encrypted note payload is too short")

    ephemeral_pub_raw = blob[:NOTE_EPHEMERAL_PUB_LEN]
    combined = blob[NOTE_EPHEMERAL_PUB_LEN:]
    nonce, ciphertext_and_tag = split_nonce_combined(combined, "note payload")

    try:
        ephemeral_public = x25519.X25519PublicKey.from_public_bytes(ephemeral_pub_raw)
    except Exception as exc:  # noqa: BLE001
        raise DecodeError("Invalid ephemeral public key in note payload") from exc

    shared_secret = backup_private_key.exchange(ephemeral_public)
    symmetric_key = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=NOTE_HKDF_SALT,
        info=b"",
    ).derive(shared_secret)

    try:
        plaintext = AESGCM(symmetric_key).decrypt(nonce, ciphertext_and_tag, associated_data=None)
    except Exception as exc:  # noqa: BLE001
        raise DecodeError("Failed to decrypt note payload") from exc

    try:
        return json.loads(plaintext.decode("utf-8"))
    except Exception as exc:  # noqa: BLE001
        raise DecodeError("Decrypted note payload is not valid JSON") from exc


def decode_backup(backup_path: Path, backup_password: str) -> dict[str, Any]:
    try:
        backup = json.loads(backup_path.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        raise DecodeError(f"Unable to read backup JSON: {exc}") from exc

    if backup.get("version") != BACKUP_VERSION:
        raise DecodeError(f"Unsupported backup version: {backup.get('version')!r}")

    wrapped = parse_wrapped_private(str(backup.get("wrappedPrivateKeyJSONBase64", "")))
    backup_private_key = unwrap_private_key(backup_password, wrapped)
    backup_public_key_b64 = backup.get("publicKeyBase64")
    if not isinstance(backup_public_key_b64, str):
        raise DecodeError("Missing publicKeyBase64")
    _ = b64decode(backup_public_key_b64, "publicKeyBase64")

    decoded: dict[str, Any] = {
        "version": backup.get("version"),
        "createdAt": backup.get("createdAt"),
        "trips": [],
    }

    trips = backup.get("trips")
    if not isinstance(trips, list):
        raise DecodeError("Backup is missing trips array")

    for trip in trips:
        trip_out = {
            "id": trip.get("id"),
            "name": trip.get("name"),
            "createdAt": trip.get("createdAt"),
            "notes": [],
        }
        notes = trip.get("notes", [])
        if not isinstance(notes, list):
            raise DecodeError("Trip contains invalid notes array")

        for note in notes:
            payload = decrypt_note_blob(str(note.get("encryptedPayloadBase64", "")), backup_private_key)
            trip_out["notes"].append(
                {
                    "id": note.get("id"),
                    "createdAt": note.get("createdAt"),
                    "payload": payload,
                }
            )
        decoded["trips"].append(trip_out)

    return decoded


def write_output(decoded: dict[str, Any], output_path: Path | None) -> None:
    rendered = json.dumps(decoded, indent=2, sort_keys=True, ensure_ascii=True)
    if output_path is None:
        print(rendered)
        return
    output_path.write_text(rendered + "\n", encoding="utf-8")


def print_summary(decoded: dict[str, Any]) -> None:
    trip_count = len(decoded["trips"])
    note_count = sum(len(trip["notes"]) for trip in decoded["trips"])
    print(f"Decoded {trip_count} trips and {note_count} notes.", flush=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Decode Trip Meter backup JSON files.")
    parser.add_argument("backup_file", type=Path, help="Path to tripmeter-backup-*.json")
    parser.add_argument("--password", help="Backup password used when the backup was created")
    parser.add_argument(
        "--output",
        type=Path,
        help="Optional output path for decoded JSON; defaults to stdout",
    )
    parser.add_argument(
        "--summary-only",
        action="store_true",
        help="Only print trip/note counts (still validates full decryption)",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    password = args.password
    if not password:
        password = getpass.getpass("Backup password: ")
    if not password:
        print("error: password cannot be empty")
        return 2

    try:
        decoded = decode_backup(args.backup_file, password)
        if args.summary_only:
            print_summary(decoded)
        else:
            write_output(decoded, args.output)
            if args.output is not None:
                print_summary(decoded)
        return 0
    except DecodeError as exc:
        print(f"error: {exc}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
