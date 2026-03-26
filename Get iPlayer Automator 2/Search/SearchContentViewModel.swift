//
//  SearchContentViewModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/8/26.
//

import Foundation
import Observation

@MainActor
@Observable
class SearchContentViewModel {
    var selection: Set<String> = []
    let cachedProgramsViewModel: any ProgramCacheProviding
    
    var programs: [Programme] {
        cachedProgramsViewModel.dataFor(
            view: cachedProgramsViewModel.viewType,
            searchText: cachedProgramsViewModel.searchText
        )
    }
    
    init(cachedProgramsViewModel: any ProgramCacheProviding) {
        self.cachedProgramsViewModel = cachedProgramsViewModel
    }
}
