//
//  Preference.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/3/23.
//

import Foundation
import SwiftUI

public enum SupportedBrowsers : String, CaseIterable, Codable {
    case safari = "Safari"
    case chrome = "Chrome"
    case brave = "Brave"
    case edge = "Microsoft Edge"
    case vivaldi = "Vivaldi"
}

public enum TVFormat : Int, CaseIterable, Codable, Identifiable {
    public var id: Self {
        return self
    }

    case fhd
    case hd
    case sd
    case web
    case mobile

    var desc: String {
        switch self {
        case .fhd:
            return "Full HD (1080p)"
        case .hd:
            return "HD (720p)"
        case .sd:
            return "SD (576p)"
        case .web:
            return "Web (432p)"
        case .mobile:
            return "Mobile (288p)"
        }
    }

    var bbcKeyword: String {
        switch self {
        case .fhd:
            return "fhd"
        case .hd:
            return "hd"
        case .sd:
            return "sd"
        case .web:
            return "web"
        case .mobile:
            return "mobile"
        }
    }

    var stvKeyword: String {
        switch self {
        case .fhd:
            return "1080"
        case .hd:
            return "720"
        case .sd:
            return "576"
        case .web:
            return "432"
        case .mobile:
            return "288"
        }
    }
}

public enum RadioFormat : Int, CaseIterable, Identifiable, Codable {
    public var id: Self {
        return self
    }

    case high
    case standard
    case medium
    case low

    var desc: String {
        switch self {
        case .high:
            return "High"
        case .standard:
            return "Standard"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }

    var bbcKeyword: String {
        switch self {
        case .high:
            return "high"
        case .standard:
            return "std"
        case .medium:
            return "med"
        case .low:
            return "low"
        }
    }

    var stvKeyword: String {
        return "Not applicable"
    }

}

public class Defaults: ObservableObject {
    @AppStorage("downloadPath") public var downloadPath: String = URL.homeDirectory.path() + "/Movies/TV Shows"
    @AppStorage("proxyHost") public var proxyHost: String = ""
    @AppStorage("alwaysUseProxy") public var alwaysUseProxy: Bool = false
    @AppStorage("autoRetry") public var autoRetryOnFailure: Bool = true
    @AppStorage("autoRetryDelay") public var autoRetryDelayMinutes: Int = 30
    @AppStorage("addToTV") public var addToTV: Bool = true
    @AppStorage("defaultBrowser") public var defaultBrowser: SupportedBrowsers = .safari
    @AppStorage("cacheBBCTV") public var cacheBBCTV = false
    @AppStorage("cacheBBCRadio") public var cacheBBCRadio = false
    @AppStorage("cacheExpiryTime") public var cacheExpiryTime = 4
    @AppStorage("verbose") public var verbose = false
    @AppStorage("addSeriesLinkAtStartup") public var addSeriesLinkAtStartup = true
    @AppStorage("downloadSubtitles") public var downloadSubtitles = false
    @AppStorage("embedSubtitles") public var embedSubtitles = false
    @AppStorage("useKodiNaming") public var useKodiNaming = false
    @AppStorage("deleteOldSeriesLink") public var deleteOldSeriesLink = false
    @AppStorage("deleteOldSeriesLinkDuration") public var deleteOldSeriesLinkDuration = 30
    @AppStorage("getSignedVideo") public var getSignedVideo = false
    @AppStorage("getAudioDescribedVideo") public var getADVideo = false
    @AppStorage("tagDownloads") public var tagDownloadsWithMetadata = true
    @AppStorage("tagRadioAsPodcast") public var tagRadioAsPodcast = false
    @AppStorage("use25FPSStreams") public var use25FPSStreams = false

    @AppStorage("bbcTVFormats") public var bbcTVFormats: [TVFormat] = []
    @AppStorage("bbcRadioFormats") public var radioFormats: [RadioFormat] = []
    @AppStorage("MaxITVResolution") public var maxSTVResolution: TVFormat = .hd
    @AppStorage("MaxABCResolution") public var maxABCResolution: TVFormat = .fhd

    // Options for all channel filters
    @AppStorage("BBCOne") public var BBCOne =  true
    @AppStorage("BBCTwo") public var BBCTwo =  true
    @AppStorage("BBCThree") public var BBCThree =  true
    @AppStorage("BBCFour") public var BBCFour =  true
    @AppStorage("CBBC") public var CBBC = false
    @AppStorage("CBeebies") public var CBeebies = false
    @AppStorage("S4C") public var S4C = false
    @AppStorage("BBCNews") public var BBCNews = false
    @AppStorage("BBCParliament") public var BBCParliament = false
    @AppStorage("Radio1") public var Radio1 = true
    @AppStorage("Radio2") public var Radio2 = true
    @AppStorage("Radio3") public var Radio3 = true
    @AppStorage("Radio4") public var Radio4 = true
    @AppStorage("Radio4Extra") public var Radio4Extra = true
    @AppStorage("Radio6Music") public var Radio6Music = true
    @AppStorage("BBCWorldService") public var BBCWorldService = false
    @AppStorage("Radio5Live") public var Radio5Live = false
    @AppStorage("Radio5LiveSportsExtra") public var Radio5LiveSportsExtra = false
    @AppStorage("Radio1Xtra") public var Radio1Xtra = false
    @AppStorage("RadioAsianNetwork") public var RadioAsianNetwork = false
    @AppStorage("CBeebiesRadio") public var CBeebiesRadio = false
    @AppStorage("ShowRegionalRadioStations") public var ShowRegionalRadioStations = false
    @AppStorage("ShowLocalRadioStations") public var ShowLocalRadioStations = false
    @AppStorage("ShowRegionalTVStations") public var ShowRegionalTVStations = false
    @AppStorage("ShowLocalTVStations") public var ShowLocalTVStations = false
    @AppStorage("IgnoreAllTVNews") public var IgnoreAllTVNews = true
    @AppStorage("IgnoreAllRadioNews") public var IgnoreAllRadioNews = true

    // Filter out all BBC TV, Radio, or STV
    @AppStorage("ShowBBCTV") public var ShowBBCTV = true
    @AppStorage("ShowBBCRadio") public var ShowBBCRadio = true

    @AppStorage("TestProxy") public var TestProxy = true
    @AppStorage("ShowDownloadedInSearch") public var ShowDownloadedInSearch = true

    @AppStorage("searchSortColumn") public var searchSortColumn: String = "available"
    @AppStorage("searchSortAscending") public var searchSortAscending: Bool = true

    public static let shared = Defaults()
}

extension Array: @retroactive RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8) else {
            return nil
        }
        do {
            let result = try JSONDecoder().decode([Element].self, from: data)
            self = result
        } catch {
            return nil
        }
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
//        print("Returning \(result)")
        return result
    }
}

@propertyWrapper
public struct Default<T>: DynamicProperty {
    @ObservedObject private var defaults: Defaults
    private let keyPath: ReferenceWritableKeyPath<Defaults, T>
    public init(_ keyPath: ReferenceWritableKeyPath<Defaults, T>, defaults: Defaults = .shared) {
        self.keyPath = keyPath
        self.defaults = defaults
    }

    public var wrappedValue: T {
        get { defaults[keyPath: keyPath] }
        nonmutating set { defaults[keyPath: keyPath] = newValue }
    }

    public var projectedValue: Binding<T> {
        Binding(
            get: { defaults[keyPath: keyPath] },
            set: { value in
                defaults[keyPath: keyPath] = value
            }
        )
    }
}

