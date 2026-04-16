//
//  FormatSettingsView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/1/23.
//

import SwiftUI

struct FormatSettingsView: View {

    @Default(\.bbcTVFormats) var tvFormats: [TVFormat]
    @Default(\.radioFormats) var radioFormats: [RadioFormat]
    @Default(\.maxSTVResolution) var maxSTVSize: TVFormat

    var body: some View {
        VStack {
            GroupBox(label: Text("BBC TV Formats")) {
                List($tvFormats, editActions: .move) { $format in
                    TokenView(title: format.desc) { title in
                        tvFormats.removeAll {
                            $0 == format
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                Menu("Add") {
                    ForEach(TVFormat.allCases) { format in
                        if !tvFormats.contains(format) {
                            Button(format.desc) {
                                tvFormats.append(format)
                            }
                        }
                    }
                }
            }
            GroupBox(label: Text("BBC Radio Formats")) {
                List($radioFormats, editActions: .move) { $format in
                    TokenView(title: format.desc) { title in
                        radioFormats.removeAll {
                            $0 == format
                        }
                    }
                    .listRowSeparator(.hidden)
                }
                Menu("Add") {
                    ForEach(RadioFormat.allCases) { format in
                        if !radioFormats.contains(format) {
                            Button(format.desc) {
                                radioFormats.append(format)
                            }
                        }
                    }
                }
            }
            Picker("Maximum STV Resolution", selection: $maxSTVSize) {
                ForEach(TVFormat.allCases) { format in
                    Text(format.desc)
                }
            }
        }
        .listStyle(.bordered)
        .frame(idealHeight: 500)
        .padding(5)
    }
}

#Preview {
    FormatSettingsView()
}

