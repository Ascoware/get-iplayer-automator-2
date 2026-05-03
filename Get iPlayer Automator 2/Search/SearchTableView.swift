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
    var downloadedPIDs: Set<String> = []

    @Default(\.searchSortColumn) private var searchSortColumn
    @Default(\.searchSortAscending) private var searchSortAscending

    @State private var sortOrder: [KeyPathComparator<CachedProgramme>] = []
    @Environment(\.openWindow) private var openWindow

    @State private var sortedTableData: [CachedProgramme] = []
    @State private var programInfoTarget: CachedProgramme? = nil

    private static func comparator(column: String, ascending: Bool) -> KeyPathComparator<CachedProgramme> {
        let order: SortOrder = ascending ? .forward : .reverse
        switch column {
        case "name":      return KeyPathComparator(\CachedProgramme.name, order: order)
        case "episode":   return KeyPathComparator(\CachedProgramme.episode, order: order)
        case "channel":   return KeyPathComparator(\CachedProgramme.channel, order: order)
        default:          return KeyPathComparator(\CachedProgramme.available, order: order)
        }
    }

    private func columnKey(for comparator: KeyPathComparator<CachedProgramme>) -> String {
        switch comparator.keyPath {
        case \CachedProgramme.name:    return "name"
        case \CachedProgramme.episode: return "episode"
        case \CachedProgramme.channel: return "channel"
        default:                       return "available"
        }
    }

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

    private func singleSelectedProgramme(from pids: Set<String>) -> CachedProgramme? {
        guard pids.count == 1, let pid = pids.first else { return nil }
        return sortedTableData.first(where: { $0.pid == pid })
    }


    var body: some View {
        VStack {
            Table(
                sortedTableData,
                selection: $selection,
                sortOrder: $sortOrder) {
                    TableColumn("Show", value: \.name) { program in
                        Text(program.name)
                            .foregroundStyle(downloadedPIDs.contains(program.pid) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    }
                    TableColumn("Episode", value: \.episode) { program in
                        Text(program.episode)
                            .foregroundStyle(downloadedPIDs.contains(program.pid) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    }
                    TableColumn("Last Broadcast", value: \.available) { program in
                        Text(program.available, style: .date)
                            .foregroundStyle(downloadedPIDs.contains(program.pid) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    }
                    TableColumn("Network", value: \.channel) { program in
                        Text(program.channel)
                            .foregroundStyle(downloadedPIDs.contains(program.pid) ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    }
                }
                .onChange(of: tableData) { sortedTableData = tableData.sorted(using: sortOrder) }
                .onChange(of: sortOrder)  {
                    sortedTableData = tableData.sorted(using: sortOrder)
                    if let first = sortOrder.first {
                        searchSortColumn = columnKey(for: first)
                        searchSortAscending = (first.order == .forward)
                    }
                }
                .task {
                    if sortOrder.isEmpty {
                        sortOrder = [Self.comparator(column: searchSortColumn, ascending: searchSortAscending)]
                    }
                    sortedTableData = tableData.sorted(using: sortOrder)
                }
                .contextMenu(forSelectionType: CachedProgramme.ID.self) { programs in
                    Button("Add To Download Queue") {
                        addItemsToQueueAndOpen(pids: programs)
                    }
                    Button("Record Series") {
                        addSelectedSeriesToAutoRecord(pids: programs)
                    }
                    if let programme = singleSelectedProgramme(from: programs) {
                        Divider()
                        Button("Show Programme Information…") {
                            programInfoTarget = programme
                        }
                    }
                } primaryAction: { pids in
                    addItemsToQueueAndOpen(pids: pids)
                }
                .sheet(item: $programInfoTarget) { programme in
                    ProgramInfoView(programme: programme)
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
        radio: false, realPID: ""
    )
    let program2 = CachedProgramme(
        pid: "sample002", index: 2, type: .tv,
        name: "Another Show", episode: "Episode 5",
        seriesNum: 0, episodeNum: 0, channel: "BBC Two",
        available: Date(), expires: nil, duration: 0,
        desc: "Another sample programme",
        web: nil, thumbnail: nil, timeadded: nil,
        radio: false, realPID: ""
    )
    SearchTableView(
        downloadQueueViewModel: mockQueue,
        pvrViewModel: pvrViewModel,
        selection: .constant([]),
        tableData: [program1, program2]
    )
}

