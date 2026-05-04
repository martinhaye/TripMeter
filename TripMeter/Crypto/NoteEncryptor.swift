import CryptoKit
import Darwin
import Foundation

enum NoteEncryptorError: Error, LocalizedError {
    case missingPublicKey
    case encryptFailed
    case decryptFailed
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .missingPublicKey:
            return "Public key not available."
        case .encryptFailed:
            return "Encryption failed."
        case .decryptFailed:
            return "Decryption failed."
        case .invalidPayload:
            return "Invalid thought payload."
        }
    }
}

/// Hybrid ECIES-style encryption per note: ephemeral X25519 + HKDF + AES-GCM.
enum NoteEncryptor {
    private static let hkdfSalt = Data("TripMeterNote".utf8)

    static func encrypt(payload: NotePayload, recipientPublic: Curve25519.KeyAgreement.PublicKey) throws -> Data {
        let ephemeral = Curve25519.KeyAgreement.PrivateKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: recipientPublic)
        let symmetricKey = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: hkdfSalt,
            sharedInfo: Data(),
            outputByteCount: 32
        )
        let plain = try JSONEncoder().encode(payload)
        let sealed = try AES.GCM.seal(plain, using: symmetricKey)
        guard let combined = sealed.combined else {
            throw NoteEncryptorError.encryptFailed
        }
        return encode(
            ephemeralPublic: ephemeral.publicKey.rawRepresentation,
            combined: combined
        )
    }

    static func decrypt(blob: Data, privateKey: SecureBytes) throws -> NotePayload {
        let (ephemeralPub, combined) = try decode(blob)
        let recipientPrivate = try privateKey.withUnsafeBytes { raw in
            var rawData = Data(raw)
            defer {
                zeroize(&rawData)
            }
            return try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: rawData)
        }
        let ephemeralPublic = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: ephemeralPub)
        let shared = try recipientPrivate.sharedSecretFromKeyAgreement(with: ephemeralPublic)
        let symmetricKey = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: hkdfSalt,
            sharedInfo: Data(),
            outputByteCount: 32
        )
        let box = try AES.GCM.SealedBox(combined: combined)
        let plain = try AES.GCM.open(box, using: symmetricKey)
        return try JSONDecoder().decode(NotePayload.self, from: plain)
    }

    // ephemeral_pub (32) || AES-GCM combined (nonce + ciphertext + tag)
    private static func encode(ephemeralPublic: Data, combined: Data) -> Data {
        precondition(ephemeralPublic.count == 32)
        var out = Data()
        out.append(ephemeralPublic)
        out.append(combined)
        return out
    }

    private static func decode(_ data: Data) throws -> (Data, Data) {
        guard data.count > 32 + 12 + 16 else { throw NoteEncryptorError.invalidPayload }
        let ep = data.prefix(32)
        let rest = data.dropFirst(32)
        return (Data(ep), Data(rest))
    }

    private static func zeroize(_ data: inout Data) {
        data.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            _ = memset_s(base, raw.count, 0, raw.count)
        }
    }
}
