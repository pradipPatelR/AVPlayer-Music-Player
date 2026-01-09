//
//  MediaFileHandle.swift
//  CachingPlayerItem
//

import Foundation

/// File handle for local file operations.
final class MediaFileHandle {
    private let filePath: String
    private lazy var readHandle = FileHandle(forReadingAtPath: self.filePath)
    private lazy var writeHandle = FileHandle(forWritingAtPath: self.filePath)

    private let lock = NSLock()

    // MARK: Init

    init(filePath: String) {
        self.filePath = filePath

        if !FileManager.default.fileExists(atPath: filePath) {
            FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
        } else {
            print("CachingPlayerItem warning: File already exists at \(filePath). A non empty file can cause unexpected behavior.")
        }
    }

    deinit {
        guard FileManager.default.fileExists(atPath: self.filePath) else { return }

        self.close()
    }
}

// MARK: Internal methods

extension MediaFileHandle {
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: filePath)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }

    var fileSize: Int {
        return self.attributes?[.size] as? Int ?? 0
    }

    func readData(withOffset offset: Int, forLength length: Int) -> Data? {
        self.lock.lock()
        defer { self.lock.unlock() }

        self.readHandle?.seek(toFileOffset: UInt64(offset))
        return self.readHandle?.readData(ofLength: length)
    }

    func append(data: Data) {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard let writeHandle = self.writeHandle else { return }

        writeHandle.seekToEndOfFile()
        writeHandle.write(data)
    }

    func synchronize() {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard let writeHandle = self.writeHandle else { return }

        writeHandle.synchronizeFile()
    }

    func close() {
        self.readHandle?.closeFile()
        self.writeHandle?.closeFile()
    }

    func deleteFile() {
        do {
            try FileManager.default.removeItem(atPath: self.filePath)
        } catch let error {
            print("File deletion error: \(error)")
        }
    }
}
