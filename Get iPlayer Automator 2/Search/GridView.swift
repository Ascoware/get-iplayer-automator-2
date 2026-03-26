//
//  GridView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import SwiftUI

struct GridView: View {
    var gridData: [Programme]

    var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 250, maximum: 250), spacing: 20)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(gridData) {
                    Text($0.pid)
//                    ProgrammeView(programme: $0)
                }
            }
        }
    }
}

#Preview {
    GridView(gridData: [])
}
