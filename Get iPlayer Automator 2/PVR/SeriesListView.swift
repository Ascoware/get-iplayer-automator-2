//
//  SeriesListView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 3/1/26.
//

import SwiftUI

/// Displays the list of auto-recorded series and lets the user edit and remove entries.
struct SeriesListView: View {

    @Bindable var pvrViewModel: PVRViewModel
    @Binding var selection: Set<UUID>

    var body: some View {
        if pvrViewModel.series.isEmpty {
            emptyState
        } else {
            seriesTable
        }
    }

    // MARK: - Sub-views

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No series are being auto-recorded.")
                .foregroundStyle(.secondary)
            Text("Search for a show above and click Auto-record.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var seriesTable: some View {
        Table(pvrViewModel.series, selection: $selection) {
            TableColumn("Show") { series in
                // Bind directly into the array element via the index.
                if let index = pvrViewModel.series.firstIndex(where: { $0.id == series.id }) {
                    TextField("Show name", text: $pvrViewModel.series[index].showName)
                        .textFieldStyle(.plain)
                        .onSubmit { pvrViewModel.save() }
                }
            }
            TableColumn("Channel") { series in
                if let index = pvrViewModel.series.firstIndex(where: { $0.id == series.id }) {
                    TextField("Any (wildcard)", text: $pvrViewModel.series[index].tvNetwork)
                        .textFieldStyle(.plain)
                        .foregroundStyle(series.tvNetwork.isEmpty ? .secondary : .primary)
                        .onSubmit { pvrViewModel.save() }
                }
            }
            .width(min: 80, ideal: 150)
            TableColumn("Last Checked") { series in
                Text(series.lastFound, style: .date)
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)
        }
    }
}

#Preview {
    @Previewable @State var selection: Set<UUID> = []
    let queue = MockDownloadQueueViewModel()
    let pvrViewModel = PVRViewModel(downloadQueueViewModel: queue)
    pvrViewModel.series = [
        Series(showName: "Blue Planet", added: 0, tvNetwork: "BBC One", lastFound: Date()),
        Series(showName: "Peaky Blinders", added: 0, tvNetwork: "", lastFound: Date()),
    ]
    return SeriesListView(pvrViewModel: pvrViewModel, selection: $selection)
}
