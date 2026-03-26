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
    var tableData: [Programme]

    @State private var sortOrder = [KeyPathComparator(\Programme.available)]
    @Environment(\.openWindow) private var openWindow

    @State private var sortedTableData: [Programme] = []

    var selectedProgrammes: [Programme] {
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
                .contextMenu(forSelectionType: Programme.ID.self) { programs in
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

    let program1 = Programme()
    program1.name = "Sample Show"
    program1.episode = "Episode 1"
    program1.channel = "BBC One"
    program1.type = .tv
    program1.available = Date()
    program1.desc = "A sample programme for preview"
    program1.pid = "sample001"
    
    let program2 = Programme()
    program2.name = "Another Show"
    program2.episode = "Episode 5"
    program2.channel = "BBC Two"
    program2.type = .tv
    program2.available = Date()
    program2.desc = "Another sample programme"
    program2.pid = "sample002"
    
    return SearchTableView(
        downloadQueueViewModel: mockQueue,
        pvrViewModel: pvrViewModel,
        selection: .constant([]),
        tableData: [program1, program2]
    )
}

