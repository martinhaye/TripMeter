import CryptoKit
import Darwin
import Foundation
import Security

enum KeyManagerError: Error, LocalizedError {
    case keychainFailure(OSStatus)
    case invalidWrappedPayload
    case decryptionFailed
    case notConfigured
    case invalidPassphrase

    var errorDescription: String? {
        switch self {
        case .keychainFailure(let status):
            return "Keychain error: \(status)"
        case .invalidWrappedPayload:
            return "Invalid wrapped key data."
        case .decryptionFailed:
            return "Could not decrypt private key (wrong passphrase?)."
        case .notConfigured:
            return "Encryption is not set up yet."
        case .invalidPassphrase:
            return "Current passphrase is incorrect."
        }
    }
}

/// Manages Curve25519 keypair: public key always available; private key passphrase-wrapped only.
enum KeyManager {
    private static let publicKeyTag = "com.tripmeter.key.public"
    private static let wrappedPrivateTag = "com.tripmeter.key.wrappedPrivate"
    private static let hintTag = "com.tripmeter.passphrase.hint"

    private static let iterations = 600_000

    // MARK: - Lifecycle

    static func hasKeys() -> Bool {
        loadPublicKeyRaw() != nil
    }

    /// Generate new keypair and wrap private key with passphrase-derived key.
    static func createKeys(passphrase: String) throws {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let publicKey = privateKey.publicKey
        let wrappedJSON = try wrapPrivateKeyRaw(privateKey.rawRepresentation, passphrase: passphrase)
        try savePublicKey(publicKey.rawRepresentation)
        try saveWrappedPrivate(wrappedJSON)
    }

    static func unwrapPrivateKey(passphrase: String) throws -> SecureBytes {
        guard let wrappedJSON = loadWrappedPrivate() else {
            throw KeyManagerError.notConfigured
        }
        return try unwrapPrivateKeyFromJSON(passphrase: passphrase, wrappedJSON: wrappedJSON)
    }

    static func unwrapPrivateKey(passphrase: String, wrappedJSON: Data) throws -> SecureBytes {
        return try unwrapPrivateKeyFromJSON(passphrase: passphrase, wrappedJSON: wrappedJSON)
    }

    static func changePassphrase(currentPassphrase: String, newPassphrase: String) throws {
        guard !newPassphrase.isEmpty else {
            throw KeyManagerError.invalidPassphrase
        }
        let privateKey = try unwrapPrivateKey(passphrase: currentPassphrase)
        let rewrapped = try privateKey.withUnsafeBytes { raw in
            try wrapPrivateKeyRaw(Data(raw), passphrase: newPassphrase)
        }
        try saveWrappedPrivate(rewrapped)
    }

    static func exportWrappedPrivateKeyJSON() throws -> Data {
        guard let wrapped = loadWrappedPrivate() else {
            throw KeyManagerError.notConfigured
        }
        return wrapped
    }

    static func exportPublicKeyRaw() throws -> Data {
        guard let raw = loadPublicKeyRaw() else {
            throw KeyManagerError.notConfigured
        }
        return raw
    }

    static func importPublicKeyRaw(_ data: Data) throws {
        try savePublicKey(data)
    }

    static func importWrappedPrivateKeyJSON(_ data: Data) throws {
        _ = try JSONDecoder().decode(WrappedPrivateKey.self, from: data)
        try saveWrappedPrivate(data)
    }

    private static func unwrapPrivateKeyFromJSON(passphrase: String, wrappedJSON: Data) throws -> SecureBytes {
        let wrapped = try JSONDecoder().decode(WrappedPrivateKey.self, from: wrappedJSON)
        guard let salt = Data(base64Encoded: wrapped.salt),
              let combined = Data(base64Encoded: wrapped.wrappedPrivateKey)
        else {
            throw KeyManagerError.invalidWrappedPayload
        }

        var wrappingKeyData = try PBKDF2.deriveKey(
            password: Data(passphrase.utf8),
            salt: salt,
            iterations: iterations
        )
        defer {
            zeroize(&wrappingKeyData)
        }
        let wrappingKey = SymmetricKey(data: wrappingKeyData)
        let box = try AES.GCM.SealedBox(combined: combined)
        var privateRaw: Data
        do {
            privateRaw = try AES.GCM.open(box, using: wrappingKey)
        } catch {
            throw KeyManagerError.decryptionFailed
        }
        defer {
            zeroize(&privateRaw)
        }
        return SecureBytes(data: privateRaw)
    }

    static func publicKeyForAgreement() throws -> Curve25519.KeyAgreement.PublicKey {
        guard let raw = loadPublicKeyRaw() else {
            throw KeyManagerError.notConfigured
        }
        return try Curve25519.KeyAgreement.PublicKey(rawRepresentation: raw)
    }

    // MARK: - Optional hint (plaintext in Keychain; user-facing reminder only)

    static func savePassphraseHint(_ hint: String?) throws {
        if let hint, !hint.isEmpty {
            try saveKeychainString(tag: hintTag, value: hint, accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        } else {
            deleteKeychainItem(tag: hintTag)
        }
    }

    static func loadPassphraseHint() -> String? {
        loadKeychainString(tag: hintTag)
    }

    // MARK: - Keychain

    private struct WrappedPrivateKey: Codable {
        var salt: String
        var wrappedPrivateKey: String
    }

    private static func wrapPrivateKeyRaw(_ privateRaw: Data, passphrase: String) throws -> Data {
        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        var wrappingKeyData = try PBKDF2.deriveKey(
            password: Data(passphrase.utf8),
            salt: salt,
            iterations: iterations
        )
        defer {
            zeroize(&wrappingKeyData)
        }
        let wrappingKey = SymmetricKey(data: wrappingKeyData)
        let sealed = try AES.GCM.seal(privateRaw, using: wrappingKey)
        guard let combined = sealed.combined else {
            throw KeyManagerError.decryptionFailed
        }
        let wrapped = WrappedPrivateKey(
            salt: salt.base64EncodedString(),
            wrappedPrivateKey: combined.base64EncodedString()
        )
        return try JSONEncoder().encode(wrapped)
    }

    private static func savePublicKey(_ data: Data) throws {
        deleteKeychainItem(tag: publicKeyTag)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: publicKeyTag,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: false,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyManagerError.keychainFailure(status) }
    }

    private static func loadPublicKeyRaw() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: publicKeyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return data
    }

    private static func saveWrappedPrivate(_ data: Data) throws {
        deleteKeychainItem(tag: wrappedPrivateTag)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: wrappedPrivateTag,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: false,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyManagerError.keychainFailure(status) }
    }

    private static func loadWrappedPrivate() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: wrappedPrivateTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return data
    }

    private static func saveKeychainString(tag: String, value: String, accessible: CFString) throws {
        deleteKeychainItem(tag: tag)
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecAttrAccessible as String: accessible,
            kSecValueData as String: data,
            kSecAttrSynchronizable as String: false,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeyManagerError.keychainFailure(status) }
    }

    private static func loadKeychainString(tag: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeychainItem(tag: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func zeroize(_ data: inout Data) {
        data.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            _ = memset_s(base, raw.count, 0, raw.count)
        }
    }
}
