//
//  ContentView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/10/23.
//

import SwiftUI

struct SearchContentView: View {
    @Bindable var cachedProgramsViewModel: CachedProgramsViewModel
    var downloadQueueViewModel: any DownloadQueueProviding
    var pvrViewModel: PVRViewModel
    var historyModel: any DownloadHistoryProviding
    @State private var viewModel: SearchContentViewModel

    init(cachedProgramsViewModel: CachedProgramsViewModel, downloadQueueViewModel: any DownloadQueueProviding, pvrViewModel: PVRViewModel, historyModel: any DownloadHistoryProviding) {
        self.cachedProgramsViewModel = cachedProgramsViewModel
        self.downloadQueueViewModel = downloadQueueViewModel
        self.pvrViewModel = pvrViewModel
        self.historyModel = historyModel
        self.viewModel = SearchContentViewModel(cachedProgramsViewModel: cachedProgramsViewModel, historyModel: historyModel)
    }

    var body: some View {
        NavigationSplitView {
            SearchSidebarView(cachedProgramsViewModel: cachedProgramsViewModel)
        } detail: {
            SearchTableView(
                downloadQueueViewModel: downloadQueueViewModel,
                pvrViewModel: pvrViewModel,
                selection: $viewModel.selection,
                tableData: viewModel.programs,
                downloadedPIDs: viewModel.downloadedPIDs
            )
        }
        .toolbar(id: "mainToolbar") {
            SearchWindowToolbar(
                downloadQueueViewModel: downloadQueueViewModel,
                pvrViewModel: pvrViewModel,
                selection: $viewModel.selection,
                tableData: viewModel.programs
            )
        }
        .frame(
            minWidth: 700,
            idealWidth: 1000,
            maxWidth: .infinity,
            minHeight: 400,
            idealHeight: 800,
            maxHeight: .infinity
        )
    }
}

#Preview("Search Content") {
    @Previewable @State var mockCache = CachedProgramsViewModel()
    @Previewable @State var mockQueue = MockDownloadQueueViewModel()
    let pvrViewModel = PVRViewModel(downloadQueueViewModel: mockQueue)
    let mockHistory = MockDownloadHistoryModel()

    SearchContentView(
        cachedProgramsViewModel: mockCache,
        downloadQueueViewModel: mockQueue,
        pvrViewModel: pvrViewModel,
        historyModel: mockHistory
    )
    .frame(width: 1000, height: 800)
}

/// The main window: a combined search-and-download-queue view. The top half is a
/// search field over the cached programme list; the bottom half is the download
/// queue. The two are stacked in a draggable top/bottom split, and the window
/// carries the download-queue toolbar.
///
/// Search results are added to the queue with the existing `SearchTableView`
/// affordances (double-click, or right-click ▸ "Add To Download Queue").
struct MainWindowView: View {
    @Bindable var cachedProgramsViewModel: CachedProgramsViewModel
    var downloadQueueViewModel: any DownloadQueueProviding
    var pvrViewModel: PVRViewModel
    var downloadHistoryModel: DownloadHistoryModel

    @State private var searchText = ""
    @State private var searchSelection: Set<String> = []
    @State private var queueSelection: Set<String> = []

    private var downloadedPIDs: Set<String> {
        Set(downloadHistoryModel.downloadHistory.map(\.pid))
    }

    /// Cached programmes matching the search text. Empty until the user types, so
    /// the top pane doesn't dump the entire cache. Searches TV and radio together
    /// (matching name, episode, and description) and hides already-downloaded
    /// shows unless the user opted to keep showing them.
    private var searchResults: [CachedProgramme] {
        guard !searchText.isEmpty else { return [] }
        let all = cachedProgramsViewModel.dataFor(view: .all, searchText: searchText)
        guard !Defaults.shared.ShowDownloadedInSearch else { return all }
        let downloaded = downloadedPIDs
        return all.filter { !downloaded.contains($0.pid) }
    }

    private func addSearchSelectionToQueue() {
        for pid in searchSelection {
            downloadQueueViewModel.addToQueue(pid: pid)
        }
    }

    var body: some View {
        VSplitView {
            VStack(spacing: 0) {
                searchField
                SearchTableView(
                    downloadQueueViewModel: downloadQueueViewModel,
                    pvrViewModel: pvrViewModel,
                    selection: $searchSelection,
                    tableData: searchResults,
                    downloadedPIDs: downloadedPIDs
                )
            }
            .frame(minHeight: 180, idealHeight: 320)

            DownloadQueueTableView(
                downloadQueueViewModel: downloadQueueViewModel,
                selection: $queueSelection
            )
            .frame(minHeight: 220, idealHeight: 420)
        }
        .toolbar(id: "main-toolbar") {
            ToolbarItem(
                id: "addToQueue",
                placement: .automatic,
                showsByDefault: true) {
                    Button {
                        addSearchSelectionToQueue()
                    } label: {
                        Label("Add to Queue", systemImage: "rectangle.stack.badge.plus")
                            .imageScale(.large)
                    }
                    .toolbarHelp("Add selected search results to the download queue", disabled: searchSelection.isEmpty)
                }
            DownloadQueueToolbar(
                downloadQueueViewModel: downloadQueueViewModel,
                pvrViewModel: pvrViewModel,
                downloadHistoryModel: downloadHistoryModel,
                selection: $queueSelection
            )
        }
        .frame(
            minWidth: 760,
            idealWidth: 1000,
            maxWidth: .infinity,
            minHeight: 500,
            idealHeight: 900,
            maxHeight: .infinity
        )
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search programmes by name", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
            }
        }
        .padding(6)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .padding(10)
    }
}

#Preview("Main Window") {
    @Previewable @State var mockCache = CachedProgramsViewModel()
    @Previewable @State var mockQueue = MockDownloadQueueViewModel()
    let pvrViewModel = PVRViewModel(downloadQueueViewModel: mockQueue)
    let historyModel = DownloadHistoryModel(loadHistory: false)

    MainWindowView(
        cachedProgramsViewModel: mockCache,
        downloadQueueViewModel: mockQueue,
        pvrViewModel: pvrViewModel,
        downloadHistoryModel: historyModel
    )
    .frame(width: 1000, height: 900)
}
