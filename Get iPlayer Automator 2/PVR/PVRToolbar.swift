//
//  PVRToolbar.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 10/14/23.
//

import SwiftUI

struct PVRToolbar: CustomizableToolbarContent {

    var pvrViewModel: PVRViewModel

    /// UUIDs selected in the series list.
    @Binding var seriesSelection: Set<UUID>

    var body: some CustomizableToolbarContent {
        ToolbarItem(
            id: "checkNow",
            placement: .automatic,
            showsByDefault: true
        ) {
            Button {
                Task { await pvrViewModel.checkForNewEpisodes() }
            } label: {
                Label("Add Series", systemImage: "record.circle")
                    .imageScale(.large)
            }
            .toolbarHelp("Search for new episodes of all auto-recorded series", disabled: pvrViewModel.series.isEmpty || pvrViewModel.isChecking)
        }

        ToolbarItem(
            id: "removeSeries",
            placement: .automatic,
            showsByDefault: true
        ) {
            Button(role: .destructive) {
                removeSelectedSeries()
            } label: {
                Label("Remove", systemImage: "minus")
                    .imageScale(.large)
            }
            .toolbarHelp("Remove selected series from the auto-record list", disabled: seriesSelection.isEmpty)
        }
    }

    // MARK: - Actions

    private func removeSelectedSeries() {
        pvrViewModel.series.removeAll { seriesSelection.contains($0.id) }
        seriesSelection.removeAll()
        pvrViewModel.save()
    }
}
