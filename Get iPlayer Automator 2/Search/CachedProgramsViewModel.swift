//
//  CachedProgramsViewModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/27/23.
//

import Foundation
import CocoaLumberjackSwift
import SwiftUI
import Observation
import Combine

/// View model for searching and filtering cached programs.
/// Cache updating is handled separately by CacheUpdateService.
@MainActor
@Observable
class CachedProgramsViewModel: ProgramCacheProviding {

    @available(*, deprecated, message: "Use dependency injection instead")
    static let shared = CachedProgramsViewModel()

    private static let dateFormatter = ISO8601DateFormatter()

    private var bbcTVShows: [CachedProgramme] = []
    private var radioShows: [CachedProgramme] = []

    @ObservationIgnored @Default(\.IgnoreAllTVNews) var ignoreAllTVNews
    @ObservationIgnored @Default(\.IgnoreAllRadioNews) var ignoreAllRadioNews
    @ObservationIgnored @Default(\.ShowRegionalTVStations) var showRegionalTVStations
    @ObservationIgnored @Default(\.ShowLocalTVStations) var showLocalTVStations
    @ObservationIgnored @Default(\.ShowRegionalRadioStations) var showRegionalRadioStations
    @ObservationIgnored @Default(\.ShowLocalRadioStations) var showLocalRadioStations

    @ObservationIgnored @Default(\.BBCOne) var showBBCOne
    @ObservationIgnored @Default(\.BBCTwo) var showBBCTwo
    @ObservationIgnored @Default(\.BBCThree) var showBBCThree
    @ObservationIgnored @Default(\.BBCFour) var showBBCFour
    @ObservationIgnored @Default(\.BBCNews) var showBBCNews
    @ObservationIgnored @Default(\.BBCParliament) var showBBCParliament
    @ObservationIgnored @Default(\.CBBC) var showCBBC
    @ObservationIgnored @Default(\.CBeebies) var showCBeebies

    /// Bumped when any channel filter preference changes, so observation triggers re-filtering.
    var filterRevision = 0
    @ObservationIgnored private var defaultsCancellable: AnyCancellable?

    var viewType: SearchViewType = .tv
    var searchText = ""

    var viewCounts: [SearchViewType: Int] {
        [
            .tv: dataFor(view: .tv, searchText: "").count,
            .radio: dataFor(view: .radio, searchText: "").count,
        ]
    }

    enum BBCNationalChannels: String, CaseIterable {
        case bbcOne = "BBC One"
        case bbcTwo = "BBC Two"
        case bbcThree = "BBC Three"
        case bbcFour = "BBC Four"
        case bbcNews = "BBC News"
        case bbcParliament = "BBC Parliament"
        case cbbc = "CBBC"
        case cbeebies = "CBeebies"
    }

    @ObservationIgnored @Default(\.Radio1) var showRadio1
    @ObservationIgnored @Default(\.Radio1Xtra) var showRadio1Xtra
    @ObservationIgnored @Default(\.Radio2) var showRadio2
    @ObservationIgnored @Default(\.Radio3) var showRadio3
    @ObservationIgnored @Default(\.Radio4) var showRadio4
    @ObservationIgnored @Default(\.Radio4Extra) var showRadio4Extra
    @ObservationIgnored @Default(\.Radio5Live) var showRadio5Live
    @ObservationIgnored @Default(\.Radio5LiveSportsExtra) var showRadio5LiveExtra
    @ObservationIgnored @Default(\.Radio6Music) var showRadio6Music
    @ObservationIgnored @Default(\.Radio6IndieForever) var showRadio6IndieForever
    @ObservationIgnored @Default(\.RadioAsianNetwork) var showAsianNetwork
    @ObservationIgnored @Default(\.BBCWorldService) var showWorldService
    @ObservationIgnored @Default(\.CBeebiesRadio) var showCBeebiesRadio

    enum BBCRadioChannels: String, CaseIterable {
        case bbcRadio1 = "BBC Radio 1"
        case bbcRadio1Xtra = "BBC Radio 1Xtra"
        case bbcRadio2 = "BBC Radio 2"
        case bbcRadio3 = "BBC Radio 3"
        case bbcRadio4 = "BBC Radio 4"
        case bbcRadio4Extra = "BBC Radio 4 Extra"
        case bbcRadio5Live = "BBC Radio 5 live"
        case bbcRadio5LiveSports = "BBC Radio 5 live sports extra"
        case bbcRadio6 = "BBC Radio 6 Music"
        case bbcRadio6IndieForever = "BBC Radio 6 Indie Forever"
        case bbcAsian = "BBC Asian Network"
        case bbcWorldService = "BBC World Service"
        case cbeebiesRadio = "CBeebies Radio"
    }

