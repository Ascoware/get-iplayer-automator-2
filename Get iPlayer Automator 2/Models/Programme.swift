//
//  Programme.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import Foundation
import Observation

enum ProgrammeType : String, CaseIterable, Codable {
    case tv
    case radio
    case stv
}

enum ProgramState : Int, CaseIterable, Codable, Comparable {
    public static func < (lhs: ProgramState, rhs: ProgramState) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    // Initial value
    case new

    // Program ID is valid, and URL is ready
    case processedPID

    // Program was automatically added by the PVR. This also implies `processedPID`
    case addedByPVR

    // Download in progress
    case downloadingProgram

    // Downloading thumbnail image started
    case downloadingThumbnail
    // Downloading thumbnail image finished
    case finishedThumbnail

    // Atomic Parsley tagging started
    case tagging
    // Atomic Parsley tagging finished
    case finishedTagging

    // get_iplayer or youtube-dl is done, and everything succeeded.
    case finishedProgramDownload

    // File is being added to Music or TV
    case addingToLibrary

    // downloaded file added to Music or TV.
    case successful

    // Something went wrong
    case failed

    // User cancelled the download.
    case cancelled
}

@MainActor
@Observable
class Programme: @preconcurrency Codable {

    @ObservationIgnored static var dateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ"
        df.timeZone = .gmt
        return df
    }()

    var status: ProgramState = .new
    var complete: Bool = false

    var successful: Bool {
        status == .successful
    }

    var readyToDownload: Bool {
        status != .successful // .processedPID || status == .addedByPVR
    }
    
    var downloadPercent: Double = 0.0
    var progress: String = ""

    public init() {

    }

    private enum CodingKeys: String, CodingKey {
        case status, complete, successful
        case index, type, name, episode, seriesNum, episodeNum
        case pid, channel, available, expires, duration, desc
        case web, thumbnail, timeadded, radio, podcast, realPID
        case subtitlePath, downloadPath
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(ProgramState.self, forKey: .status) ?? .new
        complete = try container.decodeIfPresent(Bool.self, forKey: .complete) ?? false
        index = try container.decodeIfPresent(Int.self, forKey: .index) ?? 0
        type = try container.decodeIfPresent(ProgrammeType.self, forKey: .type) ?? .tv
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        episode = try container.decodeIfPresent(String.self, forKey: .episode) ?? ""
        seriesNum = try container.decodeIfPresent(Int.self, forKey: .seriesNum) ?? 0
        episodeNum = try container.decodeIfPresent(Int.self, forKey: .episodeNum) ?? 0
        pid = try container.decodeIfPresent(String.self, forKey: .pid) ?? ""
        channel = try container.decodeIfPresent(String.self, forKey: .channel) ?? ""
        available = try container.decodeIfPresent(Date.self, forKey: .available) ?? Date()
        expires = try container.decodeIfPresent(Date.self, forKey: .expires)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 0
        desc = try container.decodeIfPresent(String.self, forKey: .desc) ?? ""
        web = try container.decodeIfPresent(URL.self, forKey: .web)
        thumbnail = try container.decodeIfPresent(URL.self, forKey: .thumbnail)
        timeadded = try container.decodeIfPresent(Date.self, forKey: .timeadded)
        radio = try container.decodeIfPresent(Bool.self, forKey: .radio) ?? false
        podcast = try container.decodeIfPresent(Bool.self, forKey: .podcast) ?? false
        realPID = try container.decodeIfPresent(String.self, forKey: .realPID) ?? ""
        subtitlePath = try container.decodeIfPresent(String.self, forKey: .subtitlePath) ?? ""
        downloadPath = try container.decodeIfPresent(String.self, forKey: .downloadPath) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(complete, forKey: .complete)
        try container.encode(successful, forKey: .successful)
        try container.encode(index, forKey: .index)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(episode, forKey: .episode)
        try container.encode(seriesNum, forKey: .seriesNum)
        try container.encode(episodeNum, forKey: .episodeNum)
        try container.encode(pid, forKey: .pid)
        try container.encode(channel, forKey: .channel)
        try container.encode(available, forKey: .available)
        try container.encodeIfPresent(expires, forKey: .expires)
        try container.encode(duration, forKey: .duration)
        try container.encode(desc, forKey: .desc)
        try container.encodeIfPresent(web, forKey: .web)
        try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
        try container.encodeIfPresent(timeadded, forKey: .timeadded)
        try container.encode(radio, forKey: .radio)
        try container.encode(podcast, forKey: .podcast)
        try container.encode(realPID, forKey: .realPID)
        try container.encode(subtitlePath, forKey: .subtitlePath)
        try container.encode(downloadPath, forKey: .downloadPath)
    }

    // #index|type|name|episode|seriesnum|episodenum|pid|channel|available|expires|duration|desc|web|thumbnail|timeadded
    var index: Int = 0
    var type: ProgrammeType = .tv
    var name: String = ""
    var episode: String = ""
    var seriesNum: Int = 0
    var episodeNum: Int = 0
    var pid: String = ""
    var channel: String = ""
    var available: Date = Date()
    var expires: Date? = nil
    var duration: Int = 0
    var desc: String = ""
    var web: URL? = nil
    var thumbnail: URL? = nil
    var timeadded: Date? = nil

    var radio: Bool = false
    
    var availableString: String {
        return Programme.dateFormatter.string(from: available)
    }

    var podcast: Bool = false
    var realPID: String = ""
    var subtitlePath: String = ""
    var downloadPath: String = ""

    //Extended Metadata
    //    var extendedMetadataRetrieved = false
    //    var successfulRetrieval = false
    //    var categories: String = ""
    //    var availableModes: String
    //    var modeSizes: [[String:String]] = []
    //    var getiPlayerProxy: GetiPlayerProxy?
    //    var addedByPVR = false

    var typeDescription: String {
        switch type {
        case .tv:
            "BBC TV"
        case .radio:
            "BBC Radio"
        case .stv:
            "STV"
        }
    }

    public var description: String {
        return "\(pid): \(name), \(episode)"
    }

}

extension Programme : @preconcurrency Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(pid.hashValue)
    }
}

extension Programme : @preconcurrency Identifiable {
    public var id: String {
        return pid
    }
}

extension Programme : @preconcurrency Comparable {
    public static func == (lhs: Programme, rhs: Programme) -> Bool {
        return lhs.pid == rhs.pid
    }


    public static func < (lhs: Programme, rhs: Programme) -> Bool {
        return lhs.name < rhs.name
    }

}

//1947|tv|Cricket: Today at the Test: The Ashes 2023|Third Test, Day One|8||m001nj18|BBC Four|2023-07-06T19:00:00+00:00|1691280900|3600|Highlights of day one in the Third Test of the 2023 Ashes between England and Australia.|https://www.bbc.co.uk/programmes/m001nj18|https://ichef.bbci.co.uk/images/ic/192xn/p0fzbsfl.jpg|1688673055|
