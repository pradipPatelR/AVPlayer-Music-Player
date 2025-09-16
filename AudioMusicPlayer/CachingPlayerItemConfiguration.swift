//
//  CachingPlayerItemConfiguration.swift
//  CachingPlayerItem
//

import Foundation

/// CachingPlayerItem global configuration.
public enum CachingPlayerItemConfiguration {
    /// How much data is downloaded in memory before stored on a file.
    public static var downloadBufferLimit: Int = 128.KB

    /// How much data is allowed to be read in memory at a time.
    public static var readDataLimit: Int = 10.MB

    /// Flag for deciding whether an error should be thrown when URLResponse's expectedContentLength is not equal with the downloaded media file bytes count. Defaults to `false`.
    public static var shouldVerifyDownloadedFileSize: Bool = false

    /// If set greater than 0, the set value with be compared with the downloaded media size. If the size of the downloaded media is lower, an error will be thrown. Useful when `expectedContentLength` is unavailable.
    /// Default value is `0`.
    public static var minimumExpectedFileSize: Int = 0
}

fileprivate extension Int {
    var KB: Int { return self * 1024 }
    var MB: Int { return self * 1024 * 1024 }
}


// MARK: - Public API
extension String {
    fileprivate var md5Bytes: [UInt8] {
        return self.data(using: .utf8, allowLossyConversion: true)?.bytes ?? Array(self.utf8)
    }

    /// The hex MD5 string (lowercase)
    var md5String: String {
        return self.md5Bytes.md5().toHexString()
    }
}

extension Data {
    var bytes: [UInt8] { Array(self) }
}

extension Array where Element == UInt8 {
    /// Convert bytes to hex string (lowercase)
    public func toHexString() -> String {
        self.reduce(into: "") { acc, byte in
            let s = String(byte, radix: 16)
            acc += (s.count == 1) ? "0" + s : s
        }
    }

    /// Compute MD5 for this byte array (internal)
    fileprivate func md5() -> [UInt8] {
        return AudioURL_Digest.md5(self)
    }
}

// MARK: - Digest entry
public struct AudioURL_Digest {
    fileprivate static func md5(_ bytes: [UInt8]) -> [UInt8] {
        return AudioURL_MD5().calculate(for: bytes)
    }
}

// MARK: - Internal/Private MD5 implementation

// Minimal protocol used by MD5
internal protocol DigestType {
    func calculate(for bytes: [UInt8]) -> [UInt8]
}

// Updatable protocol (kept simple for class implementation)
protocol Updatable {
    func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool) -> [UInt8]
}

