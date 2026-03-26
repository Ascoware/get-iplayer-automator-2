//
//  ViewType.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import Foundation

public enum SearchViewType: String, CaseIterable {
    case tvToday = "TV Today"
    case allTV = "All TV Shows"
    case radioToday = "Radio Today"
    case allRadio = "All Radio Shows"
    case all = "All Shows"

    func radio() -> Bool {
        self == .radioToday || self == .allRadio || self == .all
    }

    func tv() -> Bool {
        self == .tvToday || self == .allTV || self == .all
    }

}
