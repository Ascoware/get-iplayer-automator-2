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
    var isDirty = false
    var isShowingDiscardChanges = false
    
    var tableData: OrderedSet<DownloadHistoryEntry> {
        return historyModel.downloadHistory
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
        return selection.count > 0
    }
    
    var canSave: Bool {
        return isDirty
    }
    
    init(historyModel: any DownloadHistoryProviding) {
        self.historyModel = historyModel
    }
    
    func removeSelected() {
        historyModel.removeEntries(selection)
        selection = []
        isDirty = true
    }
    
    func save() {
        historyModel.writeHistory()
        isDirty = false
    }
    
    func handleWindowClose() -> Bool {
        if isDirty {
            isShowingDiscardChanges = true
            return false
        }
        return true
    }
    
    func saveAndDismiss() {
        save()
        isShowingDiscardChanges = false
    }
    
    func cancelDiscard() {
        isShowingDiscardChanges = false
    }
}
