//
//  MockDownloadHistoryModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/8/26.
//

import Foundation
import OrderedCollections
import Observation

@Observable
class MockDownloadHistoryModel: DownloadHistoryProviding {
    var downloadHistory: OrderedSet<DownloadHistoryEntry> = []
    
    init() {
        // Create sample data for previews
        let entry1 = DownloadHistoryEntry(
            pid: "m001abc1",
            show: "Doctor Who",
            episode: "The Star Beast",
            type: .tv,
            someNumber: "1699900000",
            downloadFormat: "hd",
            downloadPath: "/Downloads/Doctor Who - The Star Beast.mp4"
        )
        
        let entry2 = DownloadHistoryEntry(
            pid: "m001abc2",
            show: "Strictly Come Dancing",
            episode: "Series 21, Episode 10",
            type: .tv,
            someNumber: "1699800000",
            downloadFormat: "hd",
            downloadPath: "/Downloads/Strictly Come Dancing - S21E10.mp4"
        )
        
        let entry3 = DownloadHistoryEntry(
            pid: "m001abc3",
            show: "Desert Island Discs",
            episode: "Guest: Sample Person",
            type: .radio,
            someNumber: "1699700000",
            downloadFormat: "high",
            downloadPath: "/Downloads/Desert Island Discs - Sample Person.m4a"
        )
        
        downloadHistory = [entry1, entry2, entry3]
    }
    
    func readDownloadHistory() {
        // No-op for mock
    }
    
    func removeEntries(_ entries: Set<UUID>) {
        for entry in entries {
            downloadHistory.removeAll { $0.id == entry }
        }
    }
    
    func writeHistory() {
        // No-op for mock
    }
    
    func addToHistory(programs: [Programme]) {
        // No-op for mock
    }
}
