//
//  PreferencesWindow.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/1/23.
//

import SwiftUI

struct SettingsView: View {

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
            Tab("Formats", systemImage: "sparkles.tv") {
                FormatSettingsView()
            }
            Tab("New Programs", systemImage: "tv.and.mediabox") {
                ChannelsSettingsView()
            }
//            Tab("Advanced", systemImage: "star") {
//                AdvancedSettingsView()
//            }
        }
        .scenePadding()
        .frame(minWidth: 700, minHeight: 600)
    }
}

#Preview {
    SettingsView()
}
