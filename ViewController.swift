//
//  ViewController.swift
//  MusicPlayerDemo
//
//  Created by Pradip on 15/09/23.
//

import UIKit
import SDWebImage

class ViewController: UIViewController {

    @IBOutlet var imgView: UIImageView!
    @IBOutlet var lblTitle: UILabel!
    @IBOutlet var lblDescription: UILabel!
    @IBOutlet var lblMinimumTime: UILabel!
    @IBOutlet var lblMaximumTime: UILabel!
    @IBOutlet var playerSlider: ProgressSlider!
    
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet var btnPlayPause: UIButton!
    @IBOutlet var btnNext: UIButton!
    @IBOutlet var btnPrevious: UIButton!
    @IBOutlet var btnShuffle: UIButton!
    @IBOutlet var btnRepeat: UIButton!
    
    @IBOutlet var lblSongs: UILabel!
    
    var songList: [MusicJsonModel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playerSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        
        
        if let jsonData = convertToDictionary(text: musicJsonString) as? [String: Any],
           let musicArray = jsonData["data"] as? [[String: Any]] {
            self.songList = musicArray.map({ MusicJsonModel(dataJson: $0) })
            for idx in 0..<self.songList.count {
                self.songList[idx].music_title = "\(idx + 1). \(self.songList[idx].music_title)"
            }
        }
        
        AudioMusicPlayer.sharedInstance.nextIsEnabledChangeClouser = { (nwBool) in
            self.btnNext.isEnabled = nwBool
        }
        AudioMusicPlayer.sharedInstance.previousIsEnabledChangeClouser = { (nwBool) in
            self.btnPrevious.isEnabled = nwBool
        }
        
        if self.songList.count > 0 {
            let items = self.songList.compactMap({ SongListItem(_urlString: $0.music_path, _songTitleName: $0.music_title, _songArtistName: $0.music_singer, _songImageString: $0.music_thumbnail) })
            
            AudioMusicPlayer.sharedInstance.setupMusicPlayer(_songListItem: items, _playIndex: 0, isFirstTimePlayingPause: true)
            AudioMusicPlayer.sharedInstance.setupNowPlayingInfoCenter(isEnable: true)
        
            self.lblTitle.text = self.songList[0].music_title
            self.lblDescription.text = self.songList[0].music_singer
            
            let musicURL = AudioMusicPlayer.sharedInstance.songListItem[0].url.absoluteString
            
            self.imgView.downloadImage(with: self.songList[0].music_thumbnail, completed: { img, err, url in
                AudioMusicPlayer.sharedInstance.setupMPRemoteCommandSetupAndImage((musicURL, img))
            })
            
//            let largeConfig = UIImage.SymbolConfiguration(scale: .large)
            let largeConfig = UIImage.SymbolConfiguration(pointSize: 200, weight: .heavy, scale: .large)
            btnPlayPause.setImage(UIImage(systemName: "pause.circle.fill", withConfiguration: largeConfig), for: .normal)
            
            
            avPlayerBufferingClouser(isBuffering: true)
        }
        
        
        AudioMusicPlayer.sharedInstance.changeValueCallBackClouser = self.changeValueCallBackClouser
        AudioMusicPlayer.sharedInstance.avPlayerDidEndFinishTimeClouser = self.avPlayerDidEndFinishTimeClouser
        AudioMusicPlayer.sharedInstance.playPauseChangeClouser = self.playPauseChangeClouser
        AudioMusicPlayer.sharedInstance.changeMpPlayerNextPreviousClouser = self.changeMpPlayerNextPreviousClouser
        AudioMusicPlayer.sharedInstance.avPlayerBufferingClouser = self.avPlayerBufferingClouser
        
        self.btnShuffle.isEnabled = AudioMusicPlayer.sharedInstance.isAccessSuffleMode
        self.btnRepeat.isEnabled = AudioMusicPlayer.sharedInstance.isAccessRepeatMode
        self.btnRepeat.any_value_store_property = AudioMusicPlayer.sharedInstance.repeatMode
        
        var fullString = ""
        
        AudioMusicPlayer.sharedInstance.changeSongListItem.forEach({
//            fullString += "\(Unmanaged.passUnretained($0).toOpaque())\n"
            fullString += "\($0.songTitleName)\n"
        })
        
        lblSongs.text = fullString
        
        self.activityIndicatorView.layer.masksToBounds = true
        self.activityIndicatorView.layer.cornerRadius = 11
    }
    
    @objc private func avPlayerBufferingClouser(isBuffering: Bool) {
        isBuffering ? self.activityIndicatorView.startAnimating() : self.activityIndicatorView.stopAnimating()
        self.btnPlayPause.isHidden = isBuffering
    }
    
