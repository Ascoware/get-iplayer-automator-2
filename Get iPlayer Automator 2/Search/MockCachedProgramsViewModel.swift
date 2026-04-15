//
//  MockCachedProgramsViewModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/8/26.
//

import Foundation
import Observation

@MainActor
@Observable
class MockCachedProgramsViewModel: ProgramCacheProviding {
    var viewType: SearchViewType = .tvToday
    var searchText: String = ""
    private(set) var viewCounts: [SearchViewType: Int] = [:]

    private var mockPrograms: [CachedProgramme] = []

    init() {
        let program1 = CachedProgramme(
            pid: "sample001", index: 1, type: .tv,
            name: "Sample Show", episode: "Episode 1",
            seriesNum: 0, episodeNum: 0, channel: "BBC One",
            available: Date(), expires: nil, duration: 0,
            desc: "A sample programme for preview",
            web: URL(string: "https://www.bbc.co.uk/programmes/sample001"),
            thumbnail: URL(string: "https://ichef.bbci.co.uk/images/ic/192xn/sample.jpg"),
            timeadded: nil, radio: false, podcast: false, realPID: ""
        )
        let program2 = CachedProgramme(
            pid: "sample002", index: 2, type: .tv,
            name: "Another Show", episode: "Episode 5",
            seriesNum: 0, episodeNum: 0, channel: "BBC Two",
            available: Date(), expires: nil, duration: 0,
            desc: "Another sample programme",
            web: URL(string: "https://www.bbc.co.uk/programmes/sample002"),
            thumbnail: URL(string: "https://ichef.bbci.co.uk/images/ic/192xn/sample2.jpg"),
            timeadded: nil, radio: false, podcast: false, realPID: ""
        )
        mockPrograms = [program1, program2]
        viewCounts = Dictionary(uniqueKeysWithValues: SearchViewType.allCases.compactMap { type in
            guard type != .all else { return nil }
            return (type, mockPrograms.count)
        })
    }

    func reloadCachedShows() {
        // No-op for mock
    }

    func dataFor(view: SearchViewType, searchText: String) -> [CachedProgramme] {
        if searchText.isEmpty {
            return mockPrograms
        }
        return mockPrograms.filter { program in
            program.name.localizedCaseInsensitiveContains(searchText) ||
            program.desc.localizedCaseInsensitiveContains(searchText)
        }
    }

    func findProgrammeFromPID(pid: String) -> CachedProgramme? {
        return mockPrograms.first { $0.pid == pid }
    }
}
