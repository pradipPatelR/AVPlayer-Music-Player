//
//  MusicListItem.swift
//  PrpAudioPlayer
//
//  Created by Pradip on 09/01/26.
//

import Foundation


struct MusicListItem: Codable {
    let music_singer: String
    let music_thumbnail: String
    let music_path: String
    let music_title: String
    let isLocalFile: Bool?
}
