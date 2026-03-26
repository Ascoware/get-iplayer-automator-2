//
//  PVRContentView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 10/14/23.
//

import SwiftUI

struct PVRContentView: View {
    var pvrViewModel: PVRViewModel

    @State private var seriesSelection: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Auto-recorded Series")
                .font(.headline)
                .padding([.horizontal, .top], 8)
                .padding(.bottom, 4)
            Divider()
            SeriesListView(pvrViewModel: pvrViewModel, selection: $seriesSelection)
        }
        .toolbar(id: "pvrToolbar") {
            PVRToolbar(
                pvrViewModel: pvrViewModel,
                seriesSelection: $seriesSelection
            )
        }
    }
}

#Preview {
    @Previewable @State var mockQueue = MockDownloadQueueViewModel()
    let pvrViewModel = PVRViewModel(downloadQueueViewModel: mockQueue)
    PVRContentView(pvrViewModel: pvrViewModel)
}
