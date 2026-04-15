//
//  DownloadQueueView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import SwiftUI

struct DownloadQueueView: View {
    var downloadQueueViewModel: any DownloadQueueProviding
    var pvrViewModel: PVRViewModel
    var downloadHistoryModel: DownloadHistoryModel

    @State private var selection: Set<String> = []

    var body: some View {
        DownloadQueueTableView(downloadQueueViewModel: downloadQueueViewModel, selection: $selection)
            .toolbar(id: "dl-queue-toolbar") {
                DownloadQueueToolbar(downloadQueueViewModel: downloadQueueViewModel, pvrViewModel: pvrViewModel, downloadHistoryModel: downloadHistoryModel, selection: $selection)
            }
    }
}

#Preview {
    @Previewable @State var mockQueue = MockDownloadQueueViewModel()
    let pvrViewModel = PVRViewModel(downloadQueueViewModel: mockQueue)
    let historyModel = DownloadHistoryModel(loadHistory: false)
    DownloadQueueView(downloadQueueViewModel: mockQueue, pvrViewModel: pvrViewModel, downloadHistoryModel: historyModel)
}
