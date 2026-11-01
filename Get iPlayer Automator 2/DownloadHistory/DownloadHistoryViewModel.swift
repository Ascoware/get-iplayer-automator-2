//
//  DownloadHistoryViewModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/8/26.
//

import Foundation
import SwiftUI
import OrderedCollections
import Observation

@MainActor
@Observable
class DownloadHistoryViewModel {
    let historyModel: any DownloadHistoryProviding
    
    var selection: Set<DownloadHistoryEntry.ID> = []
    var sortOrder = [KeyPathComparator(\DownloadHistoryEntry.show)]
    private var pendingRemovals: Set<String> = []
    var isDirty: Bool { !pendingRemovals.isEmpty }
    var isShowingDiscardChanges = false
    
    var tableData: OrderedSet<DownloadHistoryEntry> {
        // Use the persisted record, since history reloads currently assign new UUIDs.
        return historyModel.downloadHistory.filter { !pendingRemovals.contains($0.entryString) }
    }
    
    var sortedTableData: [DownloadHistoryEntry] {
        return tableData.sorted(using: sortOrder)
    }
    
    var selectedEntries: [DownloadHistoryEntry] {
        guard !selection.isEmpty else {
            return []
        }
        
        return tableData.filter {
            selection.contains($0.id)
        }
    }
    
    var canRemove: Bool {
        return !selectedEntries.isEmpty
    }
    
    var canSave: Bool {
        return isDirty
    }
    
    init(historyModel: any DownloadHistoryProviding) {
        self.historyModel = historyModel
    }
    
    func removeSelected() {
        pendingRemovals.formUnion(selectedEntries.map(\.entryString))
        selection = []
    }
    
    @discardableResult
    func save() -> Bool {
        // Merge removals into the latest history, preserving downloads completed
        // while this window was open.
        historyModel.readDownloadHistory()
        let original = historyModel.downloadHistory
        let ids = Set(original.filter { pendingRemovals.contains($0.entryString) }.map(\.id))
        historyModel.removeEntries(ids)
        guard historyModel.writeHistory() else {
            historyModel.downloadHistory = original
            return false
        }
        pendingRemovals = []
        selection = []
        return true
    }
    
    func handleWindowClose() -> Bool {
        if isDirty {
            isShowingDiscardChanges = true
            return false
        }
        return true
    }
    
    func discardChanges() {
        pendingRemovals = []
        selection = []
        isShowingDiscardChanges = false
    }
    
    func cancelDiscard() {
        isShowingDiscardChanges = false
    }
}
