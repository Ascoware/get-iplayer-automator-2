//
//  ABCMetadataExtractor.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 6/30/26.
//

import Foundation
import SwiftyJSON
import CocoaLumberjackSwift
import Subprocess
import System

enum ABCMetadataError: Error {
    case noMetadataFound
    case unavailable
}

/// Builds `Programme` objects for ABC iView content. Unlike the STV extractor,
/// which scrapes the page HTML, this sources metadata from yt-dlp's own iview
/// extractor (`yt-dlp -J`), which is what ultimately performs the download. That
/// keeps us robust to ABC site changes and surfaces geo/availability errors.
/// Show pages are the exception: their episode lists come from the iView API.
class ABCMetadataExtractor {

    /// Fetch metadata for a single iView video URL and build a `Programme`.
    @MainActor static func getEpisode(url: String) async throws -> Programme {
        let json = try await dumpJSON(for: url)
        guard let programme = programme(from: json, fallbackURL: url) else {
            throw ABCMetadataError.noMetadataFound
        }
        return programme
    }

    /// Fetch all available episodes from an iView show/series page.
    ///
    /// yt-dlp's show/series extractor scrapes `__INITIAL_STATE__` from the page,
    /// which iView dropped when it moved to Next.js (yt-dlp issue #17699). So the
    /// episode list comes from iView's own JSON API instead; each episode is still
    /// downloaded by yt-dlp from its `/video/` URL, which is unaffected.
    @MainActor static func getShowEpisodes(url: String) async throws -> [Programme] {
        guard let components = URL(string: url)?.pathComponents,
              let showIndex = components.firstIndex(of: "show"),
              showIndex + 1 < components.count else {
            throw ABCMetadataError.noMetadataFound
        }

        // A video nested under a show page (/show/<slug>/series/<n>/video/<id>)
        // is a single episode.
        if components.contains("video") {
            return [try await getEpisode(url: url)]
        }

        let slug = components[showIndex + 1]

        // Use the season in the URL, otherwise the one the show page opens on.
        let seriesPath: String
        if let seriesIndex = components.firstIndex(of: "series"), seriesIndex + 1 < components.count {
            seriesPath = "/series/\(slug)/\(components[seriesIndex + 1])"
        } else {
            let show = try await fetchAPI("/show/\(slug)")
            guard let href = show["_links"]["selectedSeries"]["href"].string
                    ?? show["_embedded"]["seriesList"][0]["_links"]["self"]["href"].string else {
                throw ABCMetadataError.noMetadataFound
            }
            seriesPath = href
        }

        let series = try await fetchAPI(seriesPath)
        let seasonNumber = Int(seriesPath.split(separator: "/").last ?? "")
        let items = series["_embedded"]["videoEpisodes"]["items"].arrayValue

        let programmes = items.compactMap {
            programme(from: ytDLPShapedJSON(fromAPIEpisode: $0, seasonNumber: seasonNumber), fallbackURL: url)
        }
        guard !programmes.isEmpty else {
            throw ABCMetadataError.noMetadataFound
        }
        return programmes
    }

    // MARK: - iView API

    private static let apiBase = "https://api.iview.abc.net.au/v3"

