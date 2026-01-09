//
//  AudioMusicPlayer+CachingPlayerItem.swift
//  PrpAudioPlayer
//
//  Created by Pradip on 30/12/25.
//

import UIKit


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
