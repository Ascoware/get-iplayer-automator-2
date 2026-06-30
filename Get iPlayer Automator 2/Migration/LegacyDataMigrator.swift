//
//  LegacyDataMigrator.swift
//  Get iPlayer Automator 2
//
//  Handles one-time migration of data from the old Get iPlayer Automator app.
//  Reads NSKeyedArchiver files and NSUserDefaults from the old app's domain
//  and converts them to the new app's JSON and @AppStorage formats.
//

import Foundation
import CocoaLumberjackSwift

class LegacyDataMigrator {

    static let migrationCompleteKey = "legacyMigrationComplete"

    private static let oldBundleID = "com.ascoware.getiPlayerAutomator"

    private let oldAppSupportPath: String
    private let newAppSupportPath: String

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        oldAppSupportPath = home
            .appendingPathComponent("Library/Application Support/Get iPlayer Automator")
            .path(percentEncoded: false)
        newAppSupportPath = FileManager.default.applicationSupportDirectory
    }

    // MARK: - Public API

    static func shouldOfferMigration() -> Bool {
        let flagValue = UserDefaults.standard.bool(forKey: migrationCompleteKey)
        DDLogVerbose("Migration: migrationComplete flag = \(flagValue)")
        guard !flagValue else {
            DDLogVerbose("Migration: Skipping — migration already marked complete")
            return false
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let oldPath = home
            .appendingPathComponent("Library/Application Support/Get iPlayer Automator")
            .path(percentEncoded: false)

        DDLogVerbose("Migration: Looking for old data at \(oldPath)")

        let fm = FileManager.default
        let dataFiles = ["Queue.automatorqueue", "download_history", "Formats.automatorqueue"]
        for file in dataFiles {
            let fullPath = (oldPath as NSString).appendingPathComponent(file)
            let exists = fm.fileExists(atPath: fullPath)
            DDLogVerbose("Migration: \(file) exists = \(exists)")
        }
        let found = dataFiles.contains { fm.fileExists(atPath: (oldPath as NSString).appendingPathComponent($0)) }
        DDLogVerbose("Migration: shouldOfferMigration returning \(found)")
        return found
    }

    static func markMigrationComplete() {
        UserDefaults.standard.set(true, forKey: migrationCompleteKey)
    }

    @MainActor func performMigration() {
        DDLogVerbose("Starting legacy data migration from \(oldAppSupportPath)")

        migrateDownloadHistory()
        migrateSeriesAndQueue()
        migrateFormatPreferences()
        migrateUserPreferences()

        DDLogInfo("Legacy data migration complete")
    }

    // MARK: - Download History

    private func migrateDownloadHistory() {
        let oldFile = (oldAppSupportPath as NSString).appendingPathComponent("download_history")
        let newFile = (newAppSupportPath as NSString).appendingPathComponent("download_history")

        guard FileManager.default.fileExists(atPath: oldFile) else {
            DDLogVerbose("Migration: No old download_history found, skipping")
            return
        }

        do {
            let oldContent = try String(contentsOfFile: oldFile, encoding: .utf8)
            let oldLines = oldContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

            // Convert itv → stv in the type field (column index 3)
            let convertedLines = oldLines.map { line -> String in
                var components = line.components(separatedBy: "|")
                if components.count >= 4 && components[3] == "itv" {
                    components[3] = "stv"
                    return components.joined(separator: "|")
                }
                return line
            }

            if FileManager.default.fileExists(atPath: newFile) {
                // Merge: append entries not already present (by PID)
                let existingContent = (try? String(contentsOfFile: newFile, encoding: .utf8)) ?? ""
                let existingPIDs = Set(
                    existingContent.components(separatedBy: .newlines)
                        .filter { !$0.isEmpty }
                        .compactMap { $0.components(separatedBy: "|").first }
                )

                let newEntries = convertedLines.filter { line in
                    guard let pid = line.components(separatedBy: "|").first else { return false }
                    return !existingPIDs.contains(pid)
                }

                if !newEntries.isEmpty {
                    let appendString = "\n" + newEntries.joined(separator: "\n") + "\n"
                    if let data = appendString.data(using: .utf8),
                       let handle = FileHandle(forWritingAtPath: newFile) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        try handle.close()
                        DDLogVerbose("Migration: Appended \(newEntries.count) history entries")
                    }
                }
            } else {
                let content = convertedLines.joined(separator: "\n") + "\n"
                try content.write(toFile: newFile, atomically: true, encoding: .utf8)
                DDLogVerbose("Migration: Wrote \(convertedLines.count) history entries")
            }
        } catch {
            DDLogError("Migration: Failed to migrate download history: \(error)")
        }
    }

    // MARK: - Series List and Download Queue

    @MainActor private func migrateSeriesAndQueue() {
        let oldFile = (oldAppSupportPath as NSString).appendingPathComponent("Queue.automatorqueue")

        guard FileManager.default.fileExists(atPath: oldFile) else {
            DDLogInfo("Migration: No old Queue.automatorqueue found, skipping")
            return
        }

        do {
            let data = try Data(contentsOf: URL(filePath: oldFile))
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false

            // Map archived class names to our legacy wrapper classes
            unarchiver.setClass(LegacySeries.self, forClassName: "Series")
            unarchiver.setClass(LegacyProgramme.self, forClassName: "Programme")

            let rootObject = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSDictionary
            unarchiver.finishDecoding()

            // Migrate series
            migrateSeriesList(from: rootObject)

            // Migrate queue
            migrateQueue(from: rootObject)

        } catch {
            DDLogError("Migration: Failed to decode Queue.automatorqueue: \(error)")
        }
    }

    private func migrateSeriesList(from rootObject: NSDictionary?) {
        let seriesFile = (newAppSupportPath as NSString).appendingPathComponent("series.pvrdata")

        // Don't overwrite if new data already exists
        if FileManager.default.fileExists(atPath: seriesFile),
           let existing = try? Data(contentsOf: URL(filePath: seriesFile)),
           !existing.isEmpty {
            DDLogInfo("Migration: series.pvrdata already exists, skipping series migration")
            return
        }

        guard let legacySeries = rootObject?["serieslink"] as? [LegacySeries] else {
            DDLogInfo("Migration: No series data found in archive")
            return
        }

        let newSeries = legacySeries
            .map { $0.toNewSeries() }
            .filter { !$0.showName.isEmpty }

        do {
            let jsonData = try JSONEncoder().encode(newSeries)
            try jsonData.write(to: URL(filePath: seriesFile), options: .atomic)
            DDLogInfo("Migration: Wrote \(newSeries.count) series entries")
        } catch {
            DDLogError("Migration: Failed to write series data: \(error)")
        }
    }

    @MainActor
    private func migrateQueue(from rootObject: NSDictionary?) {
        let queueFile = (newAppSupportPath as NSString).appendingPathComponent("queue.automator2queue")

        // Don't overwrite if new data already exists
        if FileManager.default.fileExists(atPath: queueFile),
           let existing = try? Data(contentsOf: URL(filePath: queueFile)),
           !existing.isEmpty {
            DDLogInfo("Migration: queue.automator2queue already exists, skipping queue migration")
            return
        }

        guard let legacyQueue = rootObject?["queue"] as? [LegacyProgramme] else {
            DDLogInfo("Migration: No queue data found in archive")
            return
        }

        // Filter out completed/successful items, matching DownloadQueueViewModel.saveAppData() behavior
        let newQueue = legacyQueue
            .map { $0.toNewProgramme() }
            .filter { !(($0.complete && $0.successful) || $0.status == .addedByPVR) }

        do {
            let jsonData = try JSONEncoder().encode(newQueue)
            try jsonData.write(to: URL(filePath: queueFile), options: .atomic)
            DDLogInfo("Migration: Wrote \(newQueue.count) queue entries")
        } catch {
            DDLogError("Migration: Failed to write queue data: \(error)")
        }
    }

    // MARK: - Format Preferences

    private func migrateFormatPreferences() {
        let oldFile = (oldAppSupportPath as NSString).appendingPathComponent("Formats.automatorqueue")

        guard FileManager.default.fileExists(atPath: oldFile) else {
            DDLogInfo("Migration: No old Formats.automatorqueue found, skipping")
            return
        }

        do {
            let data = try Data(contentsOf: URL(filePath: oldFile))
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false

            unarchiver.setClass(LegacyTVFormat.self, forClassName: "TVFormat")
            unarchiver.setClass(LegacyRadioFormat.self, forClassName: "RadioFormat")

            let rootObject = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSDictionary
            unarchiver.finishDecoding()

            if let legacyTV = rootObject?["tvFormats"] as? [LegacyTVFormat] {
                let tvFormats = legacyTV.compactMap { $0.toNewFormat() }
                Defaults.shared.bbcTVFormats = tvFormats
                DDLogInfo("Migration: Imported \(tvFormats.count) TV format preferences")
            }

            if let legacyRadio = rootObject?["radioFormats"] as? [LegacyRadioFormat] {
                let radioFormats = legacyRadio.compactMap { $0.toNewFormat() }
                Defaults.shared.radioFormats = radioFormats
                DDLogInfo("Migration: Imported \(radioFormats.count) radio format preferences")
            }
        } catch {
            DDLogError("Migration: Failed to migrate format preferences: \(error)")
        }
    }

    // MARK: - User Preferences

    private func migrateUserPreferences() {
        guard let oldDefaults = UserDefaults(suiteName: LegacyDataMigrator.oldBundleID) else {
            DDLogInfo("Migration: Could not read old UserDefaults, skipping preferences")
            return
        }

        let newDefaults = UserDefaults.standard

        // Helper to migrate a bool preference
        func migrateBool(from oldKey: String, to newKey: String) {
            if oldDefaults.object(forKey: oldKey) != nil {
                newDefaults.set(oldDefaults.bool(forKey: oldKey), forKey: newKey)
            }
        }

        // Helper to migrate a string-to-int preference
        func migrateStringToInt(from oldKey: String, to newKey: String) {
            if let oldValue = oldDefaults.string(forKey: oldKey), let intValue = Int(oldValue) {
                newDefaults.set(intValue, forKey: newKey)
            }
        }

        // Download path
        if let downloadPath = oldDefaults.string(forKey: "DownloadPath") {
            newDefaults.set(downloadPath, forKey: "downloadPath")
        }

        // Proxy: old app has "Proxy" (None/Custom/Provided) + "CustomProxy"
        if let proxyType = oldDefaults.string(forKey: "Proxy"), proxyType == "Custom" {
            if let customProxy = oldDefaults.string(forKey: "CustomProxy") {
                newDefaults.set(customProxy, forKey: "proxyHost")
            }
        }

        // Boolean preferences with different key names
        migrateBool(from: "AlwaysUseProxy", to: "alwaysUseProxy")
        migrateBool(from: "AutoRetryFailed", to: "autoRetry")
        migrateBool(from: "AddCompletedToiTunes", to: "addToTV")
        migrateBool(from: "CacheBBC_TV", to: "cacheBBCTV")
        migrateBool(from: "CacheITV_TV", to: "cacheITVTV")
        migrateBool(from: "CacheBBC_Radio", to: "cacheBBCRadio")
        migrateBool(from: "Verbose", to: "verbose")
        migrateBool(from: "SeriesLinkStartup", to: "addSeriesLinkAtStartup")
        migrateBool(from: "DownloadSubtitles", to: "downloadSubtitles")
        migrateBool(from: "EmbedSubtitles", to: "embedSubtitles")
        migrateBool(from: "XBMC_naming", to: "useKodiNaming")
        migrateBool(from: "RemoveOldSeries", to: "deleteOldSeriesLink")
        migrateBool(from: "TagShows", to: "tagDownloads")
        migrateBool(from: "TagRadioAsPodcast", to: "tagRadioAsPodcast")
        migrateBool(from: "AudioDescribedNew", to: "getAudioDescribedVideo")
        migrateBool(from: "SignedNew", to: "getSignedVideo")
        migrateBool(from: "Use25FPSStreams", to: "use25FPSStreams")
        migrateBool(from: "ShowITV", to: "ShowSTV")

        // String-to-int preferences
        migrateStringToInt(from: "AutoRetryTime", to: "autoRetryDelay")
        migrateStringToInt(from: "CacheExpiryTime", to: "cacheExpiryTime")
        migrateStringToInt(from: "KeepSeriesFor", to: "deleteOldSeriesLinkDuration")

        // Default browser
        if let browser = oldDefaults.string(forKey: "DefaultBrowser") {
            if SupportedBrowsers(rawValue: browser) != nil {
                newDefaults.set(browser, forKey: "defaultBrowser")
            }
        }

        // Channel filters and other booleans with the same key names in both apps
        let sameKeyBools = [
            "BBCOne", "BBCTwo", "BBCThree", "BBCFour",
            "CBBC", "CBeebies", "BBCNews", "BBCParliament",
            "Radio1", "Radio2", "Radio3", "Radio4", "Radio4Extra", "Radio6Music",
            "BBCWorldService", "Radio5Live", "Radio5LiveSportsExtra",
            "Radio1Xtra", "RadioAsianNetwork",
            "ShowRegionalRadioStations", "ShowLocalRadioStations",
            "ShowRegionalTVStations", "ShowLocalTVStations",
            "IgnoreAllTVNews", "IgnoreAllRadioNews",
            "ShowBBCTV", "ShowBBCRadio",
            "TestProxy", "ShowDownloadedInSearch"
        ]

        for key in sameKeyBools {
            migrateBool(from: key, to: key)
        }

        DDLogInfo("Migration: User preferences migrated")
    }
}
