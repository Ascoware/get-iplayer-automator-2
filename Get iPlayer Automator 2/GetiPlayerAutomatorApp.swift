//
//  Get_iPlayer_Automator_2App.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/10/23.
//

import SwiftUI

@main
struct GetiPlayerAutomatorApp: App {

    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @State private var logger = LogController()
    @State private var cachedProgramsViewModel: CachedProgramsViewModel
    @State private var downloadQueueViewModel: DownloadQueueViewModel
    @State private var downloadHistoryModel: DownloadHistoryModel
    @State private var cacheUpdateService: CacheUpdateService
    @State private var pvrViewModel: PVRViewModel
    @State private var updaterViewModel: UpdaterViewModel
    init() {
        let cache = CachedProgramsViewModel()
        let history = DownloadHistoryModel()
        let queue = DownloadQueueViewModel(cacheProvider: cache, historyModel: history)
        let cacheService = CacheUpdateService(onCacheUpdated: {
            cache.reloadCachedShows()
        })
        let pvr = PVRViewModel(downloadQueueViewModel: queue)
        cachedProgramsViewModel = cache
        downloadHistoryModel = history
        downloadQueueViewModel = queue
        cacheUpdateService = cacheService
        pvrViewModel = pvr
        updaterViewModel = UpdaterViewModel()

        appDelegate.downloadQueueViewModel = queue
        appDelegate.cacheUpdateService = cacheService

        Task { @MainActor in
            queue.loadAppData()
            pvr.loadSeriesData()
            cache.reloadCachedShows()
            await cacheService.checkForCacheUpdate()
            cache.reloadCachedShows()
            if Defaults.shared.addSeriesLinkAtStartup {
                await pvr.checkForNewEpisodes()
            }
        }
    }

    var body: some Scene {
        Window("Search", id: "search-window") {
            SearchContentView(
                cachedProgramsViewModel: cachedProgramsViewModel,
                downloadQueueViewModel: downloadQueueViewModel,
                pvrViewModel: pvrViewModel,
                historyModel: downloadHistoryModel
            )
        }
        .windowToolbarStyle(.unified)
        .commands {
            SearchWindowMenus(cacheUpdateService: cacheUpdateService, updaterViewModel: updaterViewModel)
        }

        Window("Download Queue", id: "dl-queue") {
            DownloadQueueView(downloadQueueViewModel: downloadQueueViewModel, pvrViewModel: pvrViewModel, downloadHistoryModel: downloadHistoryModel)
        }

        Window("PVR", id: "pvr") {
            PVRContentView(pvrViewModel: pvrViewModel)
        }

        Settings {
            SettingsView()
        }

        Window("Log", id: "log") {
            LogView(logger: logger)
        }

        Window("Download History", id: "history") {
            DownloadHistoryView(historyModel: downloadHistoryModel)
        }

        UtilityWindow("Activity", id: "activity") {
            ActivityView(
                cacheUpdateService: cacheUpdateService,
                downloadQueueViewModel: downloadQueueViewModel,
                pvrViewModel: pvrViewModel
            )
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)

    }

}