    @objc private func changeValueCallBackClouser() {
        self.lblMaximumTime.text = self.timeString(time: AudioMusicPlayer.sharedInstance.totalSecond)
        self.playerSlider.maximumValue = Float(AudioMusicPlayer.sharedInstance.totalSecond)
        if self.playerSlider.accessibilityHint == nil {
            self.playerSlider.value = Float(AudioMusicPlayer.sharedInstance.currentSecond)
            self.lblMinimumTime.text = self.timeString(time: AudioMusicPlayer.sharedInstance.currentSecond)
        }
        self.playerSlider.playableProgress = Float(AudioMusicPlayer.sharedInstance.bufferProgress)
        
//        let formatter = DateComponentsFormatter()
//        formatter.allowedUnits = [.hour, .minute, .second, .nanosecond]
//        formatter.unitsStyle = .full
//        debugPrint("AudioMusicPlayer.sharedInstance.totalSecond => ",formatter.string(from: AudioMusicPlayer.sharedInstance.totalSecond) ?? "")
    }
    
    @objc private func avPlayerDidEndFinishTimeClouser() {
        self.playerSlider.value = 0
        self.playerSlider.progressBarAnimatedProgress = false
        self.playerSlider.playableProgress = 0
        self.playerSlider.progressBarAnimatedProgress = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let currentSongString = AudioMusicPlayer.sharedInstance.currentSongString,
               let indx = AudioMusicPlayer.sharedInstance.songListItem.firstIndex(where: { $0.url.absoluteString == currentSongString }) {
                
                self.lblTitle.text = self.songList[indx].music_title
                self.lblDescription.text = self.songList[indx].music_singer
                
                let musicURL = AudioMusicPlayer.sharedInstance.songListItem[indx].url.absoluteString
                
                self.imgView.downloadImage(with: self.songList[indx].music_thumbnail, completed: { img, err, url in
                    AudioMusicPlayer.sharedInstance.setupMPRemoteCommandSetupAndImage((musicURL, img))
                })
            }
        }
    }
    
    @objc private func playPauseChangeClouser() {
        let imageName = AudioMusicPlayer.sharedInstance.isPlaying ? "pause.circle.fill" : "play.circle.fill"
//        let largeConfig = UIImage.SymbolConfiguration(scale: .large)
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 200, weight: .heavy, scale: .large)
        btnPlayPause.setImage(UIImage(systemName: imageName, withConfiguration: largeConfig), for: .normal)
    }
    
    @objc private func changeMpPlayerNextPreviousClouser() {
        if let currentSongString = AudioMusicPlayer.sharedInstance.currentSongString,
           let indx = AudioMusicPlayer.sharedInstance.songListItem.firstIndex(where: { $0.url.absoluteString == currentSongString }) {
            
            self.lblTitle.text = self.songList[indx].music_title
            self.lblDescription.text = self.songList[indx].music_singer
            
            let musicURL = AudioMusicPlayer.sharedInstance.songListItem[indx].url.absoluteString
            
            self.imgView.downloadImage(with: self.songList[indx].music_thumbnail, completed: { img, err, url in
                AudioMusicPlayer.sharedInstance.setupMPRemoteCommandSetupAndImage((musicURL, img))
            })
        }
    }
    
    
    @IBAction func btnShuffleClicked(sender: UIButton) {
        if AudioMusicPlayer.sharedInstance.changeSuffleMode(!sender.isSelected) {
            sender.isSelected.toggle()
            let largeConfig = UIImage.SymbolConfiguration(pointSize: 200, weight: .heavy, scale: .large)
            sender.setImage(UIImage(systemName: sender.isSelected ? "shuffle.circle.fill" : "shuffle.circle", withConfiguration: largeConfig), for: .normal)
        }

        var fullString = ""
        
        AudioMusicPlayer.sharedInstance.changeSongListItem.forEach({
//            fullString += "\(Unmanaged.passUnretained($0).toOpaque())\n"
            fullString += "\($0.songTitleName)\n"
        })
        
        lblSongs.text = fullString
    }
    
    @IBAction func btnRepeatClicked(sender: UIButton) {
        
        let repeatMode = self.btnRepeat.any_value_store_property as? AudioMusicPlayer.AudioMusicPlayerRepeatMode ?? .all
        
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 200, weight: .heavy, scale: .large)
        
        switch repeatMode {
        case .none:
            AudioMusicPlayer.sharedInstance.changeRepeatMode(.all)
            sender.setImage(.init(systemName: "repeat.circle.fill", withConfiguration: largeConfig), for: .normal)
            sender.tintColor = .init(red: 0, green: 122/255, blue: 1, alpha: 1)
        case .one:
            AudioMusicPlayer.sharedInstance.changeRepeatMode(.none)
            sender.setImage(.init(systemName: "repeat", withConfiguration: largeConfig), for: .normal)
            sender.tintColor = .label
        case .all:
            AudioMusicPlayer.sharedInstance.changeRepeatMode(.one)
            sender.setImage(.init(systemName: "repeat.1.circle", withConfiguration: largeConfig), for: .normal)
            sender.tintColor = .init(red: 0, green: 122/255, blue: 1, alpha: 1)
        }
        
        self.btnRepeat.any_value_store_property = AudioMusicPlayer.sharedInstance.repeatMode
        
    }
    
    @IBAction func btnPreviousClicked(sender: UIButton) {
        AudioMusicPlayer.sharedInstance.nextPreviousPlaying(false, playIndex: nil)
        
        if let currentSongString = AudioMusicPlayer.sharedInstance.currentSongString,
           let indx = AudioMusicPlayer.sharedInstance.songListItem.firstIndex(where: { $0.url.absoluteString == currentSongString }) {
            
            self.lblTitle.text = self.songList[indx].music_title
            self.lblDescription.text = self.songList[indx].music_singer
            
            let musicURL = AudioMusicPlayer.sharedInstance.songListItem[indx].url.absoluteString
            
            self.imgView.downloadImage(with: self.songList[indx].music_thumbnail, completed: { img, err, url in
                AudioMusicPlayer.sharedInstance.setupMPRemoteCommandSetupAndImage((musicURL, img))
            })
        }
    }
    
    @IBAction func btnNextClicked(sender: UIButton) {
        AudioMusicPlayer.sharedInstance.nextPreviousPlaying(true, playIndex: nil)
        
        if let currentSongString = AudioMusicPlayer.sharedInstance.currentSongString,
           let indx = AudioMusicPlayer.sharedInstance.songListItem.firstIndex(where: { $0.url.absoluteString == currentSongString }) {
            
            self.lblTitle.text = self.songList[indx].music_title
            self.lblDescription.text = self.songList[indx].music_singer
            
            let musicURL = AudioMusicPlayer.sharedInstance.songListItem[indx].url.absoluteString
            
            self.imgView.downloadImage(with: self.songList[indx].music_thumbnail, completed: { img, err, url in
                AudioMusicPlayer.sharedInstance.setupMPRemoteCommandSetupAndImage((musicURL, img))
            })
        }
    }
    
    @IBAction func btnPlayPauseClicked(sender: UIButton) {
        
        AudioMusicPlayer.sharedInstance.playPauseCommand()
        
        let imageName = AudioMusicPlayer.sharedInstance.isPlaying ? "pause.circle.fill" : "play.circle.fill"
//        let largeConfig = UIImage.SymbolConfiguration(scale: .large)
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 200, weight: .heavy, scale: .large)
        self.btnPlayPause.setImage(UIImage(systemName: imageName, withConfiguration: largeConfig), for: .normal)
        
    }
    
    @objc func sliderValueChanged(sender: UISlider, forEvent event: UIEvent) {
        if AudioMusicPlayer.sharedInstance.musicPlayer?.currentItem?.duration.seconds == nil {
            return
        }
        
        guard let touchEvent = event.allTouches?.first else { return }
        
        switch (touchEvent.phase) {
        case .began:
            // whenever a finger touches the surface.
            
            sender.accessibilityHint = "draging"
            self.lblMinimumTime.text = self.timeString(time: Double(sender.value))
            
        case .moved:
            // whenever a finger moves on the surface.
            sender.accessibilityHint = "draging"
            self.lblMinimumTime.text = self.timeString(time: Double(sender.value))
            
        case .ended:
            // whenever a finger leaves the surface.
            AudioMusicPlayer.sharedInstance.musicPlayerSetSeek(sliderValue: sender.value) {
                sender.accessibilityHint = nil
            }
            
        case .stationary:
            // whenever a finger is touching the surface but hasn't moved since the previous event.
            AudioMusicPlayer.sharedInstance.musicPlayerSetSeek(sliderValue: sender.value) {
                sender.accessibilityHint = nil
            }
            
        default:
            AudioMusicPlayer.sharedInstance.musicPlayerSetSeek(sliderValue: sender.value) {
                sender.accessibilityHint = nil
            }
        }
        
        
       
        
    }
    
    func timeString(time: TimeInterval) -> String {
        let hour = Int(time) / 3600
        let minute = Int(time) / 60 % 60
        let second = Int(time) % 60
        
        // return formated string
        
        if hour > 0 {
            return String(format: "%02i:%02i:%02i", hour, minute, second)
        }
        return String(format: "%02i:%02i", minute, second)
    }
    
}


