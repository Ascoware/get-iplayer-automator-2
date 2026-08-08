//
//  DownloadQueueViewModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/27/23.
//

import Foundation
import SwiftUI
import OrderedCollections
import CocoaLumberjackSwift
import Observation

@MainActor
@Observable
class DownloadQueueViewModel: DownloadQueueProviding {

    @available(*, deprecated, message: "Use dependency injection instead")
    static let shared = DownloadQueueViewModel(cacheProvider: CachedProgramsViewModel.shared, historyModel: DownloadHistoryModel(loadHistory: false))

    private let cacheProvider: any ProgramCacheProviding
    private let historyModel: any DownloadHistoryProviding

    public init(cacheProvider: any ProgramCacheProviding, historyModel: any DownloadHistoryProviding) {
        self.cacheProvider = cacheProvider
        self.historyModel = historyModel
        loadAppData()
    }

    @ObservationIgnored @Default(\.addToTV) var addToTV: Bool
    @ObservationIgnored @Default(\.autoRetryOnFailure) var autoRetryOnFailure: Bool
    @ObservationIgnored @Default(\.autoRetryDelayMinutes) var autoRetryDelayMinutes: Int

    var downloadQueue: [Programme] = []

    public var isDownloading: Bool {
        return currentDownload != nil && !downloadsCancelled
    }

    var retryTimerActive = false
    var retryFireDate: Date?

    var processPIDRunning = false
    var downloadsCancelled = false

    internal var currentDownload: Task<Void, Never>? = nil
    private var activeDownload: Download?
    private var retryTask: Task<Void, Never>?

    public func addToQueue(programs: [Programme]) {
        let existingPIDs = Set(downloadQueue.map(\.pid))
        let newPrograms = programs.filter { !existingPIDs.contains($0.pid) }
        downloadQueue.append(contentsOf: newPrograms)
        saveAppData()
    }

    public func addToQueue(program: Programme) {
        guard !downloadQueue.contains(where: { $0.pid == program.pid }) else { return }
        downloadQueue.append(program)
        saveAppData()
    }

    public func removeFromQueue(pid: String) {
        downloadQueue.removeAll { p in
            p.pid == pid
        }
        saveAppData()
    }

    public func movePrograms(fromOffsets: IndexSet, toOffset: Int) {
        downloadQueue.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveAppData()
    }

    public func startDownloads() {
        cancelRetryTimer()
        downloadsCancelled = false
        downloadQueue.removeAll { p in
            p.successful
        }

        downloadQueue.forEach { p in
            p.complete = false
            p.progress = ""
        }

        startOneDownload()
    }

    private func startOneDownload() {
        guard !downloadsCancelled else { return }

        guard let currProgram = nextDownloadableShow() else {
            scheduleRetryIfNeeded()
            return
        }

        if currProgram.type.usesYtDlp && historyModel.downloadHistory.contains(where: { $0.pid == currProgram.pid }) {
            DDLogInfo("\(currProgram.name) is already in download history, skipping")
            currProgram.status = .failed
            currProgram.complete = true
            currProgram.progress = "Failed: In download history"
            startOneDownload()
            return
        }

        let download: Download

        if currProgram.type.usesYtDlp {
            download = STVDownload(programme: currProgram)
        } else {
            download = BBCDownload(programme: currProgram)
        }

        self.activeDownload = download

        currentDownload = Task {
            await download.start()
            self.activeDownload = nil

            // Don't process results or continue if cancelled
            guard !downloadsCancelled else { return }

            if currProgram.status == .finishedProgramDownload || currProgram.status == .finishedTagging {
                if addToTV {
                    currProgram.status = .addingToLibrary
                    await addToITunes(show: currProgram)
                } else {
                    currProgram.status = .successful
                }
            }

            if currProgram.successful {
                if currProgram.type.usesYtDlp {
                    historyModel.addToHistory(programs: [currProgram])
                } else {
                    historyModel.readDownloadHistory()
                }
            }

            currentDownload = nil

            // Only continue to the next download if downloads weren't cancelled
            guard !downloadsCancelled else { return }
            startOneDownload()
        }
    }

    /// Number of metadata fetches allowed in flight at once. A series page can yield well over
    /// a hundred PIDs, and we shouldn't open that many connections to the BBC at once.
    private static let maxConcurrentMetadataFetches = 5

