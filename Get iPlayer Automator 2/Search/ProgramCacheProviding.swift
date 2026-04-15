//
//  ProgramCacheProviding.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/8/26.
//

import Foundation

@MainActor
protocol ProgramCacheProviding: AnyObject {
    var viewType: SearchViewType { get set }
    var searchText: String { get set }
    var viewCounts: [SearchViewType: Int] { get }

    func reloadCachedShows()
    func dataFor(view: SearchViewType, searchText: String) -> [CachedProgramme]
    func findProgrammeFromPID(pid: String) -> CachedProgramme?
}
