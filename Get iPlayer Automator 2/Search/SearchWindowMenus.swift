//
//  Menus.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import SwiftUI

struct SearchWindowMenus: Commands {

    let cacheUpdateService: CacheUpdateService

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Check for Cache Update") {
                Task {
                    await cacheUpdateService.checkForCacheUpdate()
                }
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button("Rebuild Cache") {
                Task {
                    await cacheUpdateService.rebuildCache()
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        CommandGroup(after: .windowArrangement) {
            OpenWindowButton(title: "Download Queue", windowID: "dl-queue")
                .keyboardShortcut("d", modifiers: [.command])
            OpenWindowButton(title: "Log", windowID: "log")
                .keyboardShortcut("l", modifiers: [.command])
            OpenWindowButton(title: "Activity", windowID: "activity")
                .keyboardShortcut("0", modifiers: [.command])
        }
    }
}

private struct OpenWindowButton: View {
    let title: String
    let windowID: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(title) {
            openWindow(id: windowID)
        }
    }
}
