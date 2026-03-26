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

    var body: some View {
        HStack {
            DownloadQueueTableView(downloadQueueViewModel: downloadQueueViewModel)
        }
        .toolbar(id: "dl-queue-toolbar") {
            DownloadQueueToolbar(downloadQueueViewModel: downloadQueueViewModel, pvrViewModel: pvrViewModel)
        }
    }
}

#Preview {
    @Previewable @State var mockQueue = MockDownloadQueueViewModel()
    let pvrViewModel = PVRViewModel(downloadQueueViewModel: mockQueue)
    DownloadQueueView(downloadQueueViewModel: mockQueue, pvrViewModel: pvrViewModel)
}