    enum BBCRegionalChannels: String, CaseIterable {
        case bbcAlba = "BBC Alba"
        case bbcOneNI = "BBC One Northern Ireland"
        case bbcOneScotland = "BBC One Scotland"
        case bbcOneWales = "BBC One Wales"
        case bbcScotland = "BBC Scotland"
        case bbcTwoEngland = "BBC Two England"
        case bbcTwoNI = "BBC Two Northern Ireland"
        case bbcTwoWales = "BBC Two Wales"
        case s4c = "S4C"
    }

    let regionalRadioChannels = [
        "BBC Radio Cymru",
        "BBC Radio Foyle",
        "BBC Radio Nan Gaidheal",
        "BBC Radio Scotland",
        "BBC Radio Ulster",
        "BBC Radio Wales",
    ];


    private static let channelFilterKeys: Set<String> = [
        "BBCOne", "BBCTwo", "BBCThree", "BBCFour",
        "CBBC", "CBeebies", "BBCNews", "BBCParliament",
        "ShowRegionalTVStations", "ShowLocalTVStations",
        "ShowRegionalRadioStations", "ShowLocalRadioStations",
        "Radio1", "Radio2", "Radio3", "Radio4", "Radio4Extra",
        "Radio6Music", "Radio6IndieForever", "BBCWorldService", "Radio5Live",
        "Radio5LiveSportsExtra", "Radio1Xtra", "RadioAsianNetwork",
        "CBeebiesRadio", "IgnoreAllTVNews", "IgnoreAllRadioNews",
        "ShowDownloadedInSearch"
    ]

