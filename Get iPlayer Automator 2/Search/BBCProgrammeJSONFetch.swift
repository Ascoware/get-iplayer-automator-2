//
//  BBCProgrammeJSONFetch.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/6/26.
//

import Foundation
import SwiftyJSON
import CocoaLumberjackSwift

/// Fetches programme metadata directly from `https://www.bbc.co.uk/programmes/<pid>.json`,
/// the same endpoint `get_iplayer`'s `get_metadata` uses.
///
/// `get_iplayer --info` costs far more than the metadata we keep. Passing `--info` forces it
/// to fetch both DASH and HLS stream data and probe the media selector once per programme
/// version, purely to compute the mode/quality sizes that `getProgramme()` discards. Adding a
/// series page can produce ~170 PIDs, and each one paid that cost plus a Perl process launch.
///
/// This type reproduces only the JSON half of `get_metadata`, which is where every field
/// `Programme` actually retains comes from. `duration` and `thumbnail` are deliberately not
/// set: both derive from stream probing, and `ProgrammeMetadataFetch` never populated them
/// either. Callers that need categories or mode sizes must still use `ProgrammeMetadataFetch`.
@MainActor
class BBCProgrammeJSONFetch {

    enum FetchError: Error {
        case badResponse
        case notAnEpisode
    }

    let pid: String

    init(pid: String) {
        self.pid = pid
    }

    func getProgramme() async throws -> Programme {
        guard let url = URL(string: "https://www.bbc.co.uk/programmes/\(pid).json") else {
            throw FetchError.badResponse
        }

        var request = URLRequest(url: url)
        request.addValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        DDLogVerbose("Fetching metadata: \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FetchError.badResponse
        }

        let doc = try JSON(data: data)["programme"]

        // get_iplayer only trusts this shape for episodes and clips; anything else (a brand
        // or series PID) has no usable episode metadata.
        let docType = doc["type"].stringValue
        guard docType == "episode" || docType == "clip" else {
            throw FetchError.notAnEpisode
        }

        return Self.programme(from: doc, pid: pid)
    }

    /// Maps a decoded `programme` object onto a `Programme`. Split out from the fetch so the
    /// mapping can be exercised against saved JSON without a network round trip.
    static func programme(from doc: JSON, pid: String) -> Programme {
        let parent = doc["parent"]["programme"]
        let grandparent = parent["parent"]["programme"]
        let greatGrandparent = grandparent["parent"]["programme"]

        // media_type "audio" is radio, anything containing "video" is TV; when the episode
        // itself doesn't say, fall back to the owning service's type.
        let mediaType = doc["media_type"].stringValue
        let isRadio: Bool
        if mediaType == "audio" {
            isRadio = true
        } else if mediaType.contains("video") {
            isRadio = false
        } else {
            isRadio = doc["ownership"]["service"]["type"].stringValue == "radio"
        }

        var episode = doc["title"].stringValue
        var channel = doc["ownership"]["service"]["title"].stringValue
        var brand = ""
        var series = ""
        var seriesPosition = 0
        var subseriesPosition = 0

        for ancestor in [parent, grandparent, greatGrandparent] {
            if channel.isEmpty {
                channel = ancestor["ownership"]["service"]["title"].stringValue
            }

            let ancestorType = ancestor["type"].stringValue
            let ancestorTitle = ancestor["title"].stringValue
            guard !ancestorType.isEmpty, !ancestorTitle.isEmpty else { continue }

            if ancestorType == "brand" {
                brand = ancestorTitle
            } else if ancestorType == "series" {
                // Rare subseries: we already recorded an inner series, so fold it into the
                // episode title and keep its position as the episode number.
                if !series.isEmpty {
                    episode = "\(series) \(episode)"
                    subseriesPosition = seriesPosition
                }
                series = ancestorTitle
                seriesPosition = ancestor["position"].intValue
            }
        }

        var name: String
        if !brand.isEmpty {
            name = (!series.isEmpty && series != brand) ? "\(brand): \(series)" : brand
        } else {
            name = series
        }

        if name.isEmpty {
            name = episode
            episode = "-"
        }

        // get_iplayer chains these with Perl's `||`, so a zero position falls through.
        var episodeNum = subseriesPosition != 0 ? subseriesPosition : doc["position"].intValue
        var seriesNum = seriesPosition != 0 ? seriesPosition : parent["position"].intValue

        var episodePart = ""
        if subseriesPosition != 0 {
            let letters = Array("abcdefghijklmnopqrstuvwxyz")
            let position = doc["position"].intValue
            if position >= 1 && position <= letters.count {
                episodePart = String(letters[position - 1])
            }
        }

        // Titles are more reliable than the BBC's position fields when they disagree, so a
        // "Series N"/"Episode N" in the text wins.
        let haystack = "\(name) \(episode)"
        if let parsed = number(in: haystack, following: "(?:Series|Cyfres|Season)") {
            seriesNum = parsed
        }
        if let parsed = number(in: haystack, following: "(?:Episode|Pennod)") {
            episodeNum = parsed
        } else if let parsed = leadingNumber(in: episode) {
            episodeNum = parsed
        }

        episode = insertEpisodeNumber(episode, episodeNum: episodeNum, episodePart: episodePart)

        // A numbered episode always belongs to at least series 1.
        if seriesNum == 0 && episodeNum != 0 {
            seriesNum = 1
        }

        let firstBroadcast = doc["first_broadcast_date"].stringValue
        let available = firstBroadcast.isEmpty
            ? Date()
            : (ISO8601DateFormatter().date(from: firstBroadcast) ?? Date())

        let programme = Programme()
        programme.status = .processedPID
        programme.index = 0
        programme.type = isRadio ? .radio : .tv
        programme.radio = isRadio
        programme.name = name
        programme.episode = episode
        programme.seriesNum = seriesNum
        programme.episodeNum = episodeNum
        programme.pid = pid
        programme.channel = channel
        programme.available = available
        programme.desc = firstNonEmpty(doc["long_synopsis"], doc["medium_synopsis"], doc["short_synopsis"])
        programme.web = URL(string: "https://www.bbc.co.uk/programmes/\(pid)")

        return programme
    }

