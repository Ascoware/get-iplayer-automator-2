//
//  ViewType.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import Foundation

/// The sidebar's selectable views. Searching TV and radio together isn't a view
/// type -- the main window does that through `allShows(searchText:)`.
public enum SearchViewType: String, CaseIterable {
    case tv = "BBC TV"
    case radio = "BBC Radio"
}
