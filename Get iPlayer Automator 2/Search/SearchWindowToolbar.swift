//
//  Toolbar.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import SwiftUI

struct SearchWindowToolbar: CustomizableToolbarContent {

    var downloadQueueViewModel: any DownloadQueueProviding
    var pvrViewModel: PVRViewModel
    @Binding var selection: Set<String>
    let tableData: [CachedProgramme]
    @Environment(\.openWindow) private var openWindow

    var body: some CustomizableToolbarContent {
        ToolbarItem(
            id: "toggleSidebar",
            placement: .navigation,
            showsByDefault: true) {
                Button {
                    toggleSidebar()
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                        .imageScale(.large)
                }
                .help("Toggle Sidebar")
            }
        ToolbarItem(
            id: "addToQueue",
            placement: .automatic,
            showsByDefault: true) {
                Button {
                    for p in selection {
                        downloadQueueViewModel.addToQueue(pid: p)
                    }
                    openWindow(id: "dl-queue")
                } label: {
                    Label("Add to Queue", systemImage: "rectangle.stack.badge.plus")
                        .imageScale(.large)
                }
                .help("Add selected items to download queue")
                .disabled(selection.isEmpty)
            }
        ToolbarItem(
            id: "autoRecord",
            placement: .automatic,
            showsByDefault: true) {
                Button {
                    addSelectedSeriesToAutoRecord()
                } label: {
                    Label("Auto-record", systemImage: "recordingtape.circle")
                        .imageScale(.large)
                }
                .help("Add the selected show to the auto-record list")
                .disabled(selection.isEmpty)
            }
    }

    private func addSelectedSeriesToAutoRecord() {
        for pid in selection {
            guard let programme = tableData.first(where: { $0.pid == pid }) else { continue }
            pvrViewModel.addSeries(showName: programme.name, tvNetwork: programme.channel)
        }
    }

    func toggleSidebar() {
        NSApp.keyWindow?
            .contentViewController?
            .tryToPerform(
                #selector(NSSplitViewController.toggleSidebar(_:)),
                with: nil)
    }
}
