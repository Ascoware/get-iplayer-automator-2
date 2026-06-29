//
//  CacheUpdateService.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/18/26.
//

import Foundation
import CocoaLumberjackSwift
import UserNotifications
import Observation
import Subprocess
import System

/// Service responsible for updating the get_iplayer program cache.
/// Separated from CachedProgramsViewModel to provide a clear separation of concerns.
@MainActor
@Observable
class CacheUpdateService {

    var currentProgress: String = ""
    var isUpdating: Bool = false
    private var cacheWasUpdated = false

    @ObservationIgnored @Default(\.cacheExpiryTime) var cacheExpiryTime

    private let onCacheUpdated: () -> Void

    /// Initialize the cache update service.
    /// - Parameter onCacheUpdated: Callback invoked when the cache has been successfully updated.
    public init(onCacheUpdated: @escaping () -> Void = {}) {
        self.onCacheUpdated = onCacheUpdated
    }

    /// Check if cache update is needed and update if so.
    public func checkForCacheUpdate() async {
        await updateCache(rebuild: false)
    }

    /// Force a full cache rebuild.
    public func rebuildCache() async {
        await updateCache(rebuild: true)
    }

    private func updateCache(rebuild: Bool) async {
        guard !isUpdating else {
            DDLogInfo("Cache update already in progress, skipping")
            return
        }

        cacheWasUpdated = false

        let typeArg = GetiPlayerArguments.shared.typeArgument(forCacheUpdate: true)

        if typeArg.isEmpty {
            DDLogWarn("No program types enabled for cache update")
            return
        }

        isUpdating = true
        var refreshSucceeded = false

        let cacheRefreshSeconds = Int(cacheExpiryTime) * 3600

        let cacheExpiryArg: String
        if rebuild {
            cacheExpiryArg = "--cache-rebuild"
        } else {
            cacheExpiryArg = "--expiry=\(cacheRefreshSeconds)"
        }

        let args = [
            GetiPlayerArguments.shared.getiPlayerPath,
            cacheExpiryArg,
            typeArg,
            "--refresh",
            GetiPlayerArguments.shared.profileDirArg,
            ".*"
        ]

        DDLogInfo("Updating Programme Index Feeds...")
        currentProgress = "Updating Programme Index Feeds..."

        for arg in args {
            DDLogVerbose("\(arg)")
        }

        do {
            _ = try await run(
                .path(FilePath(GetiPlayerArguments.shared.perlBinaryPath)),
                arguments: Arguments(args),
                environment: .inherit.updating([
                    "HOME": URL.homeDirectory.path(percentEncoded: false),
                    "PERL_UNICODE": "AS",
                    "PERLIO": ":unix",
                    "PATH": GetiPlayerArguments.shared.perlEnvironmentPath
                ]),
                error: .combinedWithOutput,
                preferredBufferSize: 128
            ) { execution, standardOutput in
                for try await line in standardOutput.lines() {
                    self.processOutput(line)
                }
            }
            refreshSucceeded = true
        } catch {
            DDLogError("Cache update failed: \(error)")
        }

        isUpdating = false

        // Reload the in-memory cache from disk whenever the refresh completes
        // successfully. We can't reliably detect whether the on-disk cache
        // actually changed from get_iplayer's output (its progress dots arrive
        // grouped, not as single "." lines), so don't gate the reload on
        // `cacheWasUpdated` — reloading from disk is cheap and idempotent.
        if refreshSucceeded {
            DDLogInfo("BBC Index Updated")
            onCacheUpdated()

            // Only post a user-facing notification when we have positive
            // evidence the index changed, to avoid spurious "Index Updated"
            // alerts on no-op refreshes.
            if cacheWasUpdated {
                await sendUpdateNotification()
            }
        }
    }

    private func processOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            if line.hasPrefix("INFO:") {
                DDLogInfo("\(line)")
                let actualMessage = line.replacingOccurrences(of: "INFO:", with: "")
                let infoMessage = "Updating Programme Indexes: " + actualMessage
                currentProgress = infoMessage
            } else if line.hasPrefix("WARNING:") {
                DDLogWarn("\(line)")
            } else if line.hasPrefix("ERROR:") {
                DDLogError("\(line)")
            } else if !line.isEmpty, line.allSatisfy({ $0 == "." }) {
                // get_iplayer prints feed-download progress as runs of dots
                // with no newlines, so they reach us grouped (e.g. "....."),
                // not as single "." lines. Any all-dots line means a real
                // refresh ran (a skipped/fresh refresh prints none), which is
                // our signal that the on-disk index may have changed. The
                // progress bar in ActivityView is indeterminate and the detail
                // text comes from INFO lines, so we don't render the dots.
                cacheWasUpdated = true
            }
        }
    }

    private func sendUpdateNotification() async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Index Updated"
        content.body = "The program index was updated."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        do {
            try await center.add(request)
        } catch {
            DDLogError("Failed to send notification: \(error.localizedDescription)")
        }
    }
}
