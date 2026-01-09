//
//  ResourceLoaderDelegate.swift
//  CachingPlayerItem
//

import Foundation
import AVFoundation
import UIKit

/// Responsible for downloading media data and providing the requested data parts.
final class ResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {
    private let lock = NSLock()

    private var bufferData = Data()
    private let downloadBufferLimit = CachingPlayerItemConfiguration.downloadBufferLimit
    private let readDataLimit = CachingPlayerItemConfiguration.readDataLimit

    private lazy var fileHandle = MediaFileHandle(filePath: self.saveFilePath)

    private var session: URLSession?
    private var response: URLResponse?
    private var pendingRequests = Set<AVAssetResourceLoadingRequest>()
    private var isDownloadComplete = false

    private let url: URL
    private let saveFilePath: String
    private weak var owner: CachingPlayerItem?

    // MARK: Init

    init(url: URL, saveFilePath: String, owner: CachingPlayerItem?) {
        self.url = url
        self.saveFilePath = saveFilePath
        self.owner = owner
        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(self.handleAppWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }

    deinit {
        self.invalidateAndCancelSession()
    }

    // MARK: AVAssetResourceLoaderDelegate

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if self.session == nil {
            // If we're playing from an url, we need to download the file.
            // We start loading the file on first request only.
            self.startDataRequest(with: self.url)
        }

        self.pendingRequests.insert(loadingRequest)
        self.processPendingRequests()
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        self.pendingRequests.remove(loadingRequest)
    }

    // MARK: URLSessionDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        self.bufferData.append(data)
        self.writeBufferDataToFileIfNeeded()
        self.processPendingRequests()
        DispatchQueue.main.async { [weak self] in
            if let this = self,
               let ownr = this.owner {
                ownr.delegate?.playerItem?(ownr, didDownloadBytesSoFar: this.fileHandle.fileSize, outOf: Int(dataTask.countOfBytesExpectedToReceive))
            }
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        self.processPendingRequests()
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.downloadFailed(with: error)
            return
        }

        if self.bufferData.count > 0 {
            self.fileHandle.append(data: self.bufferData)
        }

        let error = self.verifyResponse()

        guard error == nil else {
            self.downloadFailed(with: error!)
            return
        }

        self.downloadComplete()
    }

    // MARK: Internal methods

    func startDataRequest(with url: URL) {
        guard self.session == nil else { return }

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        var urlRequest = URLRequest(url: url)
        self.owner?.urlRequestHeaders?.forEach { urlRequest.setValue($0.value, forHTTPHeaderField: $0.key) }
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        self.session?.dataTask(with: urlRequest).resume()
    }

    func invalidateAndCancelSession() {
        self.session?.invalidateAndCancel()
    }

    // MARK: Private methods

    private func processPendingRequests() {
        self.lock.lock()
        defer { self.lock.unlock() }

        // Filter out the unfullfilled requests
        let requestsFulfilled: Set<AVAssetResourceLoadingRequest> = self.pendingRequests.filter {
            self.fillInContentInformationRequest($0.contentInformationRequest)
            guard self.haveEnoughDataToFulfillRequest($0.dataRequest!) else { return false }

            $0.finishLoading()
            return true
        }

        // Remove fulfilled requests from pending requests
        requestsFulfilled.forEach { self.pendingRequests.remove($0) }
    }

    private func fillInContentInformationRequest(_ contentInformationRequest: AVAssetResourceLoadingContentInformationRequest?) {
        // Do we have response from the server?
        guard let response = self.response else { return }

        contentInformationRequest?.contentType = response.mimeType
        contentInformationRequest?.contentLength = response.expectedContentLength
        contentInformationRequest?.isByteRangeAccessSupported = true
    }

    private func haveEnoughDataToFulfillRequest(_ dataRequest: AVAssetResourceLoadingDataRequest) -> Bool {
        let requestedOffset = Int(dataRequest.requestedOffset)
        let requestedLength = dataRequest.requestedLength
        let currentOffset = Int(dataRequest.currentOffset)
        let bytesCached = self.fileHandle.fileSize

        // Is there enough data cached to fulfill the request?
        guard bytesCached > currentOffset else { return false }

        // Data length to be loaded into memory with maximum size of readDataLimit.
        let bytesToRespond = min(bytesCached - currentOffset, requestedLength, self.readDataLimit)

        // Read data from disk and pass it to the dataRequest
        guard let data = self.fileHandle.readData(withOffset: currentOffset, forLength: bytesToRespond) else { return false }
        dataRequest.respond(with: data)

        return bytesCached >= requestedLength + requestedOffset
    }

    private func writeBufferDataToFileIfNeeded() {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self.bufferData.count >= self.downloadBufferLimit else { return }

        self.fileHandle.append(data: self.bufferData)
        self.bufferData = Data()
    }

    private func downloadComplete() {
        self.processPendingRequests()

        self.isDownloadComplete = true

        DispatchQueue.main.async { [weak self] in
            if let this = self,
               let ownr = this.owner {
                ownr.delegate?.playerItem?(ownr, didFinishDownloadingFileAt: this.saveFilePath)
            }
        }
    }

    private func verifyResponse() -> NSError? {
        guard let response = self.response as? HTTPURLResponse else { return nil }

        let shouldVerifyDownloadedFileSize = CachingPlayerItemConfiguration.shouldVerifyDownloadedFileSize
        let minimumExpectedFileSize = CachingPlayerItemConfiguration.minimumExpectedFileSize
        var error: NSError?

        if response.statusCode >= 400 {
            error = NSError(domain: "Failed downloading asset. Reason: response status code \(response.statusCode).", code: response.statusCode, userInfo: nil)
        } else if shouldVerifyDownloadedFileSize && response.expectedContentLength != -1 && response.expectedContentLength != self.fileHandle.fileSize {
            error = NSError(domain: "Failed downloading asset. Reason: wrong file size, expected: \(response.expectedContentLength), actual: \(self.fileHandle.fileSize).", code: response.statusCode, userInfo: nil)
        } else if minimumExpectedFileSize > 0 && minimumExpectedFileSize > self.fileHandle.fileSize {
            error = NSError(domain: "Failed downloading asset. Reason: file size \(self.fileHandle.fileSize) is smaller than minimumExpectedFileSize", code: response.statusCode, userInfo: nil)
        }

        return error
    }

    private func downloadFailed(with error: Error) {
        self.fileHandle.deleteFile()

        DispatchQueue.main.async { [weak self] in
            if let this = self,
               let ownr = this.owner {
                ownr.delegate?.playerItem?(ownr, downloadingFailedWith: error)
            }
        }
    }

    @objc private func handleAppWillTerminate() {
        // We need to only remove the file if it hasn't been fully downloaded
        guard self.isDownloadComplete == false else { return }

        self.fileHandle.deleteFile()
    }
}
