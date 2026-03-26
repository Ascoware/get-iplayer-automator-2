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

    private var mockPrograms: [Programme] = []

    init() {
        // Create some sample programs for preview
        let program1 = Programme()
        program1.name = "Sample Show"
        program1.episode = "Episode 1"
        program1.channel = "BBC One"
        program1.type = .tv
        program1.radio = false
        program1.available = Date()
        program1.desc = "A sample programme for preview"
        program1.pid = "sample001"
        program1.status = .processedPID
        program1.web = URL(string: "https://www.bbc.co.uk/programmes/sample001")
        program1.thumbnail = URL(string: "https://ichef.bbci.co.uk/images/ic/192xn/sample.jpg")

        let program2 = Programme()
        program2.name = "Another Show"
        program2.episode = "Episode 5"
        program2.channel = "BBC Two"
        program2.type = .tv
        program2.radio = false
        program2.available = Date()
        program2.desc = "Another sample programme"
        program2.pid = "sample002"
        program2.status = .processedPID
        program2.web = URL(string: "https://www.bbc.co.uk/programmes/sample002")
        program2.thumbnail = URL(string: "https://ichef.bbci.co.uk/images/ic/192xn/sample2.jpg")

        mockPrograms = [program1, program2]
        viewCounts = Dictionary(uniqueKeysWithValues: SearchViewType.allCases.compactMap { type in
            guard type != .all else { return nil }
            return (type, mockPrograms.count)
        })
    }

    func reloadCachedShows() {
        // No-op for mock
    }
    
    func dataFor(view: SearchViewType, searchText: String) -> [Programme] {
        if searchText.isEmpty {
            return mockPrograms
        }
        return mockPrograms.filter { program in
            program.name.localizedCaseInsensitiveContains(searchText) ||
            program.desc.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func findProgrammeFromPID(pid: String) -> Programme? {
        return mockPrograms.first { $0.pid == pid }
    }
}
