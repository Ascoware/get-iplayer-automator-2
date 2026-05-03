//
//  MockDownloadQueueViewModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/8/26.
//

import Foundation
import Observation

@MainActor
@Observable
class MockDownloadQueueViewModel: DownloadQueueProviding {
    var downloadQueue: [Programme] = []
    var currentDownload: Task<Void, Never>? = nil
    var processPIDRunning: Bool = false
    var downloadsCancelled: Bool = false
    var retryTimerActive: Bool = false
    var retryFireDate: Date? = nil

    var isDownloading: Bool {
        return currentDownload != nil && !downloadsCancelled
    }
    
    func addToQueue(programs: [Programme]) {
        downloadQueue.append(contentsOf: programs)
    }
    
    func addToQueue(program: Programme) {
        downloadQueue.append(program)
    }
    
    func addToQueue(pid: String) {
        // Mock: do nothing for PID-based adds
    }

    func addToQueueFromPVR(pid: String) {
        // Mock: do nothing
    }
    
    func removeFromQueue(pid: String) {
        downloadQueue.removeAll { $0.pid == pid }
    }

    func movePrograms(fromOffsets: IndexSet, toOffset: Int) {
        downloadQueue.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }
    
    func startDownloads() {
        // Mock: do nothing
    }
    
    func stopDownloads() {
        downloadsCancelled = true
    }

    func cancelRetryTimer() {
        retryTimerActive = false
        retryFireDate = nil
    }
    
    func getCurrentWebpage() async {
        // Mock: do nothing
    }

    func processExtensionPayload() async {
        // Mock: do nothing
    }
    
    func saveAppData() {
        // Mock: do nothing
    }
}
