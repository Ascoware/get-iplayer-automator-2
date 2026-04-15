//
//  SearchTableView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import SwiftUI

struct SearchTableView: View {
    var downloadQueueViewModel: any DownloadQueueProviding
    var pvrViewModel: PVRViewModel
    @Binding var selection: Set<String>
    var tableData: [CachedProgramme]

    @State private var sortOrder = [KeyPathComparator(\CachedProgramme.available)]
    @Environment(\.openWindow) private var openWindow

    @State private var sortedTableData: [CachedProgramme] = []

    var selectedProgrammes: [CachedProgramme] {
        guard !selection.isEmpty else {
            return []
        }

        return tableData.filter {
            selection.contains($0.pid)
        }
    }

    func addItemsToQueueAndOpen(pids: Set<String>) {
        for p in pids {
            downloadQueueViewModel.addToQueue(pid: p)
        }

        openWindow(id: "dl-queue")
    }

    func addSelectedSeriesToAutoRecord(pids: Set<String>) {
        for pid in pids {
            guard let programme = tableData.first(where: { $0.pid == pid }) else { continue }
            pvrViewModel.addSeries(showName: programme.name, tvNetwork: programme.channel)
        }
    }


    var body: some View {
        VStack {
            Table(
                sortedTableData,
                selection: $selection,
                sortOrder: $sortOrder) {
                    TableColumn("Show", value: \.name)
                    TableColumn("Episode", value: \.episode)
                    TableColumn("Last Broadcast", value: \.available) { program in
                        Text(program.available, style: .date)
                    }
                    TableColumn("Network", value: \.channel)
                }
                .onChange(of: tableData) { sortedTableData = tableData.sorted(using: sortOrder) }
                .onChange(of: sortOrder)  { sortedTableData = tableData.sorted(using: sortOrder) }
                .task { sortedTableData = tableData.sorted(using: sortOrder) }
                .contextMenu(forSelectionType: CachedProgramme.ID.self) { programs in
                    Button("Add To Download Queue") {
                        addItemsToQueueAndOpen(pids: programs)
                    }
                    Button("Record Series") {
                        addSelectedSeriesToAutoRecord(pids: programs)
                    }
                } primaryAction: { pids in
                    addItemsToQueueAndOpen(pids: pids)
                }
        }
    }
}

#Preview("Empty Table") {
    @Previewable @State var mockQueue = MockDownloadQueueViewModel()
    let pvrViewModel = PVRViewModel(downloadQueueViewModel: mockQueue)
    SearchTableView(
        downloadQueueViewModel: mockQueue,
        pvrViewModel: pvrViewModel,
        selection: .constant([]),
        tableData: []
    )
}

#Preview("With Mock Data") {
    @Previewable @State var mockQueue = MockDownloadQueueViewModel()
    let pvrViewModel = PVRViewModel(downloadQueueViewModel: mockQueue)

    let program1 = CachedProgramme(
        pid: "sample001", index: 1, type: .tv,
        name: "Sample Show", episode: "Episode 1",
        seriesNum: 0, episodeNum: 0, channel: "BBC One",
        available: Date(), expires: nil, duration: 0,
        desc: "A sample programme for preview",
        web: nil, thumbnail: nil, timeadded: nil,
        radio: false, podcast: false, realPID: ""
    )
    let program2 = CachedProgramme(
        pid: "sample002", index: 2, type: .tv,
        name: "Another Show", episode: "Episode 5",
        seriesNum: 0, episodeNum: 0, channel: "BBC Two",
        available: Date(), expires: nil, duration: 0,
        desc: "Another sample programme",
        web: nil, thumbnail: nil, timeadded: nil,
        radio: false, podcast: false, realPID: ""
    )
    SearchTableView(
        downloadQueueViewModel: mockQueue,
        pvrViewModel: pvrViewModel,
        selection: .constant([]),
        tableData: [program1, program2]
    )
}

