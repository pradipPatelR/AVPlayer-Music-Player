//
//  PlayerViewModel.swift
//  PrpAudioPlayer
//
//  Created by Pradip on 09/01/26.
//

import SwiftUI



@MainActor
final class PlayerViewModel: ObservableObject {

    // UI state
    @Published var isEnabledNextButton = false
    @Published var isEnabledPreviousButton = false
    @Published var isBuffering = false
    @Published var currentSongItem: SongListItem?
    @Published var value: Double = 0
    @Published var bufferValue: Double = 0
    @Published var totalValue: Double = 0
    
    var isDragging: Bool = false

    // Subscriptions
    var nextIsEnabledChangeClouser: AudioMusicPlayerEvent<Bool>.Subscription?
    var previousIsEnabledChangeClouser: AudioMusicPlayerEvent<Bool>.Subscription?
    var changeValueCallBackClouser: AudioMusicPlayerEvent<Void>.Subscription?
    var avPlayerDidEndFinishTimeClouser: AudioMusicPlayerEvent<Void>.Subscription?
    var playPauseChangeClouser: AudioMusicPlayerEvent<Void>.Subscription?
    var changeMpPlayerNextPreviousClouser: AudioMusicPlayerEvent<Void>.Subscription?
    var avPlayerBufferingClouser: AudioMusicPlayerEvent<Bool>.Subscription?
    
    
    func bindPlayer() {
        
        nextIsEnabledChangeClouser =
        AudioMusicPlayer.sharedInstance.nextIsEnabledChangeClouser
            .subscribe(owner: self) { value in
                self.isEnabledNextButton = value
            }
        
        previousIsEnabledChangeClouser =
        AudioMusicPlayer.sharedInstance.previousIsEnabledChangeClouser
            .subscribe(owner: self) { value in
                self.isEnabledPreviousButton = value
            }
        
        changeValueCallBackClouser =
        AudioMusicPlayer.sharedInstance.changeValueCallBackClouser
            .subscribe(owner: self) { _ in
                self.totalValue = AudioMusicPlayer.sharedInstance.totalSecond
                if !self.isDragging { self.value = AudioMusicPlayer.sharedInstance.currentSecond }
                self.bufferValue = Double(AudioMusicPlayer.sharedInstance.bufferProgress)
            }
        
        avPlayerBufferingClouser =
        AudioMusicPlayer.sharedInstance.avPlayerBufferingClouser
            .subscribe(owner: self) { buffering in
                self.isBuffering = buffering
            }
        
        avPlayerDidEndFinishTimeClouser =
        AudioMusicPlayer.sharedInstance.avPlayerDidEndFinishTimeClouser
            .subscribe(owner: self) { _ in
                self.isBuffering = true
                self.totalValue = 0
                self.value = 0
                self.bufferValue = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.currentSongItem = AudioMusicPlayer.sharedInstance.currentSongItem
                }
            }
        
        changeMpPlayerNextPreviousClouser =
        AudioMusicPlayer.sharedInstance.avPlayerDidEndFinishTimeClouser
            .subscribe(owner: self) { _ in
                self.currentSongItem = AudioMusicPlayer.sharedInstance.currentSongItem
            }
    }
}



