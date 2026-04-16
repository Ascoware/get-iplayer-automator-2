//
//  GeneralSettingsView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/1/23.
//

import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsView: View {

    @Default(\.downloadPath) var downloadPath
    @State private var showingFolderPicker = false

    @Default(\.proxyHost) var proxyHost
    @Default(\.alwaysUseProxy) var alwaysUseProxy
    @Default(\.autoRetryOnFailure) var autoRetryOnFailure
    @Default(\.autoRetryDelayMinutes) var autoRetryDelayMinutes
    @Default(\.addToTV) var addToTV
    @Default(\.defaultBrowser) var defaultBrowser
    @Default(\.cacheBBCTV) var cacheBBCTV

    @Default(\.cacheBBCRadio) var cacheBBCRadio
    @Default(\.cacheExpiryTime) var cacheExpiryTime
    @Default(\.verbose) var verbose
    @Default(\.addSeriesLinkAtStartup) var addSeriesLinkAtStartup
    @Default(\.downloadSubtitles) var downloadSubtitles
    @Default(\.embedSubtitles) var embedSubtitles
    @Default(\.useKodiNaming) var useKodiNaming
    @Default(\.deleteOldSeriesLink) var deleteOldSeriesLink
    @Default(\.deleteOldSeriesLinkDuration) var deleteOldSeriesLinkDuration
    @Default(\.getSignedVideo) var getSignedVideo
    @Default(\.getADVideo) var getADVideo
    @Default(\.tagDownloadsWithMetadata) var tagDownloadsWithMetadata
    @Default(\.tagRadioAsPodcast) var tagRadioAsPodcast
    @Default(\.ShowDownloadedInSearch) var showDownloadedInSearch

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Download Path:", text: $downloadPath)
                    Spacer(minLength: 30)
                    Button("Choose…") {
                        showingFolderPicker = true
                    }
                }
                .fileImporter(
                    isPresented: $showingFolderPicker,
                    allowedContentTypes: [.folder]
                ) { result in
                    if case .success(let url) = result {
                        downloadPath = url.path
                    }
                }
            }
            Section {
                TextField("Proxy:", text: $proxyHost)
                Toggle("Always Use Proxy", isOn: $alwaysUseProxy)
                    .toggleStyle(.checkbox)
            }
            Section {
                Toggle("Auto-retry Failed Downloads", isOn: $autoRetryOnFailure)
                    .toggleStyle(.checkbox)
                TextField("Retry Interval:", value: $autoRetryDelayMinutes, format: .number)
                    .frame(width: 130)
                Toggle("Add Downloads to TV or Music", isOn: $addToTV)
                    .toggleStyle(.checkbox)
                Toggle("Tag Downloaded Programmes with Metadata", isOn: $tagDownloadsWithMetadata)
                Toggle("Tag Radio Programs as Podcasts", isOn: $tagRadioAsPodcast)
                    .disabled(!tagDownloadsWithMetadata)
                Picker("Default Browser:", selection: $defaultBrowser) {
                    ForEach(SupportedBrowsers.allCases, id: \.self) { browser in
                        Text(browser.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            Section {
                HStack {
                    Toggle("BBC TV", isOn: $cacheBBCTV)
                        .toggleStyle(.checkbox)

                    Toggle("BBC Radio", isOn: $cacheBBCRadio)
                        .toggleStyle(.checkbox)

                }
            }
            Section {
                HStack {
                    TextField("Cache Refresh Interval:", value: $cacheExpiryTime, format: .number)
                    Text("hours")
                }

                Toggle("Verbose Mode", isOn: $verbose)
                    .toggleStyle(.checkbox)

                Toggle("Add Available Series-Link Programs At Startup", isOn: $addSeriesLinkAtStartup)
                    .toggleStyle(.checkbox)
            }
            Section {
                Toggle("Show Downloaded Programmes", isOn: $showDownloadedInSearch)
                    .toggleStyle(.checkbox)
            }
            Section {
                Toggle("Download Subtitles", isOn: $downloadSubtitles)
                Toggle("Embed Subtitles in Video", isOn: $embedSubtitles)
                    .disabled(!downloadSubtitles)
            }
            Section {
                Toggle("Use Kodi (XBMC) Naming", isOn: $useKodiNaming)
                Toggle("Delete Old Series-Link Entries", isOn: $deleteOldSeriesLink)
                HStack {
                    TextField("After:", value: $deleteOldSeriesLinkDuration, format: .number)
                        .frame(width: 100)
                    Text("days")
                }
                .padding(.leading, 20)
                .disabled(!deleteOldSeriesLink)
                Toggle("Look for Signed Versions", isOn: $getSignedVideo)
                Toggle("Look for Audio-described Versions", isOn: $getADVideo)
            }

        }
//        .formStyle(.columns)
        .padding(10)
    }
}


#Preview("Settings") {
    GeneralSettingsView()
}
