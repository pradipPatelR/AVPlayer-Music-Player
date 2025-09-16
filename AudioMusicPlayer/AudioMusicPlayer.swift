//
//  AudioMusicPlayer.swift
//  MusicPlayerDemo
//


import UIKit
import MediaPlayer
import AVFoundation

fileprivate var sharedInstanceSingletone: AudioMusicPlayer!

extension AudioMusicPlayer {
    
    private static var saveKey: String { return "com.CachingPlayerItem.cachingPlayerItem.Time" }
    
    static func checkIfNeededCachingPlayerClear() {
        if UserDefaults.standard.value(forKey: Self.saveKey) == nil {
            UserDefaults.standard.setValue(Date().timeIntervalSince1970, forKey: Self.saveKey)
            UserDefaults.standard.synchronize()
        }
        
        let saveTimeInterval = UserDefaults.standard.double(forKey: saveKey)
        
        if (saveTimeInterval + (24 * 60 * 60)) < Date().timeIntervalSince1970 {
            CachingPlayerItem.removeCachingFolder()
        }
    }
    
    func checkIfNeededCachingPlayerClear() {
        Self.checkIfNeededCachingPlayerClear()
    }
    
    
}

final class AudioMusicPlayer: NSObject {
    
    enum AudioMusicPlayerRepeatMode {
        case none
        case one
        case all
    }
    
    
    //MARK:- Variables
    //Public
    class var sharedInstance: AudioMusicPlayer {
        if sharedInstanceSingletone == nil {
            sharedInstanceSingletone = .init()
            sharedInstanceSingletone.checkIfNeededCachingPlayerClear()
        }
        return sharedInstanceSingletone
    }
    
    private var addPeriodicTimeObserver : Any?
    
    public private(set) var musicPlayer : AVPlayer?
    public private(set) var songListItem: [SongListItem] = []
    public private(set) var changeSongListItem: [SongListItem] = []
    
    public private(set) var totalSecond: Double = 0
    public private(set) var currentSecond: Double = 0
    public private(set) var bufferProgress: Float = 0
    public private(set) var nextIsEnabled: Bool = false
    public private(set) var previousIsEnabled: Bool = false
    
    public var nextIsEnabledChangeClouser: [((Bool) -> Void)?] = []
    public var previousIsEnabledChangeClouser: [((Bool) -> Void)?] = []
    public var changeValueCallBackClouser: [(() -> Void)?] = []
    public var avPlayerDidEndFinishTimeClouser: [(() -> Void)?] = []
    public var playPauseChangeClouser: [(() -> Void)?] = []
    public var changeMpPlayerNextPreviousClouser: [(() -> Void)?] = []
    public var avPlayerBufferingClouser: [((Bool) -> Void)?] = []
    
    public var currentSongString: String? {
        
        return ((self.musicPlayer?.currentItem as? CachingPlayerItem)?.passOnObject as? URL)?.absoluteString
    }
    
    public var isAccessSuffleMode: Bool { return self.songListItem.count > 2 }
    public var isAccessRepeatMode: Bool { return self.songListItem.count > 1 }
    
    public private(set) var isSuffle: Bool = false
    public private(set) var repeatMode: AudioMusicPlayerRepeatMode = .all
    
    public private(set) var error: Error?
    public private(set) var isMPRemoteCommandCenterEnable: Bool = false
    
    
    public var isPlaying: Bool {
        guard let mPlayer = self.musicPlayer else { return false }
        return (((mPlayer.rate != 0) && (mPlayer.error == nil)) || (mPlayer.timeControlStatus == .playing))
    }
    
    private var isFirstTimePlayingPause: Bool = false
    
