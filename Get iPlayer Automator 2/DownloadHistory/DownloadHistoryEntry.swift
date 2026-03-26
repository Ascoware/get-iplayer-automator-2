//
//  DownloadHistoryEntry.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/9/23.
//

import Foundation


struct DownloadHistoryEntry : Identifiable, Hashable {
    var id = UUID()
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(pid.hashValue)
//    }

    let pid: String
    let show: String
    let episode: String
    let type: ProgrammeType
    let someNumber: String
    let downloadFormat: String
    let downloadPath: String

    var entryString: String {
        return "\(pid)|\(show)|\(episode)|\(type)|\(someNumber)|\(downloadFormat)|\(downloadPath)"
    }
}
