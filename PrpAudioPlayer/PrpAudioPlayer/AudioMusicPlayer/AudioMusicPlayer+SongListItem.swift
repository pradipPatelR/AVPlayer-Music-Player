//
//  AudioMusicPlayer+SongListItem.swift
//  PrpAudioPlayer
//
//  Created by Pradip on 30/12/25.
//


import UIKit


class SongListItem: NSObject {
    //MARK:- Variables
    var urlString: String
    let songTitleName: String
    let songArtistName: String
    let songImageString: String
    let url: URL
    var img: UIImage?
    var anyItem: Any?
    var isLocalFile: Bool
    
    //MARK:- Initializer
    init?(_urlString: String, _songTitleName: String, _songArtistName: String, _songImageString: String, _isLocalFile: Bool) {
        self.urlString = _urlString
        self.songTitleName = _songTitleName
        self.songArtistName = _songArtistName
        self.songImageString = _songImageString
        self.isLocalFile = _isLocalFile
        
        if _isLocalFile {
            let urlStrings = _urlString.components(separatedBy: ".")
            if let mp3url = Bundle.main.url(forResource: urlStrings.first ?? "", withExtension: urlStrings.last ?? "") {
                self.url = mp3url
                self.urlString = mp3url.absoluteString
            } else {
                if #available(iOS 16.0, *) {
                    self.url = URL.init(filePath: _urlString)
                } else {
                    self.url = URL.init(fileURLWithPath: _urlString)
                }
            }
            
        } else {
            guard let setURL = URL(string: _urlString) ??
                    URL(string: _urlString.trimmingCharacters(in: .whitespaces)) ??
                    URL(string: _urlString.trimmingCharacters(in: .whitespaces).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? _urlString.trimmingCharacters(in: .whitespaces)) ??
                    URL(string: _urlString.trimmingCharacters(in: .whitespacesAndNewlines)) ??
                    URL(string: _urlString.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? _urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            
            self.url = setURL
        }
    }
    
}