    private func nowPlayingSetMPNowPlayingInfo(_ setImageByURLString: (urlString:String, image:UIImage?)?) -> [String : Any]? {
        
        guard self.changeSongListItem.count > 0 else { return nil }
        guard self.songListItem.count > 0 else { return nil }
            
        if let getImageByURLString = setImageByURLString {
            
            if let indx = self.changeSongListItem.firstIndex(where: { $0.url.absoluteString == getImageByURLString.urlString }) {
                self.changeSongListItem[indx].img = getImageByURLString.image
            }
            
            if let indx = self.songListItem.firstIndex(where: { $0.url.absoluteString == getImageByURLString.urlString }) {
                self.songListItem[indx].img = getImageByURLString.image
            }
            
        }
        
            
        if let currentSongStr = self.currentSongString,
           let indx = self.changeSongListItem.firstIndex(where: { $0.url.absoluteString == currentSongStr }) {
            
            let item = self.changeSongListItem[indx]
            
            var dict: [String: Any] = [MPMediaItemPropertyTitle: item.songTitleName,
                                      MPMediaItemPropertyArtist: item.songArtistName,
                           MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: 1.0)]
            
            if let getImg = item.img {
                dict[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: getImg.size, requestHandler: { (sz) in
                    return getImg
                })
            }
            
            return dict
            
        }
        
        return nil
    }
    
    private func changeListAndSuffleMPRemoteCommandCenterSetup() {
        
        self.changeSongListItem = self.isSuffle ? self.arrayListShuffle(self.songListItem) : self.songListItem
        
        guard isMPRemoteCommandCenterEnable else { return }
        
        guard self.changeSongListItem.count > 0 else { return }
        
        if let currentSongStr = self.currentSongString {
            
            if let indx = self.changeSongListItem.firstIndex(where: { $0.url.absoluteString == currentSongStr }) {
                MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = !(indx == (self.changeSongListItem.count - 1))
                MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = !(indx == 0)
            }
            
        }
        
        
    }
    
    //MARK:- Initializer
    private override init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            debugPrint("Playback OK")
            try AVAudioSession.sharedInstance().setActive(true)
            debugPrint("Session is Active")
        } catch let err {
            debugPrint(err.localizedDescription)
        }
        super.init()
    }
    
    static func newCreateInstanceObject() -> AudioMusicPlayer {
        return AudioMusicPlayer()
    }
    
    func setupNowPlayingInfoCenter(isEnable: Bool) {
        
        self.isMPRemoteCommandCenterEnable = isEnable
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let remoteCommandCenter = MPRemoteCommandCenter.shared()
        
        remoteCommandCenter.togglePlayPauseCommand.isEnabled = isEnable
        remoteCommandCenter.playCommand.isEnabled = isEnable
        remoteCommandCenter.pauseCommand.isEnabled = isEnable
        remoteCommandCenter.nextTrackCommand.isEnabled = isEnable
        remoteCommandCenter.previousTrackCommand.isEnabled = isEnable
//        remoteCommandCenter.changeRepeatModeCommand.isEnabled = isEnable
//        remoteCommandCenter.changeShuffleModeCommand.isEnabled = isEnable
        remoteCommandCenter.changePlaybackPositionCommand.isEnabled = isEnable
        
        guard isEnable else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            UIApplication.shared.endReceivingRemoteControlEvents()
            return
        }
        
        remoteCommandCenter.nextTrackCommand.isEnabled = self.nextIsEnabled
        remoteCommandCenter.previousTrackCommand.isEnabled = self.previousIsEnabled
        
        remoteCommandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            self?.playPauseCommand()
            self?.playPauseChangeClouser.forEach({ $0?() })
            return .success
        }
        
        remoteCommandCenter.playCommand.addTarget { [weak self] event in
            self?.playPauseCommand()
            self?.playPauseChangeClouser.forEach({ $0?() })
            return .success
        }
        
        remoteCommandCenter.pauseCommand.addTarget { [weak self] event in
            self?.playPauseCommand()
            self?.playPauseChangeClouser.forEach({ $0?() })
            return .success
        }
        
        remoteCommandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.nextPreviousPlaying(true, playIndex: nil)
            self?.changeMpPlayerNextPreviousClouser.forEach({ $0?() })
            return .success
        }
        
        remoteCommandCenter.previousTrackCommand.addTarget { [weak self] event in
            self?.nextPreviousPlaying(false, playIndex: nil)
            self?.changeMpPlayerNextPreviousClouser.forEach({ $0?() })
            return .success
        }
        
