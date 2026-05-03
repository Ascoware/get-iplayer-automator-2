//
//  STVMetadataExtractor.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 3/14/26.
//

import Foundation
import Kanna
import SwiftyJSON
import CocoaLumberjackSwift

enum STVMetadataError: Error {
    case noMetadataFound
    case drmProtectedError
}

class STVMetadataExtractor {

    @MainActor static func getShowMetadata(html: String) throws -> Programme {
        let longDateFormatter = ISO8601DateFormatter()
        longDateFormatter.timeZone = TimeZone(secondsFromGMT:0)

        let newProgram = Programme()
        newProgram.channel = "STV"

        // Find the "props" JSON dictionary. Then traverse the tree
        if let htmlPage = try? HTML(html: html, encoding: .utf8) {
            guard let propertiesElement = htmlPage.at_xpath("//script[@id='__NEXT_DATA__']") else {
                DDLogError("**** No metadata found")
                throw STVMetadataError.noMetadataFound
            }

            if let propertiesContent = propertiesElement.content {
                let propertiesJSON = JSON(parseJSON: propertiesContent)
                let propsDict = propertiesJSON["props"].dictionaryValue
                if let pageProps = propsDict["pageProps"] {
                    let episodeInfo = pageProps["episodeInfo"]
                    // episodeInfo.episodeId is a JSON string; pageProps.episodeId is an integer — use the string version
                    newProgram.pid = episodeInfo["episodeId"].stringValue

                    // Primary metadata from episodeInfo — always present on first page load
                    newProgram.name = episodeInfo["name"].stringValue
                    newProgram.episode = episodeInfo["title"].stringValue
                    let startTime = episodeInfo["startTime"].stringValue
                    newProgram.available = longDateFormatter.date(from: startTime) ?? Date()

                    // episodeInfo.summary is the episode description; pageProps.summary is the series description
                    let rawDesc = episodeInfo["summary"].string ?? pageProps["summary"].string ?? "None available"
                    newProgram.desc = rawDesc.filter { !$0.isNewline }

                    // Supplement with playerApiCache if available (series/episode numbers and DRM check)
                    let episodesKey = "/episodes/\(newProgram.pid)"
                    if let showData = propsDict["initialReduxState"]?["playerApiCache"][episodesKey]["results"],
                       !showData.isEmpty {
                        let protectedMedia = showData["programme"]["drmEnabled"].boolValue
                        if protectedMedia {
                            DDLogError("**** DRM protected media - bailing out")
                            throw STVMetadataError.drmProtectedError
                        }

                        let seriesString = showData["playerSeries"]["name"].stringValue
                        for item in seriesString.components(separatedBy: .whitespacesAndNewlines) {
                            if let number = Int(item) {
                                newProgram.seriesNum = number
                            }
                        }
                        newProgram.episodeNum = showData["number"].intValue
                    }

                    newProgram.web = URL(string: pageProps["currentUrl"].stringValue)
                    newProgram.thumbnail = URL(string: pageProps["image"].stringValue)
                }
            }
        }

        // The series number should appear in the show name.
        // STV provides us a "Series xx" string, so if that's available use it.
        if newProgram.seriesNum != 0 {
            newProgram.name = "\(newProgram.name): Series \(newProgram.seriesNum)"
        }

        if newProgram.episode.isEmpty {
            if newProgram.episodeNum != 0 {
                newProgram.episode = "Episode \(newProgram.episodeNum)"
            } else {
                newProgram.episode = newProgram.availableString
            }
        }
        
        newProgram.type = .stv
        newProgram.status = .processedPID

        return newProgram
    }

    @MainActor static func getSeriesEpisodes(html: String, selectedSeriesId: String? = nil) async throws -> [Programme] {
        guard let htmlPage = try? HTML(html: html, encoding: .utf8),
              let propertiesElement = htmlPage.at_xpath("//script[@id='__NEXT_DATA__']"),
              let propertiesContent = propertiesElement.content else {
            throw STVMetadataError.noMetadataFound
        }

        let json = JSON(parseJSON: propertiesContent)
        let data = json["props"]["pageProps"]["data"]

        // Programme-level DRM check
        if data["programmeData"]["drmEnabled"].boolValue {
            throw STVMetadataError.drmProtectedError
        }

        let showName = data["programmeHeader"]["name"].stringValue
        guard !showName.isEmpty else {
            throw STVMetadataError.noMetadataFound
        }

        // Each series gets its own tab. The tab the page rendered server-side has its
        // episodes inline in `data`; the others have `data: null` and a `params` block
        // pointing at the player API.
        let episodeTabs = data["tabs"].arrayValue.filter {
            $0["type"].stringValue == "episode" && $0["accessibility"].type == .null
        }
        guard !episodeTabs.isEmpty else {
            throw STVMetadataError.noMetadataFound
        }

        // Pick the tab matching the selected series fragment (e.g. "all31-kingdom-series-3"),
        // falling back to the first/only tab.
        let episodeTab: JSON = {
            if let id = selectedSeriesId,
               let match = episodeTabs.first(where: { $0["id"].stringValue == id }) {
                return match
            }
            return episodeTabs[0]
        }()

        let episodeURLs = await episodeURLs(for: episodeTab)
        var programmes: [Programme] = []

        for episodeURL in episodeURLs {
            var request = URLRequest(url: episodeURL)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            guard let (episodeData, _) = try? await URLSession.shared.data(for: request),
                  let episodeHTML = String(data: episodeData, encoding: .utf8) else {
                DDLogWarn("Failed to fetch episode page: \(episodeURL)")
                continue
            }

            do {
                let prog = try getShowMetadata(html: episodeHTML)
                programmes.append(prog)
            } catch {
                DDLogWarn("Failed to extract metadata from \(episodeURL): \(error)")
            }
        }

        return programmes
    }

    /// Resolve a series tab to a list of episode page URLs. Inline `data` is used when
    /// present; otherwise the player API is queried using the tab's `params`.
    private static func episodeURLs(for episodeTab: JSON) async -> [URL] {
        if let inline = episodeTab["data"].array, !inline.isEmpty {
            return inline.compactMap { episode in
                guard let link = episode["link"].string, !link.isEmpty else { return nil }
                return URL(string: "https://player.stv.tv" + link)
            }
        }

        let params = episodeTab["params"]
        let path = params["path"].stringValue
        guard !path.isEmpty else { return [] }

        var components = URLComponents(string: "https://player.api.stv.tv/v1" + path)
        var items: [URLQueryItem] = []
        for (key, value) in params["query"].dictionaryValue {
            items.append(URLQueryItem(name: key, value: value.stringValue))
        }
        if !items.contains(where: { $0.name == "limit" }) {
            items.append(URLQueryItem(name: "limit", value: "200"))
        }
        components?.queryItems = items

        guard let apiURL = components?.url else {
            return []
        }

        var request = URLRequest(url: apiURL)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else {
            DDLogWarn("Failed to fetch series episodes from player API: \(apiURL)")
            return []
        }

        let apiJSON = JSON(data)
        return apiJSON["results"].arrayValue.compactMap {
            guard let permalink = $0["_permalink"].string else { return nil }
            return URL(string: permalink)
        }
    }

}
