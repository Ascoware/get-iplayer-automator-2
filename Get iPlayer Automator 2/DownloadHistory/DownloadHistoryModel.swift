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

    public func readDownloadHistory() {
        DDLogVerbose("Read History")
        downloadHistory = []

        let historyFilePath = FileManager.default.applicationSupportDirectory.appending("download_history")
        DDLogInfo("Opening \(historyFilePath)")
        guard let historyFile = FileHandle(forReadingAtPath: historyFilePath) else {
            DDLogError("History file missing!")
            return
        }

        let historyFileData = historyFile.readDataToEndOfFile()

        guard let historyFileInfo = String(data:historyFileData, encoding:.utf8) else {
            DDLogError("Error reading history file")
            return
        }

        let historyEntries = historyFileInfo.components(separatedBy: .newlines)
        var newHistory = OrderedSet<DownloadHistoryEntry>()

        for line in historyEntries {
            if line.isEmpty {
                continue
            }

            let components = line.components(separatedBy: "|")
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
        try? historyFile.close()
        DDLogVerbose("End read history")
    }

    public func removeEntries(_ entries: Set<UUID>) {
        for entry in entries {
            downloadHistory.removeAll {
                $0.id == entry
            }
        }
    }

    public func writeHistory() {
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
            } catch {
                let alert = NSAlert()
                alert.informativeText = "Please submit a bug report saying that the history file could not be written to."
                alert.messageText = "Could not write to history file!"
                alert.addButton(withTitle:"OK")
                alert.runModal()
            }
        }
    }

    public func addToHistory(programs: [Programme]) {
        readDownloadHistory()

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