struct MusicJsonModel {
    var music_singer: String
    var music_thumbnail: String
    var music_path: String
    var music_title: String
    
    init(dataJson: [String:Any]) {
        self.music_singer = dataJson["music_singer"] as? String ?? ""
        self.music_thumbnail = dataJson["music_thumbnail"] as? String ?? ""
        self.music_path = dataJson["music_path"] as? String ?? ""
        self.music_title = dataJson["music_title"] as? String ?? ""
    }
}

func convertToDictionary(text: String) -> Any? {
    if let data = text.data(using: .utf8) {
        do {
            return try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            print(error.localizedDescription)
        }
    }
    return nil
}


var musicJsonString = """
{
  "data" : [
    
    {
      "music_singer" : "Arijit Singh",
      "music_thumbnail" : "https://www.pagalworld.com.cm/siteuploads/thumb/sft138/68671_4.jpg",
        "music_path" : "https://www.pagalworld.com.cm/files/download/id/68671",
      "music_title" : "O Mahi O Mahi"
    },
    {
      "music_singer" : "Jasleen Royal, Arijit Singh",
      "music_thumbnail" : "https://www.pagalworld.com.cm/siteuploads/thumb/sft135/67444_4.jpg",
        "music_path" : "https://www.pagalworld.com.cm/files/download/id/67444",
      "music_title" : "Heeriye"
    },
    {
      "music_singer" : "Danny",
      "music_thumbnail" : "https://www.pagalworld.com.cm/siteuploads/thumb/sft140/69987_4.jpg",
        "music_path" : "https://www.pagalworld.com.cm/files/download/id/69987",
      "music_title" : "Ve Haniya"
    },
    {
      "music_singer" : "King",
      "music_thumbnail" : "https://www.pagalworld.com.cm/siteuploads/thumb/sft130/64630_4.jpg",
        "music_path" : "https://www.pagalworld.com.cm/files/download/id/64630",
      "music_title" : "Maan Meri Jaan"
    },
    {
      "music_singer" : "Aur",
      "music_thumbnail" : "https://www.pagalworld.com.cm/siteuploads/thumb/sft141/70390_4.jpg",
        "music_path" : "https://www.pagalworld.com.cm/files/download/id/70390",
      "music_title" : "Tu Hai Kahan"
    },
    {
      "music_singer" : "Mohammad Faiz",
      "music_thumbnail" : "https://www.pagalworld.com.cm/siteuploads/thumb/sft137/68453_4.jpg",
        "music_path" : "https://www.pagalworld.com.cm/files/download/id/68453",
      "music_title" : "Kabhi Shaam Dhale"
    },
    {
      "music_singer" : "Saad Lamjarred, Shreya Ghoshal",
      "music_thumbnail" : "https://www.pagalworld.com.cm/siteuploads/thumb/sft135/67064_4.jpg",
        "music_path" : "https://www.pagalworld.com.cm/files/download/id/67064",
      "music_title" : "Guli Mata"
    },
    {
      "music_singer" : "Live",
      "music_thumbnail" : "",
        "music_path" : "https://paglasongs.com/files/download/id/15519",
      "music_title" : "Live"
    }
  ]
}
"""




