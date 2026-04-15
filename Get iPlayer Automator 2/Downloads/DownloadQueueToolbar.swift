//
//  DownloadQueueToolbar.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/31/23.
//

import Foundation
import SwiftUI

struct DownloadQueueToolbar: CustomizableToolbarContent {

    var downloadQueueViewModel: any DownloadQueueProviding
    var pvrViewModel: PVRViewModel
    var downloadHistoryModel: DownloadHistoryModel
    @Binding var selection: Set<String>

    private var selectedSeriesLinkedItems: [Programme] {
        downloadQueueViewModel.downloadQueue.filter { program in
            selection.contains(program.pid) && program.status == .addedByPVR
        }
    }

    var body: some CustomizableToolbarContent {
        ToolbarItem(
            id: "startDownloads",
            placement: .automatic,
            showsByDefault: true) {
                Button {
                    downloadQueueViewModel.startDownloads()
                } label: {
                    Label("Start", systemImage: "arrow.down.circle")
                        .imageScale(.large)
                }
                .help("Start Downloading")
                .disabled(downloadQueueViewModel.downloadQueue.count == 0 || downloadQueueViewModel.isDownloading)
            }
        ToolbarItem(
            id: "stopDownloads",
            placement: .automatic,
            showsByDefault: true) {
                Button {
                    downloadQueueViewModel.stopDownloads()
                } label: {
                    Label("Stop", systemImage: "stop.circle")
                        .imageScale(.large)
                }
                .help("Stop Downloading")
                .disabled(!downloadQueueViewModel.isDownloading)
            }
        ToolbarItem(
            id: "seriesLinkToQueue",
            placement: .automatic,
            showsByDefault: true) {
                Button {
                    Task { await pvrViewModel.checkForNewEpisodes() }
                } label: {
                    Label("Add Series", systemImage: "record.circle")
                        .imageScale(.large)
                }
                .help("Search for new episodes of all auto-recorded series")
                .disabled(pvrViewModel.series.isEmpty || pvrViewModel.isChecking)
            }
        ToolbarItem(
            id: "currentWebpage",
            placement: .automatic,
            showsByDefault: true) {
                Button {
                    downloadQueueViewModel.getCurrentWebpage()
                } label: {
                    Label("Use Current Webpage", systemImage: "globe")
                        .imageScale(.large)
                }
                .help("Add the programme from the current browser tab to the queue")
            }
        ToolbarItem(
            id: "skipSeriesLinked",
            placement: .automatic,
            showsByDefault: true) {
                Button {
                    let itemsToSkip = selectedSeriesLinkedItems
                    downloadHistoryModel.addToHistory(programs: itemsToSkip)
                    for program in itemsToSkip {
                        downloadQueueViewModel.removeFromQueue(pid: program.pid)
                    }
                    selection.subtract(itemsToSkip.map(\.pid))
                } label: {
                    Label("Skip Selected Series-Linked Items", systemImage: "forward.circle")
                        .imageScale(.large)
                }
                .help("Remove selected series-linked items from the queue and add them to download history")
                .disabled(selectedSeriesLinkedItems.isEmpty)
            }
    }
}
