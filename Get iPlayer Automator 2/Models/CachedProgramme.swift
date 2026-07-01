//
//  CachedProgramme.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 4/4/26.
//

import Foundation

/// Lightweight value type representing a programme read from the on-disk cache.
/// Used only for display in the search/browse UI; does not carry download state.
/// Convert to a queue item with `toQueueItem()` before adding to the download queue.
struct CachedProgramme: Identifiable, Hashable, Comparable {

    let pid: String
    let index: Int
    let type: ProgrammeType
    let name: String
    let episode: String
    let seriesNum: Int
    let episodeNum: Int
    let channel: String
    let available: Date
    let expires: Date?
    let duration: Int
    let desc: String
    let web: URL?
    let thumbnail: URL?
    let timeadded: Date?
    let radio: Bool
    let realPID: String

    var id: String { pid }

    var typeDescription: String {
        switch type {
        case .tv: "BBC TV"
        case .radio: "BBC Radio"
        case .stv: "STV"
        case .abc: "ABC iView"
        }
    }

    static func == (lhs: CachedProgramme, rhs: CachedProgramme) -> Bool {
        lhs.pid == rhs.pid
    }

    static func < (lhs: CachedProgramme, rhs: CachedProgramme) -> Bool {
        lhs.name < rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }

    /// Creates a mutable `Programme` queue item pre-populated from this cache entry.
    @MainActor
    func toQueueItem() -> Programme {
        let p = Programme()
        p.status = .processedPID
        p.index = index
        p.type = type
        p.name = name
        p.episode = episode
        p.seriesNum = seriesNum
        p.episodeNum = episodeNum
        p.pid = pid
        p.channel = channel
        p.available = available
        p.expires = expires
        p.duration = duration
        p.desc = desc
        p.web = web
        p.thumbnail = thumbnail
        p.timeadded = timeadded
        p.radio = radio
        p.realPID = realPID
        return p
    }
}
