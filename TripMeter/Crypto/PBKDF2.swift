import CryptoKit
import Darwin
import Foundation

/// PBKDF2-HMAC-SHA256 (RFC 2898).
enum PBKDF2 {
    static func deriveKey(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int = 32,
        progress: (@Sendable (Double) -> Void)? = nil
    ) throws -> Data {
        precondition(iterations > 0)
        precondition(keyLength > 0)

        let hLen = SHA256.byteCount
        let l = Int(ceil(Double(keyLength) / Double(hLen)))
        var dk = Data()

        let key = SymmetricKey(data: password)

        for block in 1...l {
            var u = try HMAC<SHA256>.authenticationCode(
                for: salt + UInt32(block).bigEndianData,
                using: key
            )
            var t = Data(u)
            var uData = Data(u)
            defer {
                zeroize(&t)
                zeroize(&uData)
            }

            for iteration in 1..<iterations {
                u = try HMAC<SHA256>.authenticationCode(for: uData, using: key)
                uData = Data(u)
                for j in 0..<t.count {
                    t[j] ^= uData[j]
                }
                if let progress, iteration % 6_000 == 0 {
                    progress(Double(iteration) / Double(iterations))
                }
            }
            if let progress {
                progress(1.0)
            }
            dk.append(t)
        }

        return dk.prefix(keyLength)
    }

    private static func zeroize(_ data: inout Data) {
        data.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            _ = memset_s(base, raw.count, 0, raw.count)
        }
    }
}

private extension UInt32 {
    var bigEndianData: Data {
        withUnsafeBytes(of: self.bigEndian) { Data($0) }
    }
}
