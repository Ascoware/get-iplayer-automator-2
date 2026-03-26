//
//  SidebarView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import SwiftUI

struct SearchSidebarView: View {
    @AppStorage("showTotals") var showTotals = true
    @Bindable var cachedProgramsViewModel: CachedProgramsViewModel

    var body: some View {
        List(selection: $cachedProgramsViewModel.viewType) {
            Section("WHAT'S ON") {
                ForEach(SearchViewType.allCases, id: \.self) { type in
                    if type != .all {
                        Text(type.rawValue)
                            .badge(showTotals ? cachedProgramsViewModel.viewCounts[type, default: 0] : 0)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

#Preview("Light Mode") {
    @Previewable @State var mockCache = CachedProgramsViewModel()
    SearchSidebarView(cachedProgramsViewModel: mockCache)
        .preferredColorScheme(.light)
        .frame(width: 200)
}
#Preview("Dark Mode") {
    @Previewable @State var mockCache = CachedProgramsViewModel()
    SearchSidebarView(cachedProgramsViewModel: mockCache)
        .preferredColorScheme(.dark)
        .frame(width: 200)
}