    /// GET a path from the iView v3 API and parse the JSON response.
    private static func fetchAPI(_ path: String) async throws -> JSON {
        guard let url = URL(string: apiBase + path) else {
            throw ABCMetadataError.noMetadataFound
        }
        DDLogVerbose("ABC iView API request: \(url)")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            DDLogError("ABC iView API request failed: \(error)")
            throw ABCMetadataError.noMetadataFound
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            DDLogError("ABC iView API returned \((response as? HTTPURLResponse)?.statusCode ?? -1) for \(url)")
            throw ABCMetadataError.noMetadataFound
        }
        let json = try JSON(data: data)
        if json.isEmpty {
            throw ABCMetadataError.noMetadataFound
        }
        return json
    }

    /// Map an episode from the iView API into the field names yt-dlp's iview
    /// extractor uses, so show listings and single-episode lookups build
    /// identical `Programme`s.
    private static func ytDLPShapedJSON(fromAPIEpisode item: JSON, seasonNumber: Int?) -> JSON {
        // displaySubtitle is "Episode 1", "Episode 1 Wood For The Trees", or just
        // a title ("Trading Fire") for shows without episode numbers.
        let subtitle = item["displaySubtitle"].stringValue
        var episodeNumber: Int?
        var episodeName = subtitle
        if let match = subtitle.wholeMatch(of: /Episode\s+(\d+)\s*(.*)/) {
            episodeNumber = Int(match.1)
            episodeName = String(match.2)
        }
        if episodeName.isEmpty, let episodeNumber {
            episodeName = "Episode \(episodeNumber)"
        }

        let id = item["id"].stringValue
        var dict: [String: Any] = [
            "id": id,
            "title": item["title"].stringValue,
            "series": item["seriesTitle"].string ?? item["showTitle"].stringValue,
            "episode": episodeName,
            "description": item["description"].stringValue,
            "webpage_url": item["_links"]["share"]["href"].string ?? "https://iview.abc.net.au/video/\(id)"
        ]
        if let seasonNumber {
            dict["season_number"] = seasonNumber
        }
        if let episodeNumber {
            dict["episode_number"] = episodeNumber
        }

        // Prefer the episode's own thumbnail over the show/series artwork.
        let images = item["images"].arrayValue
        let thumbnail = images.first { $0["type"] == "thumb" && $0["_source"] == "video" }
            ?? images.first { $0["type"] == "thumb" }
        if let thumbnailURL = thumbnail?["url"].string {
            dict["thumbnail"] = thumbnailURL
        }

        // pubDate is "yyyy-MM-dd HH:mm:ss" in UTC, as yt-dlp interprets it.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let pubDate = formatter.date(from: item["pubDate"].stringValue) {
            dict["timestamp"] = pubDate.timeIntervalSince1970
        }

        return JSON(dict)
    }

    // MARK: - yt-dlp invocation

    /// Run `yt-dlp -J <url>` and parse its single-line JSON output.
    private static func dumpJSON(for url: String) async throws -> JSON {
        guard let youtubeDLFolder = Bundle.main.path(forResource: "yt-dlp_macos", ofType: nil) else {
            throw ABCMetadataError.noMetadataFound
        }
        let youtubeDLBinary = youtubeDLFolder + "/yt-dlp_macos"

        let args = ["-J", "--no-warnings", url]
        DDLogVerbose("ABC metadata args: \(args)")

        let stdout: String?
        let stderr: String
        let succeeded: Bool
        do {
            let result = try await run(
                .path(FilePath(youtubeDLBinary)),
                arguments: Arguments(args),
                environment: .inherit.updating([
                    "PATH": GetiPlayerArguments.shared.youtubeDLEnvironment["PATH"] ?? "",
                    "SSL_CERT_FILE": GetiPlayerArguments.shared.youtubeDLEnvironment["SSL_CERT_FILE"] ?? ""
                ]),
                output: .string(limit: 16 * 1024 * 1024),
                error: .string(limit: 1024 * 1024)
            )
            stdout = result.standardOutput
            stderr = result.standardError ?? ""
            succeeded = result.terminationStatus.isSuccess
        } catch {
            DDLogError("yt-dlp -J failed to launch: \(error)")
            throw ABCMetadataError.noMetadataFound
        }

        if !succeeded {
            DDLogError("yt-dlp -J failed: \(stderr)")
            let lowered = stderr.lowercased()
            if lowered.contains("not available") || lowered.contains("geo") || lowered.contains("region") {
                throw ABCMetadataError.unavailable
            }
            throw ABCMetadataError.noMetadataFound
        }

        guard let output = stdout, !output.isEmpty else {
            throw ABCMetadataError.noMetadataFound
        }

        let json = JSON(parseJSON: output)
        if json.isEmpty {
            throw ABCMetadataError.noMetadataFound
        }
        return json
    }

    // MARK: - JSON → Programme

    @MainActor private static func programme(from json: JSON, fallbackURL: String) -> Programme? {
        let pid = json["id"].stringValue
        guard !pid.isEmpty else {
            return nil
        }

        let p = Programme()
        p.type = .abc
        p.status = .processedPID
        p.channel = "ABC iView"
        p.pid = pid

        let title = json["title"].stringValue
        p.name = json["series"].string ?? json["playlist_title"].string ?? title
        p.episode = json["episode"].string ?? title
        p.seriesNum = json["season_number"].int ?? 0
        p.episodeNum = json["episode_number"].int ?? 0
        p.desc = json["description"].stringValue
        p.web = URL(string: json["webpage_url"].string ?? fallbackURL)
        p.thumbnail = URL(string: json["thumbnail"].stringValue)
        p.available = broadcastDate(from: json)

        // Mirror the STV extractor: fold the series number into the show name so
        // the queue and download folder disambiguate seasons, and ensure the
        // episode field is never empty.
        if p.seriesNum != 0 {
            p.name = "\(p.name): Series \(p.seriesNum)"
        }
        if p.episode.isEmpty {
            p.episode = p.episodeNum != 0 ? "Episode \(p.episodeNum)" : p.availableString
        }

        return p
    }

    /// Resolve a broadcast date from yt-dlp's timestamp fields, preferring an
    /// explicit release time, then upload timestamp, then the `YYYYMMDD` date.
    private static func broadcastDate(from json: JSON) -> Date {
        if let release = json["release_timestamp"].double {
            return Date(timeIntervalSince1970: release)
        }
        if let timestamp = json["timestamp"].double {
            return Date(timeIntervalSince1970: timestamp)
        }
        if let uploadDate = json["upload_date"].string, uploadDate.count == 8 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if let date = formatter.date(from: uploadDate) {
                return date
            }
        }
        return Date()
    }
}
