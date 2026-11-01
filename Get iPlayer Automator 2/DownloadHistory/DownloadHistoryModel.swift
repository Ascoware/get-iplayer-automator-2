//
//  DownloadHistoryModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/10/23.
//

import Foundation
import CocoaLumberjackSwift
import OrderedCollections
import Observation

@MainActor
@Observable
class DownloadHistoryModel: DownloadHistoryProviding {

    var downloadHistory: OrderedSet<DownloadHistoryEntry> = []

    init(loadHistory: Bool = true) {
        if loadHistory {
            readDownloadHistory()
        }
    }

    @discardableResult
    public func readDownloadHistory() -> Bool {
        DDLogVerbose("Read History")
        let historyFilePath = URL(filePath: FileManager.default.applicationSupportDirectory, directoryHint: .isDirectory)
            .appending(path: "download_history")
        DDLogInfo("Opening \(historyFilePath)")
        let historyFileData: Data
        do {
            historyFileData = try Data(contentsOf: historyFilePath)
        } catch {
            DDLogError("Could not read history file: \(error)")
            return false
        }

        guard let historyFileInfo = String(data: historyFileData, encoding: .utf8) else {
            DDLogError("Error reading history file")
            return false
        }

        let historyEntries = historyFileInfo.components(separatedBy: .newlines)
        var newHistory = OrderedSet<DownloadHistoryEntry>()

        for line in historyEntries {
            if line.isEmpty {
                continue
            }

            let components = line.components(separatedBy: "|")
            guard components.count >= 7, !components[0].isEmpty else {
                DDLogWarn("Skipping malformed download history row: \(line)")
                continue
            }
            let progType = ProgrammeType(rawValue: components[3])

            let historyEntry = DownloadHistoryEntry(
                pid: components[0],
                show: components[1],
                episode: components[2],
                type: progType ?? .tv,
                someNumber: components[4],
                downloadFormat: components[5],
                downloadPath: components[6]
            )

            newHistory.append(historyEntry)
        }

        downloadHistory = newHistory
        DDLogVerbose("End read history")
        return true
    }

    public func removeEntries(_ entries: Set<UUID>) {
        for entry in entries {
            downloadHistory.removeAll {
                $0.id == entry
            }
        }
    }

    @discardableResult
    public func writeHistory() -> Bool {
        DDLogVerbose("Write History to File")

        var historyString = ""
        for entry in downloadHistory {
            historyString.append(entry.entryString)
            historyString.append("\n")
        }

        let historyFileURL = URL(filePath: FileManager.default.applicationSupportDirectory.appending("/download_history"), directoryHint: .notDirectory)
        let newHistoryFile = URL(filePath: "download_history", directoryHint: .notDirectory, relativeTo: URL.temporaryDirectory)
        if let historyData = historyString.data(using: .utf8) {
            do {
                try historyData.write(to: newHistoryFile, options: [.atomic])
                try _ = FileManager.default.replaceItemAt(historyFileURL, withItemAt: newHistoryFile, options: [.usingNewMetadataOnly])
                return true
            } catch {
                let alert = NSAlert()
                alert.informativeText = "Please submit a bug report saying that the history file could not be written to."
                alert.messageText = "Could not write to history file!"
                alert.addButton(withTitle:"OK")
                alert.runModal()
            }
        }
        return false
    }

    public func addToHistory(programs: [Programme]) {
        guard readDownloadHistory() else { return }

        var newEntries: [DownloadHistoryEntry] = []

        for p in programs {
            let dateNow = Date().timeIntervalSince1970
            let entry = DownloadHistoryEntry(
                pid: p.pid,
                show: p.name,
                episode: p.episode,
                type: p.type,
                someNumber: "\(dateNow)",
                downloadFormat: "hd",
                downloadPath: p.downloadPath)

            newEntries.append(entry)
        }

        downloadHistory.append(contentsOf: newEntries)
        writeHistory()
    }
}