    /// Resolves a PID to a `Programme`, preferring the direct JSON fetch.
    ///
    /// `BBCProgrammeJSONFetch` covers every field we keep in a single request. `get_iplayer
    /// --info` is the fallback for the cases it can't handle — a PID that isn't an episode or
    /// clip, a geoblocked programme, or a transient HTTP failure.
    private func fetchProgramme(pid: String) async -> Programme? {
        do {
            return try await BBCProgrammeJSONFetch(pid: pid).getProgramme()
        } catch {
            DDLogError("JSON metadata fetch failed for \(pid) (\(error)) — falling back to get_iplayer --info")
            return await ProgrammeMetadataFetch(pid: pid).getProgramme()
        }
    }

    public func addToQueue(pid: String) {
        if let cached = cacheProvider.findProgrammeFromPID(pid: pid) {
            addToQueue(program: cached.toQueueItem())
        } else {
            Task {
                processPIDRunning = true
                if let program = await fetchProgramme(pid: pid) {
                    addToQueue(program: program)
                }
                processPIDRunning = false
            }
        }
    }

    /// Adds many PIDs at once, resolving uncached ones concurrently.
    ///
    /// Adding each PID individually spawned an unbounded `Task` per programme, so a series
    /// page fired ~170 overlapping metadata fetches and left `processPIDRunning` being set and
    /// cleared by all of them at once.
    public func addToQueue(pids: [String]) async {
        guard !pids.isEmpty else { return }

        var resolved = [Programme?](repeating: nil, count: pids.count)
        var needsFetch: [(offset: Int, pid: String)] = []

        for (offset, pid) in pids.enumerated() {
            if let cached = cacheProvider.findProgrammeFromPID(pid: pid) {
                resolved[offset] = cached.toQueueItem()
            } else {
                needsFetch.append((offset, pid))
            }
        }

        if !needsFetch.isEmpty {
            processPIDRunning = true

            await withTaskGroup(of: (Int, Programme?).self) { group in
                var nextIndex = 0

                func addNext() {
                    guard nextIndex < needsFetch.count else { return }
                    let entry = needsFetch[nextIndex]
                    nextIndex += 1
                    group.addTask { (entry.offset, await self.fetchProgramme(pid: entry.pid)) }
                }

                for _ in 0..<Self.maxConcurrentMetadataFetches { addNext() }

                // Keep the window full: start another fetch as each one lands.
                while let (offset, programme) = await group.next() {
                    resolved[offset] = programme
                    addNext()
                }
            }

            processPIDRunning = false
        }

        // Queue in the order the PIDs arrived, regardless of which fetches finished first.
        addToQueue(programs: resolved.compactMap { $0 })
    }

    public func addToQueueFromPVR(pid: String) {
        if let cached = cacheProvider.findProgrammeFromPID(pid: pid) {
            let program = cached.toQueueItem()
            program.status = .addedByPVR
            program.progress = "Added by Series-Link"
            addToQueue(program: program)
        } else {
            Task {
                processPIDRunning = true
                if let program = await fetchProgramme(pid: pid) {
                    program.status = .addedByPVR
                    addToQueue(program: program)
                }
                processPIDRunning = false
            }
        }
    }
    
    public func getCurrentWebpage() async {
        let scanner = GetCurrentWebpage()
        await scanner.getCurrentWebpage()

        // Add BBC programs by PID (looked up via cache or metadata fetch)
        await addToQueue(pids: scanner.programIDs)

        // Add STV programs directly (already have full metadata)
        addToQueue(programs: scanner.programs)
    }

    public func processExtensionPayload() async {
        let scanner = GetCurrentWebpage()
        await scanner.processExtensionPayload()

        await addToQueue(pids: scanner.programIDs)
        addToQueue(programs: scanner.programs)
    }

    func nextDownloadableShow() -> Programme? {
        if downloadsCancelled {
            return nil
        }

        return downloadQueue.first { p in
            !p.successful && !p.complete && p.readyToDownload
        }
    }

    public func stopDownloads() {
        downloadsCancelled = true
        cancelRetryTimer()
        activeDownload?.cancel()
        activeDownload = nil
        currentDownload?.cancel()
        currentDownload = nil
    }

    public func cancelRetryTimer() {
        retryTask?.cancel()
        retryTask = nil
        retryTimerActive = false
        retryFireDate = nil
    }

