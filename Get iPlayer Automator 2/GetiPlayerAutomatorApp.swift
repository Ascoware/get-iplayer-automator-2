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
    @State private var downloadHistoryModel = DownloadHistoryModel()
    @State private var cacheUpdateService: CacheUpdateService
    @State private var pvrViewModel: PVRViewModel
    init() {
        let cache = CachedProgramsViewModel()
        let queue = DownloadQueueViewModel(cacheProvider: cache)
        let cacheService = CacheUpdateService(onCacheUpdated: {
            cache.reloadCachedShows()
        })
        let pvr = PVRViewModel(downloadQueueViewModel: queue)
        cachedProgramsViewModel = cache
        downloadQueueViewModel = queue
        cacheUpdateService = cacheService
        pvrViewModel = pvr
    }

    var body: some Scene {
        Window("Search", id: "search-window") {
            SearchContentView(
                cachedProgramsViewModel: cachedProgramsViewModel,
                downloadQueueViewModel: downloadQueueViewModel,
                pvrViewModel: pvrViewModel,
                historyModel: downloadHistoryModel
            )
            .task {
                appDelegate.downloadQueueViewModel = downloadQueueViewModel
                appDelegate.cacheUpdateService = cacheUpdateService

                if LegacyDataMigrator.shouldOfferMigration() {
                    let shouldImport = await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = "Import Data from Get iPlayer Automator?"
                        alert.informativeText = "Data from the previous version of Get iPlayer Automator was found. Would you like to import your settings, series links, and download history?"
                        alert.addButton(withTitle: "Import")
                        alert.addButton(withTitle: "Don't Import")
                        return alert.runModal() == .alertFirstButtonReturn
                    }

                    if shouldImport {
                        let migrator = LegacyDataMigrator()
                        migrator.performMigration()
                    }
                    LegacyDataMigrator.markMigrationComplete()
                }

                await startupAfterMigration()
            }
        }
        .windowToolbarStyle(.unified)
        .commands {
            SearchWindowMenus(cacheUpdateService: cacheUpdateService)
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

    private func startupAfterMigration() async {
        downloadQueueViewModel.loadAppData()
        pvrViewModel.loadSeriesData()
        cachedProgramsViewModel.reloadCachedShows()
        await cacheUpdateService.checkForCacheUpdate()
        cachedProgramsViewModel.reloadCachedShows()

        if Defaults.shared.addSeriesLinkAtStartup {
            await pvrViewModel.checkForNewEpisodes()
        }
    }

}
