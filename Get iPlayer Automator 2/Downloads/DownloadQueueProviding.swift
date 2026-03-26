//
//  DownloadQueueProviding.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/8/26.
//

import Foundation

@MainActor
protocol DownloadQueueProviding: AnyObject {
    var downloadQueue: [Programme] { get set }
    var currentDownload: Task<Void, Never>? { get }
    var processPIDRunning: Bool { get set }
    var downloadsCancelled: Bool { get set }
    var isDownloading: Bool { get }
    
    func addToQueue(programs: [Programme])
    func addToQueue(program: Programme)
    func addToQueue(pid: String)
    func removeFromQueue(pid: String)
    func movePrograms(fromOffsets: IndexSet, toOffset: Int)
    func startDownloads()
    func stopDownloads()
    func getCurrentWebpage()
    func saveAppData()
}