//        remoteCommandCenter.changeRepeatModeCommand.addTarget { event in
//            return .success
//        }
//        remoteCommandCenter.changeShuffleModeCommand.addTarget { event in
//            return .success
//        }
        
        MPNowPlayingInfoCenter.default().playbackState = .playing
        
        remoteCommandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let commandEvent = event as? MPChangePlaybackPositionCommandEvent {
                
                if let mPlayer = self?.musicPlayer {
                    mPlayer.currentItem?.seek(to: CMTime(seconds: commandEvent.positionTime, preferredTimescale: 1), completionHandler: { (bool) in
                        
                    })
                }
            }
            return .success
        }
        
        setupMPRemoteCommandSetupAndImage(nil)
        
    }
    
    func setupMPRemoteCommandSetupAndImage(_ setImageByURLString: (urlString:String, image:UIImage?)?) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingSetMPNowPlayingInfo(setImageByURLString)
    }
    
    func updateMusicPlayer(_songListItem: [SongListItem]) {
        self.songListItem = _songListItem
        
        if songListItem.count > 2 {
            self.changeSongListItem = self.isSuffle ? self.arrayListShuffle(self.songListItem) : self.songListItem
        } else {
            self.changeSongListItem = self.songListItem
        }
    }
    
    func playAtSongIndex(_ playIndex: Int) {
        if self.changeSongListItem.indices.contains(playIndex) {
            self.isFirstTimePlayingPause = true
            
            self.nextPreviousPlaying(nil, playIndex: playIndex, isChangeIndexForceFull: true)
        }
    }
    
    func setupMusicPlayer(_songListItem: [SongListItem], _playIndex: Int, isFirstTimePlayingPause: Bool = false) {
        self.songListItem = _songListItem
        self.isFirstTimePlayingPause = isFirstTimePlayingPause
        
        if songListItem.count > 2 {
            self.changeSongListItem = self.isSuffle ? self.arrayListShuffle(self.songListItem) : self.songListItem
        } else {
            self.changeSongListItem = self.songListItem
        }
        
        nextPreviousPlaying(true, playIndex: _playIndex - 1)
    }
    
    func playPauseCommand() {
        if self.isPlaying {
            self.musicPlayer?.pause()
        } else {
            self.musicPlayer?.play()
        }
        
        if self.isMPRemoteCommandCenterEnable {
            
            DispatchQueue.main.async {
                MPNowPlayingInfoCenter.default().playbackState = self.isPlaying ? .playing : .paused
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    if let mPlayer = self?.musicPlayer {
                        var nowPlayingInfoDict = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        
                        let currentTime = mPlayer.currentTime()
                        nowPlayingInfoDict[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime.seconds
                        if let duration = mPlayer.currentItem?.duration {
                            nowPlayingInfoDict[MPMediaItemPropertyPlaybackDuration] = duration.seconds
                        }
                        
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
                    }
                }
            }
            
        }
        
        
    }
    
    //MARK:- Public Methods
    
    @objc func musicPlayerSetSeek(sliderValue: Float, completion: (() -> Void)? = nil) {
        let seekTime = CMTime(seconds: Double(sliderValue), preferredTimescale: 1)
        if self.musicPlayer == nil { return }
        self.musicPlayer?.currentItem?.seek(to: seekTime, completionHandler: { (_) in
            completion?()
        })
        
    }
    
    func changeSuffleMode(_ _isSuffle: Bool) -> Bool {
        if self.songListItem.count > 2 {
            self.isSuffle = _isSuffle
            self.changeListAndSuffleMPRemoteCommandCenterSetup()
            
            if let currentSongStr = self.currentSongString {
                
                if let idx = self.changeSongListItem.firstIndex(where: { $0.url.absoluteString == currentSongStr }) {
                    
                    self.nextIsEnabled = !(idx == (self.changeSongListItem.count - 1))
                    self.previousIsEnabled = !(idx == 0)
                    self.nextIsEnabledChangeClouser.forEach({ $0?(self.nextIsEnabled) })
                    self.previousIsEnabledChangeClouser.forEach({ $0?(self.previousIsEnabled) })
                    
                }
                
            }
            
            
            return true
        } else {
            return false
        }
    }
    
    @discardableResult
    func changeRepeatMode(_ _repeatMode: AudioMusicPlayerRepeatMode) -> Bool {
        if self.songListItem.count > 1 {
            self.repeatMode = _repeatMode
            return true
        } else {
            return false
        }
    }
    
    func clearAudioPlayer() {
        if self.isPlaying { self.musicPlayer?.pause() }
        
        if self.isMPRemoteCommandCenterEnable {
            self.setupMPRemoteCommandSetupAndImage(nil)
        }
        
        if let mPlayer = self.musicPlayer {
            mPlayer.pause()
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: mPlayer.currentItem)
            mPlayer.removeObserver(self, forKeyPath: "status", context: nil)
            mPlayer.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty", context: nil)
            mPlayer.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: nil)
            mPlayer.currentItem?.removeObserver(self, forKeyPath: "playbackBufferFull", context: nil)
            if let observer = self.addPeriodicTimeObserver {
                self.musicPlayer?.removeTimeObserver(observer)
                self.addPeriodicTimeObserver = nil
            }
            self.musicPlayer = nil
        }
        
        self.songListItem = []
        self.changeSongListItem = []
        
        self.nextIsEnabled = false
        self.previousIsEnabled = false
        self.totalSecond = 0
        self.currentSecond = 0
        self.bufferProgress = 0
        
        self.changeValueCallBackClouser.forEach({ $0?() })
        
        guard isMPRemoteCommandCenterEnable else { return }

        MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = false
        MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = false
        MPRemoteCommandCenter.shared().playCommand.isEnabled = false
        
            
    }
    
    private func nextPreviousPlaying(_ nextPreviousButtonClicked: Bool?, playIndex: Int?, isChangeIndexForceFull: Bool = false) {
        
        var idx: Int = 0
        
        if let getPlayIndex = playIndex {
            idx = getPlayIndex
        } else {
            
            guard self.changeSongListItem.count != 0 else { return }
            
            if let currentSongStr = self.currentSongString {
                
                if let indx = self.changeSongListItem.firstIndex(where: { $0.url.absoluteString == currentSongStr }) {
                    //$0.url.removeSchema_CachingPlayerString
                    idx = indx
                }
                
            }
        }
        
        var checkCondition = true
        
        if let getNextPreviousButtonClicked = nextPreviousButtonClicked {
            idx = getNextPreviousButtonClicked ? idx + 1 : idx - 1
            checkCondition = getNextPreviousButtonClicked ? ((idx >= 0) && (idx <= (self.changeSongListItem.count - 1))) : ((idx >= 0) && (idx <= (self.changeSongListItem.count - 1)))
        } else {
            
            if !isChangeIndexForceFull {    // this case is called when listing to direct play at perticular index of using `playAtSongIndex` function.
                switch self.repeatMode {
                case .none:
                    return
                case .one:
                    
                    if self.musicPlayer != nil, self.musicPlayer?.currentItem != nil {
                        self.currentSecond = 0
                        self.changeValueCallBackClouser.forEach({ $0?() })
                        self.musicPlayer?.currentItem?.seek(to: CMTime(seconds: 0, preferredTimescale: 1), completionHandler: { (bool) in
                            self.musicPlayer?.play()
                            
                            self.playPauseChangeClouser.forEach({ $0?() })
                        })
                    }
                    return
                case .all:
                    break
                }
            }
        }
        
        
        if let mPlayer = self.musicPlayer, self.changeSongListItem.indices.contains(idx) {
            
            mPlayer.pause()
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: mPlayer.currentItem)
            mPlayer.removeObserver(self, forKeyPath: "status", context: nil)
            mPlayer.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty", context: nil)
            mPlayer.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: nil)
            mPlayer.currentItem?.removeObserver(self, forKeyPath: "playbackBufferFull", context: nil)
            if let observer = self.addPeriodicTimeObserver {
                self.musicPlayer?.removeTimeObserver(observer)
                self.addPeriodicTimeObserver = nil
            }
            self.musicPlayer = nil
        }
        
        guard self.changeSongListItem.indices.contains(idx) else {
            self.musicPlayer?.pause()
            self.musicPlayer?.currentItem?.seek(to: CMTime(seconds: 0, preferredTimescale: 1), completionHandler: { (bool) in
                
            })
            self.currentSecond = 0
            self.changeValueCallBackClouser.forEach({ $0?() })
            self.playPauseChangeClouser.forEach({ $0?() })
            return
        }
        
        self.nextIsEnabled = !(idx == (self.changeSongListItem.count - 1))
        self.previousIsEnabled = !(idx == 0)
        self.nextIsEnabledChangeClouser.forEach({ $0?(self.nextIsEnabled) })
        self.previousIsEnabledChangeClouser.forEach({ $0?(self.previousIsEnabled) })
        
        self.totalSecond = 0
        self.currentSecond = 0
        self.bufferProgress = 0
        
        
        self.changeValueCallBackClouser.forEach({ $0?() })
        
        if checkCondition {
            
//            let avPlayerItem = AVPlayerItem(url: self.changeSongListItem[idx].url)
            let avPlayerItem = CachingPlayerItem(playerURL: self.changeSongListItem[idx].url)
            avPlayerItem.delegate = self
                
            self.error = nil
            musicPlayer = AVPlayer(playerItem: avPlayerItem)
            musicPlayer?.automaticallyWaitsToMinimizeStalling = false
            musicPlayer?.allowsExternalPlayback = false
            musicPlayer?.isMuted = false
            musicPlayer?.volume = 1.0
            musicPlayer?.addObserver(self, forKeyPath: "status", context: nil)
            musicPlayer?.currentItem?.addObserver(self, forKeyPath: "playbackBufferEmpty", options: .new, context: nil)
            musicPlayer?.currentItem?.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: .new, context: nil)
            musicPlayer?.currentItem?.addObserver(self, forKeyPath: "playbackBufferFull", options: .new, context: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(avPlayerDidFinish), name: .AVPlayerItemDidPlayToEndTime, object: avPlayerItem)
            self.avPlayerBufferingClouser.forEach({ $0?(true) })
            
            addPeriodicTime()
            
        }
        
        if self.isMPRemoteCommandCenterEnable {
            MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = self.nextIsEnabled
            MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = self.previousIsEnabled
            self.setupMPRemoteCommandSetupAndImage(nil)
        }
    }
    
    private func addPeriodicTime() {
//        let interval = CMTime(value: 1, timescale: 2)
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        if let mPlayer = self.musicPlayer {
            self.addPeriodicTimeObserver = mPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main, using: { [weak self] (progressTime) in
                
                guard let `self` = self else { return }
                
                if let duration = mPlayer.currentItem?.duration, duration.seconds > 0  {
                    
                    self.totalSecond = Double(CMTimeGetSeconds(duration))
                    
                    let currentTime = CMTimeGetSeconds(mPlayer.currentTime())
                    
                    self.currentSecond = Double(currentTime)
                    
                    if self.isMPRemoteCommandCenterEnable {
                        var nowPlayingInfoDict = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        
                        nowPlayingInfoDict[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.currentSecond
                        nowPlayingInfoDict[MPMediaItemPropertyPlaybackDuration] = duration.seconds
                        
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfoDict
                    }
                    
                    
                    if let range = mPlayer.currentItem?.loadedTimeRanges.first {
                        let timeRange = range.timeRangeValue
                        
                        let bufferState = Double(CMTimeGetSeconds(timeRange.duration))
                        
                        self.bufferProgress = Float(bufferState / self.totalSecond)
                    }
                    
                }
                self.changeValueCallBackClouser.forEach({ $0?() })
            })
        }
    }
    
    @objc private func avPlayerDidFinish(_ notification: NSNotification) {
        
        self.avPlayerDidEndFinishTimeClouser.forEach({ $0?() })
        
        switch self.repeatMode {
        case .none:
            self.currentSecond = 0
            self.changeValueCallBackClouser.forEach({ $0?() })
            self.musicPlayer?.currentItem?.seek(to: CMTime(seconds: 0, preferredTimescale: 1), completionHandler: { (bool) in
                
                self.playPauseChangeClouser.forEach({ $0?() })
            })
        case .one:
            nextPreviousPlaying(nil, playIndex: nil)
        case .all:
            nextPreviousPlaying(true, playIndex: nil)
        }
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if let mPlayer = self.musicPlayer {
            
            switch mPlayer.status {
            case .failed:
                self.error = mPlayer.error
                debugPrint("mPlayer.error => ", mPlayer.error ?? "-")
                if self.isMPRemoteCommandCenterEnable {
                    MPNowPlayingInfoCenter.default().playbackState = .stopped
                }
                
                self.avPlayerBufferingClouser.forEach({ $0?(false) })
                return
            case .unknown:
                self.error = nil
                
                if self.isMPRemoteCommandCenterEnable {
                    MPNowPlayingInfoCenter.default().playbackState = .unknown
                }
                
            case .readyToPlay:
                self.error = nil
                if isFirstTimePlayingPause {
                    mPlayer.play()
                }
                
                if self.isMPRemoteCommandCenterEnable {
                    MPNowPlayingInfoCenter.default().playbackState = isFirstTimePlayingPause ? .playing : .paused
                }
                
            @unknown default:
                self.error = nil
                
                if self.isMPRemoteCommandCenterEnable {
                    MPNowPlayingInfoCenter.default().playbackState = .stopped
                }
            }
            
            if mPlayer.currentItem?.isPlaybackLikelyToKeepUp ?? false {
                debugPrint("Playing")
                self.avPlayerBufferingClouser.forEach({ $0?(false) })
            } else if mPlayer.currentItem?.isPlaybackBufferEmpty ?? false {
                debugPrint("Buffer empty - show loader")
                self.avPlayerBufferingClouser.forEach({ $0?(true) })
            }  else if mPlayer.currentItem?.isPlaybackBufferFull ?? false {
                debugPrint("Buffer full - hide loader")
                self.avPlayerBufferingClouser.forEach({ $0?(false) })
            } else {
                debugPrint("Buffering")
                self.avPlayerBufferingClouser.forEach({ $0?(true) })
            }
        }
    }
    
    
    
}

