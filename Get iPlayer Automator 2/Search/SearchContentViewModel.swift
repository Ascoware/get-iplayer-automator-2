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
    let historyModel: any DownloadHistoryProviding

    var downloadedPIDs: Set<String> {
        Set(historyModel.downloadHistory.map(\.pid))
    }

    var programs: [CachedProgramme] {
        let all = cachedProgramsViewModel.dataFor(
            view: cachedProgramsViewModel.viewType,
            searchText: cachedProgramsViewModel.searchText
        )

        guard !Defaults.shared.ShowDownloadedInSearch else {
            return all
        }

        let downloaded = downloadedPIDs
        return all.filter { !downloaded.contains($0.pid) }
    }

    init(cachedProgramsViewModel: any ProgramCacheProviding, historyModel: any DownloadHistoryProviding) {
        self.cachedProgramsViewModel = cachedProgramsViewModel
        self.historyModel = historyModel
    }
}