extension UIImageView {
    
    func downloadImage(with string: String?, placeholderImage: UIImage? = nil, options: SDWebImageOptions = .continueInBackground, progess: SDImageLoaderProgressBlock? = nil, completed: ((UIImage?, Error?, URL?) -> Void)? = nil) {
            
            self.image = nil
            
            guard let getImageString = string?.trimmingCharacters(in: .whitespacesAndNewlines),
                  getImageString.count > 0 else {
                self.image = placeholderImage
                return
            }
            
            let url = URL(string: getImageString) ?? URL(string: getImageString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
            
            self.sd_imageIndicator = SDWebImageActivityIndicator.grayLarge
            
            self.sd_setImage(with: url, placeholderImage: placeholderImage, options: options, progress: progess) { [weak self] (getImage, getError, sdImageType, getUrl) in
                if getImage == nil {
                    self?.image = placeholderImage
                    completed?(placeholderImage, getError, getUrl)
                } else {
                    completed?(getImage, getError, getUrl)
                }
            }
        }
    
}


extension NSObject {
    
    private struct NSObject_Associated_Keys {
        static var any_Value_store_Key = Int.random(in: -100000 ..< -101)
    }

    /**
     Any value store for hint.
     */
    @objc public var any_value_store_property: Any? {
        get {
            return objc_getAssociatedObject(self, &NSObject_Associated_Keys.any_Value_store_Key)
        }
        set(newValue) {
            objc_setAssociatedObject(self, &NSObject_Associated_Keys.any_Value_store_Key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
