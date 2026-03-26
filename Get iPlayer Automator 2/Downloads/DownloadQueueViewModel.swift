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
    static let shared = DownloadQueueViewModel(cacheProvider: CachedProgramsViewModel.shared)

    private let cacheProvider: any ProgramCacheProviding

    public init(cacheProvider: any ProgramCacheProviding) {
        self.cacheProvider = cacheProvider
    }

    @ObservationIgnored @Default(\.addToTV) var addToTV: Bool

    var downloadQueue: [Programme] = []

    public var isDownloading: Bool {
        return currentDownload != nil && !downloadsCancelled
    }
    
    var processPIDRunning = false
    var downloadsCancelled = false
    
    internal var currentDownload: Task<Void, Never>? = nil
    private var activeDownload: Download?

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

        guard let currProgram = nextDownloadableShow() else { return }

        let download: Download

        if currProgram.type == .stv {
            download = ITVDownload(programme: currProgram)
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

            currentDownload = nil

            // Only continue to the next download if downloads weren't cancelled
            guard !downloadsCancelled else { return }
            startOneDownload()
        }
    }

    public func addToQueue(pid: String) {
        if let program = cacheProvider.findProgrammeFromPID(pid: pid) {
            addToQueue(program: program)
        } else {
            let fetcher = ProgrammeMetadataFetch(pid: pid)
            Task {
                processPIDRunning = true
                if let program = await fetcher.getProgramme() {
                    addToQueue(program: program)
                }
                processPIDRunning = false
            }
        }
    }
    
    public func getCurrentWebpage() {
        let scanner = GetCurrentWebpage()
        scanner.getCurrentWebpage()

        // Add BBC programs by PID (looked up via cache or metadata fetch)
        for pid in scanner.programIDs {
            addToQueue(pid: pid)
        }

        // Add STV programs directly (already have full metadata)
        for program in scanner.programs {
            addToQueue(program: program)
        }
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
        activeDownload?.cancel()
        activeDownload = nil
        currentDownload?.cancel()
        currentDownload = nil
    }

    private func addToITunes(show: Programme) async {
        var appName: String?

        // Thankfully, TV.app supports the same AppleEvents as iTunes. Use TV.app if present, but if not
        // try iTunes.app.
        var iTunes: TVApplication?

        switch (show.type) {
        case .radio:
            if (!show.podcast) {
                iTunes = SBApplication(bundleIdentifier:"com.apple.Music")
                appName = "Music"
            }

        default:
            iTunes = SBApplication(bundleIdentifier:"com.apple.TV")
            appName = "TV"
        }

        // In this case it's a podcast and we're on Catalina or later. Can't do much with it, unfortunately.
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
            !(p.complete && p.successful) && p.progress != "Added by Series-Link"
        }

        let appSupportFolder = FileManager.default.applicationSupportDirectory
        let fileURL = URL(filePath: appSupportFolder).appending(path: "queue.automator2queue")

        do {
            let data = try JSONEncoder().encode(cleanedQueue)
            try data.write(to: fileURL, options: .atomic)
            DDLogInfo("Saved \(cleanedQueue.count) items to queue file")
        } catch {
            DDLogError("Error saving queue data: \(error.localizedDescription)")
        }
    }
}