    public init() {
        defaultsCancellable = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // UserDefaults.didChangeNotification doesn't include the key,
                // so we bump unconditionally. The cost is a re-filter which is cheap.
                self?.filterRevision &+= 1
            }
        reloadCachedShows()
    }

    /// Reload cached shows from disk.
    public func reloadCachedShows() {
        getCachedShows()
    }

    private func getCachedShows() {
        let shows = readCaches()
        bbcTVShows = shows[0]
        radioShows = shows[1]
    }

    public func readCaches() -> [[CachedProgramme]] {
        let bbc = readCacheFile(fileName: "tv.cache")
        let radio = readCacheFile(fileName: "radio.cache")
        return [bbc, radio]
    }

    fileprivate func readCacheFile(fileName: String) -> [CachedProgramme] {
        var cachedPrograms = [CachedProgramme]()

        let ourSupportDir = FileManager.default.applicationSupportDirectory
        let cacheFile = ourSupportDir.appending("/\(fileName)")
        let cacheURL = URL(fileURLWithPath: cacheFile)
        guard let cacheContents = try? String(contentsOf: cacheURL, encoding: .utf8) else {
            return []
        }

        // #index|type|name|episode|seriesnum|episodenum|pid|channel|available|expires|duration|desc|web|thumbnail|timeadded

        // 741|tv|Wimbledon: 2023|Day 6, Part 2|2023||m001nq2z|BBC One|2023-07-08T16:00:00+00:00|1691424000|16800|Further live action from day six of Wimbledon 2023.|https://www.bbc.co.uk/programmes/m001nq2z|https://ichef.bbci.co.uk/images/ic/192xn/p0fzss2c.jpg|1688838892|

        let lines = cacheContents.components(separatedBy: .newlines)

        var checkForHeader = true
        let isRadio = fileName.hasPrefix("radio")
        for line in lines {
            // Skip the first line as it has the header fields.
            if checkForHeader && line.hasPrefix("#index") {
                checkForHeader = false
                continue
            }

            if line.isEmpty {
                continue
            }

            let elements = line.components(separatedBy: "|")

            // A refresh interrupted mid-write (or a full disk) can leave a truncated
            // final line. Skip short rows rather than trapping on a missing field --
            // the bad cache is re-read on every launch, so a crash here never recovers.
            guard elements.count >= 15 else {
                DDLogWarn("Skipping malformed \(fileName) line with \(elements.count) fields: \(line)")
                continue
            }

            let availableDate = Self.dateFormatter.date(from: elements[8]) ?? Date()
            let expiresDate = Self.dateFormatter.date(from: elements[9])
            let timeAddedSecs = Double(elements[14]) ?? 0.0
            let timeAdded = Date(timeIntervalSince1970: timeAddedSecs)
            let p = CachedProgramme(
                pid: elements[6],
                index: Int(elements[0]) ?? 0,
                type: ProgrammeType(rawValue: elements[1]) ?? .tv,
                name: elements[2],
                episode: elements[3],
                seriesNum: Int(elements[4]) ?? 0,
                episodeNum: Int(elements[5]) ?? 0,
                channel: elements[7],
                available: availableDate,
                expires: expiresDate,
                duration: Int(elements[10]) ?? 0,
                desc: elements[11],
                web: URL(string: elements[12]),
                thumbnail: URL(string: elements[13]),
                timeadded: timeAdded,
                radio: isRadio,
                realPID: ""
            )
            cachedPrograms.append(p)
        }

        return cachedPrograms
    }

    /// Matches the promise made by the Channels settings labels -- "programmes with
    /// \"news\" in the title". `hasSuffix("News")` missed Newsnight, Newsbeat and
    /// BBC News at Ten, which are exactly the shows the setting exists to hide.
    private static func isNews(_ name: String) -> Bool {
        name.localizedCaseInsensitiveContains("news")
    }

    /// Programmes for one sidebar view.
    public func dataFor(view: SearchViewType, searchText: String) -> [CachedProgramme] {
        filter(view == .tv ? bbcTVShows : radioShows, searchText: searchText)
    }

    /// TV and radio together, for the main window's search field.
    public func allShows(searchText: String) -> [CachedProgramme] {
        filter(bbcTVShows + radioShows, searchText: searchText)
    }

    /// Applies the news, channel, and text filters. Every test dispatches on the
    /// programme's own `radio` flag, so the same pass works for a single view and
    /// for TV and radio combined.
    private func filter(_ shows: [CachedProgramme], searchText: String) -> [CachedProgramme] {
        // Access filterRevision so the observation system tracks it as a dependency.
        _ = filterRevision

        var filteredShows = shows

        // Filter out programs by category first
        if ignoreAllTVNews {
            filteredShows = filteredShows.filter { show in
                !(!show.radio && Self.isNews(show.name))
            }
        }

        if ignoreAllRadioNews {
            filteredShows = filteredShows.filter { show in
                !(show.radio && Self.isNews(show.name))
            }
        }

        filteredShows = filteredShows.filter { show in
            show.radio ? showRadioChannel(show.channel) : showTVChannel(show.channel)
        }

        if !searchText.isEmpty {
            filteredShows = filteredShows.filter { show in
                show.desc.localizedStandardContains(searchText) ||
                show.name.localizedStandardContains(searchText) ||
                show.episode.localizedStandardContains(searchText)
            }
        }

        return filteredShows
    }

    /// Whether a TV programme's channel is enabled in Channels settings.
    private func showTVChannel(_ channel: String) -> Bool {
        if let channel = BBCNationalChannels(rawValue: channel) {
            switch channel {
            case .bbcOne:
                return showBBCOne
            case .bbcTwo:
                return showBBCTwo
            case .bbcThree:
                return showBBCThree
            case .bbcFour:
                return showBBCFour
            case .bbcNews:
                return showBBCNews
            case .bbcParliament:
                return showBBCParliament
            case .cbbc:
                return showCBBC
            case .cbeebies:
                return showCBeebies
            }
        }

        if BBCRegionalChannels(rawValue: channel) != nil {
            return showRegionalTVStations
        }

        // Only option left is local TV.
        return showLocalTVStations
    }

    /// Whether a radio programme's station is enabled in Channels settings.
    private func showRadioChannel(_ channel: String) -> Bool {
        if let channel = BBCRadioChannels(rawValue: channel) {
            switch channel {
            case .bbcRadio1:
                return showRadio1
            case .bbcRadio1Xtra:
                return showRadio1Xtra
            case .bbcRadio2:
                return showRadio2
            case .bbcRadio3:
                return showRadio3
            case .bbcRadio4:
                return showRadio4
            case .bbcRadio4Extra:
                return showRadio4Extra
            case .bbcRadio5Live:
                return showRadio5Live
            case .bbcRadio5LiveSports:
                return showRadio5LiveExtra
            case .bbcRadio6:
                return showRadio6Music
            case .bbcRadio6IndieForever:
                return showRadio6IndieForever
            case .bbcAsian:
                return showAsianNetwork
            case .bbcWorldService:
                return showWorldService
            case .cbeebiesRadio:
                return showCBeebiesRadio
            }
        }

        if regionalRadioChannels.contains(channel) {
            return showRegionalRadioStations
        }

        // Only option left is local radio
        return showLocalRadioStations
    }

    public func findProgrammeFromPID(pid: String) -> CachedProgramme? {
        return bbcTVShows.first { $0.pid == pid }
            ?? radioShows.first { $0.pid == pid }
    }
}
