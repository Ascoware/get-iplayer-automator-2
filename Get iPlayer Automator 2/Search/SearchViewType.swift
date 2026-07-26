//
//  ViewType.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import Foundation

public enum SearchViewType: String, CaseIterable {
    case tv = "BBC TV"
    case radio = "BBC Radio"
    case all = "All Shows"

    func radio() -> Bool {
        self == .radio || self == .all
    }

    func tv() -> Bool {
        self == .tv || self == .all
    }

}
