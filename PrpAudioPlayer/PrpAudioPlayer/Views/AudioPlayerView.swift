//
//  AudioPlayerView.swift
//  PrpAudioPlayer
//
//  Created by Pradip on 30/12/25.
//

import SwiftUI
import SDWebImageSwiftUI

struct AudioPlayerView: View {
    
    @StateObject private var viewModel = PlayerViewModel()
    
    @State private var isSuffle = false
    @State private var isEnabledSuffleMode = false
    @State private var repeatImageName = "repeat.circle.fill"
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                WebImage(url: URL(string: viewModel.currentSongItem?.songImageString ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .onSuccess(perform: { platformImage, tData, sdImageCacheType in
                    if let musicURL = viewModel.currentSongItem?.url.absoluteString,
                       let gData = tData,
                       let getImage = UIImage(data: gData) {
                        AudioMusicPlayer.sharedInstance.setupMPRemoteCommandSetupAndImage((musicURL, getImage))
                    }
                })
                .indicator(.activity) // Activity Indicator
                .transition(.fade(duration: 0.5))
                .frame(width: geometry.size.width * 0.35,
                       height: geometry.size.width * 0.35)
                .clipShape(Circle())
                .padding(.top, 20)
                .padding(.bottom, 14)
                
                VStack {
                    Text(viewModel.currentSongItem?.songTitleName ?? "N/A")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 2)
                    Text(viewModel.currentSongItem?.songArtistName ?? "N/A")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
                
                VStack {
                    AdvancedMusicSlider(currentTime: $viewModel.value, duration: $viewModel.totalValue, bufferedTime: $viewModel.bufferValue) { isDragg, currentSecond in
                        viewModel.isDragging = isDragg
                        if !isDragg {
                            viewModel.value = currentSecond
                            viewModel.isDragging = true
                            AudioMusicPlayer.sharedInstance.musicPlayerSetSeek(sliderValue: Float(currentSecond)) {
                                viewModel.isDragging = false
                            }
                        }
                    }
                    .frame(width: geometry.size.width,
                               height: 40)
                }
                .padding(.bottom, 30)
                
                HStack(alignment: .center, spacing: 15) {
                    // Shuffle button
                    Button(action: {
                        debugPrint("Shuffle tapped")
                        if AudioMusicPlayer.sharedInstance.changeSuffleMode(!self.isSuffle) {
                            self.isSuffle.toggle()
                        } else {
                            self.isSuffle = false
                        }
                    }) {
                        Image(systemName: self.isSuffle ? "shuffle.circle.fill" : "shuffle")
                            .font(.system(size: 25, weight: .heavy))
                            .foregroundColor(isEnabledSuffleMode ? .blue : .gray)
                    }
                    .disabled(!isEnabledSuffleMode)
                    
                    // Previous/Rewind button
                    Button(action: {
                        debugPrint("Previous tapped")
                        
                        AudioMusicPlayer.sharedInstance.nextPreviousPlaying(false, playIndex: nil)
                        viewModel.currentSongItem = AudioMusicPlayer.sharedInstance.currentSongItem
                        viewModel.isEnabledPreviousButton = AudioMusicPlayer.sharedInstance.previousIsEnabled
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 25))
                            .foregroundColor(viewModel.isEnabledPreviousButton ? .blue : .gray)
                    }
                    .disabled(!viewModel.isEnabledPreviousButton)
                    
                    // Play button
                    Button(action: {
                        debugPrint("Play tapped")
                        AudioMusicPlayer.sharedInstance.playPauseCommand()
                        
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 50, height: 50)
                            
                            if AudioMusicPlayer.sharedInstance.isPlaying,
                               viewModel.isBuffering {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            } else {
                                Image(systemName: AudioMusicPlayer.sharedInstance.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 25))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // Next/Forward button
                    Button(action: {
                        debugPrint("Next tapped")
                        
                        AudioMusicPlayer.sharedInstance.nextPreviousPlaying(true, playIndex: nil)
                        viewModel.currentSongItem = AudioMusicPlayer.sharedInstance.currentSongItem
                        viewModel.isEnabledNextButton = AudioMusicPlayer.sharedInstance.nextIsEnabled
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 25))
                            .foregroundColor(viewModel.isEnabledNextButton ? .blue : .gray)
                    }
                    .disabled(!viewModel.isEnabledNextButton)
                    
                    // Repeat button
                    Button(action: {
                        debugPrint("Repeat tapped")
                        switch AudioMusicPlayer.sharedInstance.repeatMode {
                        case .none:
                            AudioMusicPlayer.sharedInstance.changeRepeatMode(.all)
                            self.repeatImageName = "repeat.circle.fill"
                        case .one:
                            AudioMusicPlayer.sharedInstance.changeRepeatMode(.none)
                            self.repeatImageName = "repeat"
                        case .all:
                            AudioMusicPlayer.sharedInstance.changeRepeatMode(.one)
                            self.repeatImageName = "repeat.1"
                        }
                    }) {
                        
                        Image(systemName: repeatImageName)
                            .font(.system(size: 25, weight: .heavy))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 30)
                

                List(0..<AudioMusicPlayer.sharedInstance.changeSongListItem.count, id: \.self) { idx in
                    let itm = AudioMusicPlayer.sharedInstance.changeSongListItem[idx]
                    let isPlaying = itm.urlString == AudioMusicPlayer.sharedInstance.currentSongItem?.urlString
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        VStack(alignment: .leading, spacing: 5, content: {
                            Text(itm.songTitleName)
                                .font(.title)
                                .fontWeight(.regular)
                                .multilineTextAlignment(.leading)
                            Text(itm.songArtistName)
                                .font(.title2)
                                .fontWeight(.thin)
                                .italic()
                                .multilineTextAlignment(.leading)
                        })
                        if isPlaying {
                            Spacer()
                            Image(systemName: AudioMusicPlayer.sharedInstance.isPlaying ? "play.fill" : "pause.fill")
                                .font(.system(size: 25))
                                .foregroundColor(.accentColor)
                        }
                    }.onTapGesture {
                        
                    }
                    
                }
                .listStyle(.plain)
                .listRowInsets(.init(top: 0, leading: 0, bottom: geometry.safeAreaInsets.bottom, trailing: 0))
            }
            .frame(maxWidth: .infinity)
        }
        .task {
            let list = loadJsonData()
            audioPlayerSetup(list)
        }
    }
    
    func loadJsonData() -> [MusicListItem] {
        guard let url = Bundle.main.url(forResource: "MusicList", withExtension: "json") else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: url)
            let list = try JSONDecoder().decode([MusicListItem].self, from: data)
            return list
        } catch {
            debugPrint(error)
        }
        return []
    }
    
    func audioPlayerSetup(_ list: [MusicListItem]) {
        
        viewModel.bindPlayer()
        
        switch AudioMusicPlayer.sharedInstance.repeatMode {
        case .all:
            repeatImageName = "repeat.circle.fill"
        case .none:
            repeatImageName = "repeat"
        case .one:
            repeatImageName = "repeat.1.circle"
        }
        
        let items = list.compactMap({ SongListItem(_urlString: $0.music_path, _songTitleName: $0.music_title, _songArtistName: $0.music_singer, _songImageString: $0.music_thumbnail, _isLocalFile: $0.isLocalFile ?? false) })
        
        AudioMusicPlayer.sharedInstance.setupMusicPlayer(_songListItem: items, _playIndex: 0, isFirstTimePlayingPause: true)
        AudioMusicPlayer.sharedInstance.setupNowPlayingInfoCenter(isEnable: true)
    
        viewModel.currentSongItem = AudioMusicPlayer.sharedInstance.currentSongItem
        
        viewModel.isBuffering = true
        
        isEnabledSuffleMode = AudioMusicPlayer.sharedInstance.isAccessSuffleMode
        isSuffle = AudioMusicPlayer.sharedInstance.isSuffle
    }
}

#Preview {
    AudioPlayerView()
}



