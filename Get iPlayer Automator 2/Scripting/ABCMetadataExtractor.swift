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
class ABCMetadataExtractor {

    /// Fetch metadata for a single iView video URL and build a `Programme`.
    @MainActor static func getEpisode(url: String) async throws -> Programme {
        let json = try await dumpJSON(for: url)
        guard let programme = programme(from: json, fallbackURL: url) else {
            throw ABCMetadataError.noMetadataFound
        }
        return programme
    }

    /// Fetch all available episodes from an iView show/series page. `yt-dlp -J`
    /// on a show URL returns a playlist object whose `entries` are the episodes.
    @MainActor static func getShowEpisodes(url: String) async throws -> [Programme] {
        let json = try await dumpJSON(for: url)

        let entries = json["entries"].array
        guard let entries, !entries.isEmpty else {
            // A show URL that resolved to a single video is still usable.
            if let single = programme(from: json, fallbackURL: url) {
                return [single]
            }
            throw ABCMetadataError.noMetadataFound
        }

        return entries.compactMap { programme(from: $0, fallbackURL: $0["webpage_url"].stringValue) }
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
