//
//  Series.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 9/23/23.
//

import Foundation

struct Series: Equatable, Codable, Identifiable {

    let id: UUID
    var showName: String
    var added: Int
    var tvNetwork: String
    var lastFound: Date

    init(id: UUID = UUID(), showName: String, added: Int, tvNetwork: String, lastFound: Date) {
        self.id = id
        self.showName = showName
        self.added = added
        self.tvNetwork = tvNetwork
        self.lastFound = lastFound
    }
}
