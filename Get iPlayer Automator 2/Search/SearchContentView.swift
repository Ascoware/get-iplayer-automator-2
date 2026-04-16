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
        .searchable(text: $cachedProgramsViewModel.searchText)
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
