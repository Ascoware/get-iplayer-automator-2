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
    }
}