extension AudioMusicPlayer: CachingPlayerItemDelegate {
    
    func playerItem(_ playerItem: CachingPlayerItem, didFinishDownloadingFileAt filePath: String) {
        debugPrint(#function)
        debugPrint(filePath)
    }
    
    func playerItem(_ playerItem: CachingPlayerItem, didDownloadBytesSoFar bytesDownloaded: Int, outOf bytesExpected: Int) {
        debugPrint(#function)
        debugPrint(bytesDownloaded, bytesExpected)
    }
    
    func playerItem(_ playerItem: CachingPlayerItem, downloadingFailedWith error: Error) {
        debugPrint(#function)
        debugPrint(error)
    }
    
    func playerItemReadyToPlay(_ playerItem: CachingPlayerItem) {
        debugPrint(#function)
    }
    
    func playerItemUnknown(_ playerItem: CachingPlayerItem) {
        debugPrint(#function)
    }
    
    func playerItemDidFailToPlay(_ playerItem: CachingPlayerItem, withError error: Error?) {
        debugPrint(#function)
        debugPrint(error ?? "-")
        
        self.error = self.musicPlayer?.error
        debugPrint("mPlayer.error => ", self.musicPlayer?.error ?? "-")
        if self.isMPRemoteCommandCenterEnable {
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.avPlayerBufferingClouser.forEach({ $0?(false) })
        }
        
    }
    
    func playerItemPlaybackStalled(_ playerItem: CachingPlayerItem) {
        debugPrint(#function)
    }
    
    
}


extension AudioMusicPlayer {
    
    fileprivate func arrayListShuffle<T>(_ array: [T]) -> [T] {
        var newArray = array
        let n = array.count
        for i in (1..<n).reversed() {
            let j = Int(arc4random_uniform(UInt32(i + 1)))
            if i != j {
                newArray.swapAt(i, j)
            }
        }
        
        return newArray
    }
}


class SongListItem: NSObject {
    //MARK:- Variables
    let urlString: String
    let songTitleName: String
    let songArtistName: String
    let songImageString: String
    let url: URL
    var img: UIImage?
    var anyItem: Any?
    
    //MARK:- Initializer
    init?(_urlString: String, _songTitleName: String, _songArtistName: String, _songImageString: String) {
        self.urlString = _urlString
        self.songTitleName = _songTitleName
        self.songArtistName = _songArtistName
        self.songImageString = _songImageString
        
        guard let setURL = URL(string: _urlString.trimmingCharacters(in: .whitespaces)) ?? URL(string: _urlString.trimmingCharacters(in: .whitespaces).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? _urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        
        self.url = setURL
    }
    
}
