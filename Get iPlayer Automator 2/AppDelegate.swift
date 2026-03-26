//
//  AppDelegate.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/21/23.
//

import Foundation
import Sparkle
import SwiftUI
import UserNotifications
import CocoaLumberjackSwift

class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {

    var downloadQueueViewModel: DownloadQueueViewModel? = nil
    var cacheUpdateService: CacheUpdateService? = nil

    private var allowedToNotify = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Queue data is loaded in GetiPlayerAutomatorApp.task after the view model is injected

        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                self.allowedToNotify = granted
            } catch {
                DDLogError("Error while requesting notification authorization: \(error)")
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if !confirmExit() {
            return .terminateCancel
        }

        return .terminateNow;
    }

    @MainActor
    func confirmExit() -> Bool {
        guard let downloadQueueViewModel else {
            return true
        }

        if downloadQueueViewModel.isDownloading {
            let downloadAlert = NSAlert()
            downloadAlert.messageText = "Are you sure you wish to quit?";
            downloadAlert.addButton(withTitle:"No")
            downloadAlert.addButton(withTitle:"Yes")
            downloadAlert.informativeText = "You are currently downloading shows. If you quit, they will be cancelled."
            let response = downloadAlert.runModal()
            if response == .alertFirstButtonReturn {
                return false
            }
        } else if cacheUpdateService?.isUpdating == true {
            let updateAlert = NSAlert()
            updateAlert.messageText = "Are you sure you wish to quit?";
            updateAlert.addButton(withTitle:"No")
            updateAlert.addButton(withTitle:"Yes")
            updateAlert.informativeText = "Get iPlayer Automator is currently updating the cache. If you proceed with quiting, some series-link information will be lost. It is not recommended to quit during an update. Are you sure you wish to quit?"
            let response = updateAlert.runModal()
            if response == .alertFirstButtonReturn {
                return false
            }
        }

        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // End downloads if running
        if let downloadQueueViewModel,
           downloadQueueViewModel.isDownloading {
            downloadQueueViewModel.stopDownloads()
        }

        // Save queue data
        downloadQueueViewModel?.saveAppData()
    }

    func updaterDidFindValidUpdate(item: SUAppcastItem)
    {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Index Updated";
        content.body = "Get iPlayer Automator \(item.displayVersionString) is available."
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
