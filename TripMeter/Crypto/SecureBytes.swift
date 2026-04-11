import Darwin
import Foundation

/// Holds sensitive bytes and zeroes them on deallocation.
final class SecureBytes: @unchecked Sendable {
    private var buffer: [UInt8]

    init(data: Data) {
        buffer = Array(data)
    }

    deinit {
        buffer.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            _ = memset_s(base, raw.count, 0, raw.count)
        }
    }

    func withUnsafeBytes<T>(_ body: (UnsafeRawBufferPointer) throws -> T) rethrows -> T {
        try buffer.withUnsafeBytes(body)
    }

    var data: Data {
        Data(buffer)
    }
}
