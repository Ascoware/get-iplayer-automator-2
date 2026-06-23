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

    var viewType: SearchViewType = .tvToday
    var searchText = ""

    var viewCounts: [SearchViewType: Int] {
        let allTV = dataFor(view: .allTV, searchText: "")
        let allRadio = dataFor(view: .allRadio, searchText: "")
        let startDate = Date(timeIntervalSinceNow: -24 * 60 * 60)
        let endDate = Date()
        return [
            .allTV: allTV.count,
            .allRadio: allRadio.count,
            .tvToday: allTV.filter { startDate < $0.available && endDate > $0.available }.count,
            .radioToday: allRadio.filter { startDate < $0.available && endDate > $0.available }.count,
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
    @ObservationIgnored @Default(\.RadioAsianNetwork) var showAsianNetwork
    @ObservationIgnored @Default(\.BBCWorldService) var showWorldService
    @ObservationIgnored @Default(\.CBeebies) var showCBeebiesRadio

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
        "Radio6Music", "BBCWorldService", "Radio5Live",
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

    public func dataFor(view: SearchViewType, searchText: String) -> [CachedProgramme] {
        // Access filterRevision so the observation system tracks it as a dependency.
        _ = filterRevision
        let startDate = Date(timeIntervalSinceNow: -24 * 60 * 60)
        let endDate = Date()

        var filteredShows: [CachedProgramme]
        switch view {
        case .tvToday, .allTV:
            filteredShows = bbcTVShows
        case .radioToday, .allRadio:
            filteredShows = radioShows
        default:
            filteredShows = bbcTVShows + radioShows
        }

        // Filter out programs by category first
        if ignoreAllTVNews && !view.radio() {
            filteredShows = filteredShows.filter { show in
                !(!show.radio && show.name.hasSuffix("News"))
            }
        }

        if ignoreAllRadioNews && !view.tv() {
            filteredShows = filteredShows.filter { show in
                !(show.radio && show.name.hasSuffix("News"))
            }
        }

        if view.tv() || view == .all {
            filteredShows = filteredShows.filter { show in
                guard !show.radio else {
                    return view == .all
                }


                if let channel = BBCNationalChannels(rawValue: show.channel) {
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

                if let _ = BBCRegionalChannels(rawValue: show.channel) {
                    return showRegionalTVStations
                }

                // Only option left is local TV.
                return showLocalTVStations
            }
        }

        if view.radio() {
            filteredShows = filteredShows.filter { show in
                guard show.radio else {
                    return view == .all
                }

                if let channel = BBCRadioChannels(rawValue: show.channel) {
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
                        return showRadio4
                    case .bbcRadio5Live:
                        return showRadio5Live
                    case .bbcRadio5LiveSports:
                        return showRadio5LiveExtra
                    case .bbcRadio6:
                        return showRadio6Music
                    case .bbcAsian:
                        return showAsianNetwork
                    case .bbcWorldService:
                        return showWorldService
                    case .cbeebiesRadio:
                        return showCBeebies
                    }
                }

                for region in regionalRadioChannels {
                    if show.channel == region {
                        return showRegionalRadioStations
                    }
                }

                // Only option left is local radio
                return showLocalRadioStations
            }
        }

        if !searchText.isEmpty {
            filteredShows = filteredShows.filter { show in
                show.desc.localizedStandardContains(searchText) ||
                show.name.localizedStandardContains(searchText) ||
                show.episode.localizedStandardContains(searchText)
            }
        }

        if view == .tvToday || view == .radioToday {
            filteredShows = filteredShows.filter { show in
                return startDate < show.available && endDate > show.available
            }
        }

        return filteredShows
    }

    public func findProgrammeFromPID(pid: String) -> CachedProgramme? {
        return bbcTVShows.first { $0.pid == pid }
            ?? radioShows.first { $0.pid == pid }
    }
}
