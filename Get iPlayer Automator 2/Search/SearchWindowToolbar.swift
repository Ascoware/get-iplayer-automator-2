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
                .toolbarHelp("Add selected items to download queue", disabled: selection.isEmpty)
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
                .toolbarHelp("Add the selected show to the auto-record list", disabled: selection.isEmpty)
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

extension View {
    /// Applies a help tooltip that stays visible even while the control is
    /// disabled.
    ///
    /// macOS suppresses `.help(_:)` tooltips on disabled controls, so a
    /// greyed-out toolbar button in icon-only mode gives the user no hint about
    /// what it does. When `disabled` is true we additionally surface the
    /// tooltip through a transparent, still-enabled overlay that owns the hover
    /// tracking area. When the control is enabled the overlay is absent and the
    /// button's own `.help(_:)` provides the tooltip as usual.
    ///
    /// - Parameters:
    ///   - text: The hover text to display.
    ///   - disabled: Whether the underlying control is disabled.
    func toolbarHelp(_ text: String, disabled: Bool) -> some View {
        self
            .disabled(disabled)
            .help(text)
            .overlay {
                if disabled {
                    Color.clear
                        .contentShape(Rectangle())
                        .help(text)
                        .accessibilityHidden(true)
                }
            }
    }
}
