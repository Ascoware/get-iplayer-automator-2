//
//  DownloadHistoryProviding.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/8/26.
//

import Foundation
import OrderedCollections

@MainActor
protocol DownloadHistoryProviding: AnyObject {
    var downloadHistory: OrderedSet<DownloadHistoryEntry> { get set }
    
    @discardableResult func readDownloadHistory() -> Bool
    func removeEntries(_ entries: Set<UUID>)
    @discardableResult func writeHistory() -> Bool
    func addToHistory(programs: [Programme])
}
