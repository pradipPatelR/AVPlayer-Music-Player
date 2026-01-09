//
//  CachingPlayerItemConfiguration.swift
//  CachingPlayerItem
//

import Foundation

/// CachingPlayerItem global configuration.
public enum CachingPlayerItemConfiguration {
    /// How much data is downloaded in memory before stored on a file.
    public static var downloadBufferLimit: Int = 128.audioURL_KB

    /// How much data is allowed to be read in memory at a time.
    public static var readDataLimit: Int = 10.audioURL_MB

    /// Flag for deciding whether an error should be thrown when URLResponse's expectedContentLength is not equal with the downloaded media file bytes count. Defaults to `false`.
    public static var shouldVerifyDownloadedFileSize: Bool = false

    /// If set greater than 0, the set value with be compared with the downloaded media size. If the size of the downloaded media is lower, an error will be thrown. Useful when `expectedContentLength` is unavailable.
    /// Default value is `0`.
    public static var minimumExpectedFileSize: Int = 0
}

fileprivate extension Int {
    var audioURL_KB: Int { return self * 1024 }
    var audioURL_MB: Int { return self * 1024 * 1024 }
}