    private func scheduleRetryIfNeeded() {
        guard autoRetryOnFailure else { return }

        let hasFailures = downloadQueue.contains { $0.status == .failed }
        guard hasFailures else { return }

        let delayMinutes = autoRetryDelayMinutes
        let fireDate = Date().addingTimeInterval(TimeInterval(delayMinutes * 60))
        retryFireDate = fireDate
        retryTimerActive = true

        DDLogInfo("Scheduling retry in \(delayMinutes) minutes")

        retryTask = Task {
            do {
                try await Task.sleep(for: .seconds(delayMinutes * 60))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            retryTimerActive = false
            retryFireDate = nil
            retryTask = nil
            retryFailedDownloads()
        }
    }

    private func retryFailedDownloads() {
        downloadsCancelled = false

        for program in downloadQueue where program.status == .failed {
            program.complete = false
            program.status = .processedPID
            program.progress = ""
        }

        startOneDownload()
    }

    private func addToITunes(show: Programme) async {
        var appName: String?

        // Thankfully, TV.app supports the same AppleEvents as iTunes. Use TV.app if present, but if not
        // try iTunes.app.
        var iTunes: TVApplication?

        switch (show.type) {
        case .radio:
            iTunes = SBApplication(bundleIdentifier:"com.apple.Music")
            appName = "Music"

        default:
            iTunes = SBApplication(bundleIdentifier:"com.apple.TV")
            appName = "TV"
        }

        guard let iTunes, let appName else {
            show.progress = "Complete: No media app available"
            show.status = .successful
            return
        }

        DDLogInfo("Adding \(show.name) to \(appName)")

        let downloadUrl = URL(filePath: show.downloadPath)
        let ext = downloadUrl.pathExtension
        let fileToAdd = [URL(filePath: show.downloadPath)]

        // Music and TV will not store the track if the app isn't fully up and running when the add command is received.
        // Launch the app and wait for it to be ready before adding.
        if !iTunes.isRunning {
            iTunes.activate()
        }

        // Wait for the app to be ready to receive Apple Events
        try? await Task.sleep(for: .seconds(2))

        if ext == "mov" || ext == "mp4" || ext == "mp3" || ext == "m4a" {
            let track = iTunes.add?(fileToAdd, to: nil)
            let trackExists = track?.exists?() ?? false
            if let track {
                DDLogVerbose("Track exists = \(trackExists ? "YES" : "NO")")
                if trackExists && (ext == "mov" || ext == "mp4") {
                    track.setUnplayed?(true)
                    show.progress = "Complete & in \(appName)"
                } else if trackExists && (ext == "mp3" || ext == "m4a") {
                    track.setBookmarkable?(true)
                    track.setUnplayed?(true)
                    show.progress = "Complete & in \(appName)"
                } else {
                    DDLogWarn("Media app did not accept file.")
                    DDLogWarn("Try dragging the file from the Finder into TV or iTunes.")
                    show.progress = "Complete: Not in \(appName)"
                }

                show.status = .successful
            } else {
                DDLogWarn("Can't add \(ext) file to \(appName) -- incompatible format.")
                show.status = .successful
            }
        } else {
            show.status = .successful
        }
    }

    public func loadAppData() {
        let appSupportFolder = FileManager.default.applicationSupportDirectory
        let fileURL = URL(filePath: appSupportFolder).appending(path: "queue.automator2queue")

        do {
            let data = try Data(contentsOf: fileURL)
            let loadedQueue = try JSONDecoder().decode([Programme].self, from: data)
            downloadQueue = loadedQueue
            DDLogInfo("Loaded \(loadedQueue.count) items from queue file")
        } catch {
            DDLogInfo("No existing queue file found or unable to load: \(error.localizedDescription)")
        }
    }

    public func saveAppData() {
        let cleanedQueue = downloadQueue.filter { p in
            !(p.complete && p.successful) && p.status != .addedByPVR
        }

        let appSupportFolder = FileManager.default.applicationSupportDirectory
        let fileURL = URL(filePath: appSupportFolder).appending(path: "queue.automator2queue")

        do {
            let data = try JSONEncoder().encode(cleanedQueue)
            try data.write(to: fileURL, options: .atomic)
            DDLogVerbose("Saved \(cleanedQueue.count) items to queue file")
        } catch {
            DDLogError("Error saving queue data: \(error.localizedDescription)")
        }
    }
}