    // MARK: - Episode/series numbering

    // Ports of get_iplayer's regex_numbers (get_iplayer:2501) and convert_words_to_number
    // (get_iplayer:2444), which let titles spell their numbers out ("Series Two").

    static let unitWords = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
    static let teenWords = ["ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
                            "sixteen", "seventeen", "eighteen", "nineteen"]
    static let tensWords = ["twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

    /// Matches a number written either as digits or as words, up to 99.
    ///
    /// Deliberate deviation from get_iplayer: it lists the units before the teens, so its
    /// capture of "Series Seventeen" stops at "seven" and yields 7. Ordering the teens first
    /// captures the whole word and yields 17, which is what `convert_words_to_number` is
    /// built to return.
    static var numberPattern: String {
        let units = unitWords.joined(separator: "|")
        let teens = teenWords.joined(separator: "|")
        let tens = tensWords.joined(separator: "|")
        return "(?:\\d+|\(teens)|\(units)|(?:\(tens))(?:(?:\\s+|-)?(?:\(units)))?)"
    }

    static func wordsToNumber(_ text: String) -> Int {
        let lowered = text.lowercased()

        if let digits = Int(lowered) {
            return digits
        }

        var number = 0

        // A trailing unit or teen carries the ones place. The `$` anchor means "seventeen"
        // matches the teen rather than the "seven" inside it.
        let units = unitWords.joined(separator: "|")
        let teens = teenWords.joined(separator: "|")
        if let word = firstMatch(in: lowered, pattern: "(?:\(teens)|\(units))$") {
            number += wordValues[word] ?? 0
        }

        let tens = tensWords.joined(separator: "|")
        if let word = firstMatch(in: lowered, pattern: "^(\(tens))", group: 1) {
            number += wordValues[word] ?? 0
        }

        return number
    }

    static let wordValues: [String: Int] = {
        var values: [String: Int] = [:]
        for (index, word) in (unitWords + teenWords).enumerated() {
            values[word] = index
        }
        for (index, word) in tensWords.enumerated() {
            values[word] = (index + 2) * 10
        }
        return values
    }()

    /// Finds the number following a keyword, e.g. "Series 4" or "Episode Two".
    static func number(in text: String, following keywordPattern: String) -> Int? {
        guard let captured = firstMatch(in: text,
                                        pattern: "\(keywordPattern)\\s+(\(numberPattern))",
                                        caseInsensitive: true,
                                        group: 1) else {
            return nil
        }
        let value = wordsToNumber(captured)
        return value != 0 ? value : nil
    }

    /// Matches an episode title that opens with its own number, e.g. "03. Something".
    static func leadingNumber(in episode: String) -> Int? {
        guard let captured = firstMatch(in: episode,
                                        pattern: "^(\(numberPattern))\\.\\s+",
                                        caseInsensitive: true,
                                        group: 1) else {
            return nil
        }
        let value = wordsToNumber(captured)
        return value != 0 ? value : nil
    }

    /// Port of get_iplayer's `insert_episode_number` (get_iplayer:5876).
    static func insertEpisodeNumber(_ episode: String, episodeNum: Int, episodePart: String) -> String {
        guard episodeNum != 0 else { return episode }

        // Leave titles that already lead with their own number alone.
        if firstMatch(in: episode, pattern: "^\\d+[a-z]?\\.") != nil {
            return episode
        }

        return String(format: "%02d%@. %@", episodeNum, episodePart, episode)
    }

    // MARK: - Helpers

    private static func firstNonEmpty(_ candidates: JSON...) -> String {
        for candidate in candidates {
            let value = candidate.stringValue
            if !value.isEmpty {
                return value
            }
        }
        return ""
    }

    private static func firstMatch(in text: String,
                                   pattern: String,
                                   caseInsensitive: Bool = false,
                                   group: Int = 0) -> String? {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range(at: group), in: text) else {
            return nil
        }

        return String(text[matchRange])
    }
}
