//
//  Menus.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import CocoaLumberjackSwift
import Combine
import Sparkle
import SwiftUI
import UserNotifications

struct SearchWindowMenus: Commands {

    let cacheUpdateService: CacheUpdateService
    let updaterViewModel: UpdaterViewModel

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            CheckForUpdatesView(updaterViewModel: updaterViewModel)
        }

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

/// Wraps Sparkle's updater. Creating it with `startingUpdater: true` starts the
/// scheduled background update checks, and `checkForUpdates()` drives the manual
/// "Check for Updates…" menu item. Acts as its own updater delegate so it can
/// post a local notification when an update is found.
final class UpdaterViewModel: NSObject, ObservableObject, SPUUpdaterDelegate {
    private var updaterController: SPUStandardUpdaterController!
    @Published var canCheckForUpdates = false

    override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil)
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Update Available"
        content.body = "Get iPlayer Automator 2 \(item.displayVersionString) is available."
        let request = UNNotificationRequest(identifier: "", content: content, trigger: nil)
        Task {
            do {
                try await center.add(request)
            } catch {
                DDLogError("Error posting update notification: \(error)")
            }
        }
    }
}

private struct CheckForUpdatesView: View {
    @ObservedObject var updaterViewModel: UpdaterViewModel

    var body: some View {
        Button("Check for Updates…") {
            updaterViewModel.checkForUpdates()
        }
        .disabled(!updaterViewModel.canCheckForUpdates)
    }
}