// Fileprivate MD5 core
fileprivate class AudioURL_MD5: DigestType, Updatable {
    static let blockSize: Int = 64
    static let digestLength: Int = 16
    fileprivate static let hashInitialValue: [UInt32] = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476]

    fileprivate var accumulated = [UInt8]()
    fileprivate var processedBytesTotalCount: Int = 0
    fileprivate var accumulatedHash: [UInt32] = AudioURL_MD5.hashInitialValue

    // per-round shift amounts
    private let s: [UInt32] = [
        7,12,17,22,7,12,17,22,7,12,17,22,7,12,17,22,
        5,9,14,20,5,9,14,20,5,9,14,20,5,9,14,20,
        4,11,16,23,4,11,16,23,4,11,16,23,4,11,16,23,
        6,10,15,21,6,10,15,21,6,10,15,21,6,10,15,21
    ]

    // constants
    private let k: [UInt32] = [
        0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,
        0xf57c0faf,0x4787c62a,0xa8304613,0xfd469501,
        0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,
        0x6b901122,0xfd987193,0xa679438e,0x49b40821,
        0xf61e2562,0xc040b340,0x265e5a51,0xe9b6c7aa,
        0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
        0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,
        0xa9e3e905,0xfcefa3f8,0x676f02d9,0x8d2a4c8a,
        0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,
        0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,
        0x289b7ec6,0xeaa127fa,0xd4ef3085,0x04881d05,
        0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
        0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,
        0x655b59c3,0x8f0ccc92,0xffeff47d,0x85845dd1,
        0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,
        0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391
    ]

    public init() {}

    // DigestType conformance
    func calculate(for bytes: [UInt8]) -> [UInt8] {
        return update(withBytes: bytes.bytesSlice, isLast: true)
    }

    // Updatable conformance: handle streaming updates and finalization
    func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool = false) -> [UInt8] {
        // append new bytes
        self.accumulated += bytes

        if isLast {
            // append padding and length
            let lengthInBits = (processedBytesTotalCount + self.accumulated.count) * 8
            let lengthBytes = lengthInBits.bytes(totalBytes: 64 / 8) // 64-bit representation
            bitPadding(to: &self.accumulated, blockSize: AudioURL_MD5.blockSize, allowance: 64 / 8)
            self.accumulated += lengthBytes.reversed()
        }

        // process full 64-byte (512-bit) chunks
        var processedBytes = 0
        let chunkSize = AudioURL_MD5.blockSize
        while (self.accumulated.count - processedBytes) >= chunkSize {
            let start = processedBytes
            let end = start + chunkSize
            let chunk = ArraySlice(self.accumulated[start..<end])
            self.process(block: chunk, currentHash: &self.accumulatedHash)
            processedBytes += chunk.count
        }

        if processedBytes > 0 {
            self.accumulated.removeFirst(processedBytes)
        }
        self.processedBytesTotalCount += processedBytes

        // produce current digest (little-endian concatenation)
        var result = [UInt8]()
        result.reserveCapacity(AudioURL_MD5.digestLength)
        for h in self.accumulatedHash {
            let hLE = h.littleEndian
            result += [UInt8(hLE & 0xff), UInt8((hLE >> 8) & 0xff), UInt8((hLE >> 16) & 0xff), UInt8((hLE >> 24) & 0xff)]
        }

        if isLast {
            // reset internal state for potential reuse
            self.accumulatedHash = AudioURL_MD5.hashInitialValue
        }

        return result
    }

    // Process a single 512-bit chunk
    fileprivate func process(block chunk: ArraySlice<UInt8>, currentHash: inout [UInt32]) {
        assert(chunk.count == 16 * 4)

        var A: UInt32 = currentHash[0]
        var B: UInt32 = currentHash[1]
        var C: UInt32 = currentHash[2]
        var D: UInt32 = currentHash[3]

        var dTemp: UInt32 = 0

        for j in 0..<self.k.count {
            var g = 0
            var F: UInt32 = 0

            switch j {
            case 0...15:
                F = (B & C) | ((~B) & D)
                g = j
            case 16...31:
                F = (D & B) | ((~D) & C)
                g = (5 * j + 1) % 16
            case 32...47:
                F = B ^ C ^ D
                g = (3 * j + 5) % 16
            case 48...63:
                F = C ^ (B | (~D))
                g = (7 * j) % 16
            default:
                break
            }

            dTemp = D
            D = C
            C = B

            let gAdvanced = g << 2
            var Mg = UInt32(chunk[chunk.startIndex &+ gAdvanced])
            Mg |= UInt32(chunk[chunk.startIndex &+ gAdvanced &+ 1]) << 8
            Mg |= UInt32(chunk[chunk.startIndex &+ gAdvanced &+ 2]) << 16
            Mg |= UInt32(chunk[chunk.startIndex &+ gAdvanced &+ 3]) << 24

            B = B &+ rotateLeft(A &+ F &+ self.k[j] &+ Mg, by: self.s[j])
            A = dTemp
        }

        currentHash[0] = currentHash[0] &+ A
        currentHash[1] = currentHash[1] &+ B
        currentHash[2] = currentHash[2] &+ C
        currentHash[3] = currentHash[3] &+ D
    }
}

// MARK: - Helpers


fileprivate func rotateLeft(_ value: UInt32, by: UInt32) -> UInt32 {
    ((value << by) & 0xffffffff) | (value >> (32 - by))
}


fileprivate func bitPadding(to data: inout [UInt8], blockSize: Int, allowance: Int = 0) {
    let msgLength = data.count
    data.append(0x80)
    let max = blockSize - allowance
    if msgLength % blockSize < max {
        data += Array<UInt8>(repeating: 0, count: max - 1 - (msgLength % blockSize))
    } else {
        data += Array<UInt8>(repeating: 0, count: blockSize + max - 1 - (msgLength % blockSize))
    }
}

// FixedWidthInteger -> bytes helper (uses manual pointer copy to match expected byte order)
fileprivate extension FixedWidthInteger {
    
    func bytes(totalBytes: Int = MemoryLayout<Self>.size) -> [UInt8] {
        arrayOfBytes(value: self.littleEndian, length: totalBytes)
    }
}

@_specialize(where T == Int)
@_specialize(where T == UInt)
@_specialize(where T == UInt8)
@_specialize(where T == UInt16)
@_specialize(where T == UInt32)
@_specialize(where T == UInt64)
fileprivate func arrayOfBytes<T: FixedWidthInteger>(value: T, length totalBytes: Int = MemoryLayout<T>.size) -> [UInt8] {
    let valuePointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
    valuePointer.pointee = value

    let bytesPointer = UnsafeMutablePointer<UInt8>(OpaquePointer(valuePointer))
    var bytes = [UInt8](repeating: 0, count: totalBytes)
    for j in 0..<min(MemoryLayout<T>.size, totalBytes) {
        bytes[totalBytes - 1 - j] = (bytesPointer + j).pointee
    }

    valuePointer.deinitialize(count: 1)
    valuePointer.deallocate()

    return bytes
}

// Small convenience to get an ArraySlice of a full array
fileprivate extension Array {
    var bytesSlice: ArraySlice<Element> { self[startIndex..<endIndex] }
}
