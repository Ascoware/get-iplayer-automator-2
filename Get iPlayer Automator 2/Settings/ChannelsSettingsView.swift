//
//  ChannelsSettingsView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/1/23.
//

import SwiftUI

struct ChannelsSettingsView: View {

    @Default(\.BBCOne) var BBCOne
    @Default(\.BBCTwo) var BBCTwo
    @Default(\.BBCThree) var BBCThree
    @Default(\.BBCFour) var BBCFour
    @Default(\.CBBC) var CBBC
    @Default(\.CBeebies) var CBeebies
    @Default(\.BBCNews) var BBCNews
    @Default(\.BBCParliament) var BBCParliament
    @Default(\.Radio1) var Radio1
    @Default(\.Radio2) var Radio2
    @Default(\.Radio3) var Radio3
    @Default(\.Radio4) var Radio4
    @Default(\.Radio4Extra) var Radio4Extra
    @Default(\.Radio6Music) var Radio6Music
    @Default(\.BBCWorldService) var BBCWorldService
    @Default(\.Radio5Live) var Radio5Live
    @Default(\.Radio5LiveSportsExtra) var Radio5LiveSportsExtra
    @Default(\.Radio1Xtra) var Radio1Xtra
    @Default(\.RadioAsianNetwork) var RadioAsianNetwork
    @Default(\.CBeebiesRadio) var CBeebiesRadio
    @Default(\.ShowRegionalRadioStations) var ShowRegionalRadioStations
    @Default(\.ShowLocalRadioStations) var ShowLocalRadioStations
    @Default(\.ShowRegionalTVStations) var ShowRegionalTVStations
    @Default(\.ShowLocalTVStations) var ShowLocalTVStations
    @Default(\.IgnoreAllTVNews) var IgnoreAllTVNews
    @Default(\.IgnoreAllRadioNews) var IgnoreAllRadioNews

    var body: some View {
        VStack {
            GroupBox(label: Text("BBC TV")) {
                Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 15) {
                    GridRow {
                        Toggle(isOn: $BBCOne, label: {
                            Text("BBC One")
                        })
                        Toggle(isOn: $BBCTwo, label: {
                            Text("BBC Two")
                        })
                        Toggle(isOn: $BBCThree, label: {
                            Text("BBC Three")
                        })
                        Toggle(isOn: $BBCFour, label: {
                            Text("BBC Four")
                        })
                    }
                    GridRow {
                        Toggle(isOn: $BBCNews, label: {
                            Text("BBC News")
                        })
                        Toggle(isOn: $BBCParliament, label: {
                            Text("BBC Parliament")
                        })
                        Toggle(isOn: $CBBC, label: {
                            Text("CBBC")
                        })
                        Toggle(isOn: $CBeebies, label: {
                            Text("CBeebies")
                        })
                    }
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                        .frame(width: 600, height: 1)
                    GridRow {
                        Toggle(isOn: $ShowRegionalTVStations, label: {
                            Text("Regional TV Stations")
                        })
                        .gridCellColumns(4)
                    }
                    GridRow {
                        Toggle(isOn: $ShowLocalTVStations, label: {
                            Text("Local TV Stations")
                        })
                        .gridCellColumns(4)
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity)
            }
            GroupBox(label: Text("BBC Radio")) {
                Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 15) {
                    GridRow {
                        Toggle(isOn: $Radio1, label: {
                            Text("BBC Radio 1")
                        })
                        Toggle(isOn: $Radio1Xtra, label: {
                            Text("BBC Radio 1Xtra")
                        })
                        Toggle(isOn: $Radio2, label: {
                            Text("BBC Radio 2")
                        })
                        Toggle(isOn: $Radio3, label: {
                            Text("BBC Radio 3")
                        })
                    }
                    GridRow {
                        Toggle(isOn: $Radio4, label: {
                            Text("BBC Radio 4")
                        })
                        Toggle(isOn: $Radio4Extra, label: {
                            Text("BBC Radio 4 Extra")
                        })
                        Toggle(isOn: $Radio5Live, label: {
                            Text("BBC Radio 5 Live")
                        })
                        Toggle(isOn: $Radio6Music, label: {
                            Text("BBC Radio 6 Music")
                        })
                    }
                    GridRow {
                        Toggle(isOn: $BBCWorldService, label: {
                            Text("BBC World Service")
                        })
                        Toggle(isOn: $RadioAsianNetwork, label: {
                            Text("BBC Asian Network")
                        })
                        Toggle(isOn: $CBeebiesRadio, label: {
                            Text("CBeebies Radio")
                        })
                    }
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                        .frame(width: 600, height: 1)
                    GridRow {
                        Toggle(isOn: $ShowRegionalRadioStations, label: {
                            Text("Regional Radio Stations")
                        })
                        .gridCellColumns(4)
                    }
                    GridRow {
                        Toggle(isOn: $ShowLocalRadioStations, label: {
                            Text("Local Radio Stations")
                        })
                        .gridCellColumns(2)
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity)
            }
            GroupBox(label: Text("News")) {
                Grid(alignment: .leading, horizontalSpacing: 15, verticalSpacing: 15) {
                    GridRow {
                        Toggle(isOn: $IgnoreAllTVNews, label: {
                            Text("Ignore all TV Programmes with \"news\" in the title")
                        })
                    }
                    GridRow {
                        Toggle(isOn: $IgnoreAllRadioNews, label: {
                            Text("Ignore all Radio Programmes with \"news\" in the title")
                        })
                    }
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                        .frame(width: 600, height: 1)
                }
                
                .padding(15)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: 630)
    }
}

#Preview {
    ChannelsSettingsView()
}

