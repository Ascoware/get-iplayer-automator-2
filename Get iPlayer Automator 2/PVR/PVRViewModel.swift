//
//  PVRViewModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 3/1/26.
//

import Foundation
import CocoaLumberjackSwift
import Observation
import Subprocess
import System

/// Manages the list of auto-recorded series, their persistence, and queuing new episodes.
@MainActor
@Observable
class PVRViewModel {

    var series: [Series] = []
    var sortOrder: [KeyPathComparator<Series>] = PVRViewModel.savedSortOrder() {
        didSet {
            saveSortOrder()
            save()
        }
    }
    private(set) var isChecking = false
    private(set) var currentSeriesName: String?

    private let downloadQueueViewModel: any DownloadQueueProviding
    private let seriesFileName = "series.pvrdata"

    init(downloadQueueViewModel: any DownloadQueueProviding) {
        self.downloadQueueViewModel = downloadQueueViewModel
        loadSeriesData()
    }

    // MARK: - Series Management

    func addSeries(showName: String, tvNetwork: String) {
        let normalizedNetwork = tvNetwork.trimmingCharacters(in: .whitespaces)
        // Avoid exact duplicates (same show name + network, case-insensitive)
        guard !series.contains(where: {
            $0.showName.localizedCaseInsensitiveCompare(showName) == .orderedSame &&
            $0.tvNetwork.localizedCaseInsensitiveCompare(normalizedNetwork) == .orderedSame
        }) else { return }

        let s = Series(
            showName: showName,
            added: Int(Date().timeIntervalSince1970),
            tvNetwork: normalizedNetwork,
            lastFound: Date()
        )
        series.append(s)
        save()
    }

    func removeSeries(_ toRemove: Series) {
        series.removeAll { $0.id == toRemove.id }
        save()
    }

    func removeSeries(at offsets: IndexSet) {
        series.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Searching for new episodes

    /// Search get_iplayer for any new episodes matching each recorded series and add them to the queue.
    /// Returns `true` if any new episode was found and added to the download queue.
    @discardableResult
    func checkForNewEpisodes() async -> Bool {
        guard !series.isEmpty, !isChecking else { return false }
        isChecking = true
        defer {
            isChecking = false
            currentSeriesName = nil
        }

        var toRemove: Set<UUID> = []
        var foundAnyOverall = false

        // Header sorting can reorder the live array while a search is suspended.
        let seriesToCheck = series
        for s in seriesToCheck {
            guard series.contains(where: { $0.id == s.id }) else { continue }
            guard !s.showName.isEmpty else {
                toRemove.insert(s.id)
                continue
            }

            currentSeriesName = s.showName
            let searchArgs = buildSearchArgs(for: s)
            var outputLines: [String] = []

            do {
                let result = try await run(
                    .path(FilePath(GetiPlayerArguments.shared.perlBinaryPath)),
                    arguments: Arguments(searchArgs),
                    environment: .inherit.updating([
                        "HOME": URL.homeDirectory.path(percentEncoded: false),
                        "PERL_UNICODE": "AS",
                        "PERLIO": ":unix",
                        "PATH": GetiPlayerArguments.shared.perlEnvironmentPath
                    ]),
                    output: .string(limit: 1024 * 1024),
                    error: .string(limit: 1024 * 1024)
                )

                let allOutput = [result.standardOutput, result.standardError]
                    .compactMap { $0 }
                    .joined(separator: "\n")
                outputLines = allOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }
            } catch {
                DDLogError("PVR search failed: \(error)")
            }

            guard let index = series.firstIndex(where: { $0.id == s.id }) else { continue }
            let (valid, foundAny) = processSearchOutput(lines: outputLines, series: s)
            if !valid {
                toRemove.insert(s.id)
            } else if foundAny {
                series[index].lastFound = Date()
                foundAnyOverall = true
            }
        }

        if !toRemove.isEmpty {
            series.removeAll { toRemove.contains($0.id) }
        }
        save()

        return foundAnyOverall
    }

    // MARK: - Output Parsing

    /// Returns `(valid, foundAny)` — `valid` is false if get_iplayer reported an argument error.
    private func processSearchOutput(lines: [String], series: Series) -> (Bool, Bool) {
        var foundAny = false

        for line in lines {
            if line.isEmpty ||
                line == "Matches:" ||
                line.hasPrefix("INFO:") ||
                line.hasPrefix("WARNING:") ||
                line.hasPrefix("Added:") ||
                line.hasPrefix(".") ||
                line.hasPrefix("reading") {
                continue
            }

            if line.hasPrefix("Unknown option:") || line.hasPrefix("Option") || line.hasPrefix("Usage") {
                return (false, false)
            }

            let elements = line.components(separatedBy: "|")
            guard elements.count == 8 else {
                DDLogError("*** PVR: Invalid output line — expected 8 elements, got \(elements.count): \(line)")
                continue
            }

            let pid       = elements[0]
            let type      = elements[1]
            let tvNetwork = elements[4]
            let dateStr   = elements[7]

            guard channelMatches(tvNetwork, pattern: series.tvNetwork) else { continue }

            downloadQueueViewModel.addToQueueFromPVR(pid: pid)
            foundAny = true
            DDLogVerbose("PVR: queuing \(pid) (\(type), \(tvNetwork), \(dateStr)) for '\(series.showName)'")
        }

        return (true, foundAny)
    }

    // MARK: - Channel matching

    /// Returns true if `channel` matches `pattern`.
    ///
    /// Pattern rules:
    /// - Empty or "*" matches any channel.
    /// - A pattern containing "*" is treated as a wildcard glob (e.g. "BBC *").
    /// - Otherwise, exact case-insensitive comparison.
    private func channelMatches(_ channel: String, pattern: String) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != "*" else { return true }

        if trimmed.contains("*") {
            // Convert the pattern to a regex: escape everything, then replace \* with .*
            let escaped = NSRegularExpression.escapedPattern(for: trimmed)
            let regexPattern = escaped.replacingOccurrences(of: "\\*", with: ".*")
            if let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$", options: .caseInsensitive) {
                let range = NSRange(channel.startIndex..., in: channel)
                return regex.firstMatch(in: channel, range: range) != nil
            }
            return false
        }

        return channel.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
    }

    // MARK: - Argument Building

    private func buildSearchArgs(for series: Series) -> [String] {
        return [
            GetiPlayerArguments.shared.getiPlayerPath,
            GetiPlayerArguments.shared.noWarningArg,
            "--listformat=<pid>|<type>|<name>|<episode>|<channel>|<timeadded>|<web>|<available>",
            GetiPlayerArguments.shared.cacheExpiryArg,
            GetiPlayerArguments.shared.typeArgument(forCacheUpdate: false),
            GetiPlayerArguments.shared.profileDirArg,
            "--hide",
            escapeSpecialCharacters(string: series.showName)
        ]
    }

    // MARK: - Persistence

    private static func savedSortOrder() -> [KeyPathComparator<Series>] {
        let defaults = Defaults.shared
        let order: SortOrder = defaults.pvrSortAscending ? .forward : .reverse
        switch defaults.pvrSortColumn {
        case "showName": return [KeyPathComparator(\Series.showName, order: order)]
        case "tvNetwork": return [KeyPathComparator(\Series.tvNetwork, order: order)]
        case "lastFound": return [KeyPathComparator(\Series.lastFound, order: order)]
        default: return [] // Preserve file order until a sort column is chosen.
        }
    }

    private func saveSortOrder() {
        let defaults = Defaults.shared
        guard let comparator = sortOrder.first else {
            defaults.pvrSortColumn = ""
            return
        }
        switch comparator.keyPath {
        case \Series.showName: defaults.pvrSortColumn = "showName"
        case \Series.tvNetwork: defaults.pvrSortColumn = "tvNetwork"
        case \Series.lastFound: defaults.pvrSortColumn = "lastFound"
        default: defaults.pvrSortColumn = ""
        }
        defaults.pvrSortAscending = comparator.order == .forward
    }

    private var seriesFileURL: URL {
        let appSupport = FileManager.default.applicationSupportDirectory
        return URL(filePath: appSupport).appending(path: seriesFileName)
    }

    func save() {
        if !sortOrder.isEmpty {
            series.sort(using: sortOrder)
        }
        do {
            let data = try JSONEncoder().encode(series)
            try data.write(to: seriesFileURL, options: .atomic)
        } catch {
            DDLogError("PVRViewModel: failed to save series: \(error.localizedDescription)")
        }
    }

    func loadSeriesData() {
        do {
            let data = try Data(contentsOf: seriesFileURL)
            series = try JSONDecoder().decode([Series].self, from: data)
            if !sortOrder.isEmpty {
                series.sort(using: sortOrder)
            }
            DDLogVerbose("PVRViewModel: loaded \(series.count) series")
        } catch {
            DDLogVerbose("PVRViewModel: no existing series file or load error: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    /// Escapes Perl regex metacharacters in a show name so it is treated as a
    /// literal string when passed as a search term to get_iplayer.
    ///
    /// Perl regex metacharacters: \ . ^ $ * + ? ( ) [ ] { } |
    /// The backslash is listed first so it is escaped before any other
    /// metacharacter is processed, preventing double-escaping.
    private func escapeSpecialCharacters(string: String) -> String {
        let metacharacters: [Character] = ["\\", ".", "^", "$", "*", "+", "?", "(", ")", "[", "]", "{", "}", "|"]
        var result = string
        for ch in metacharacters {
            result = result.replacingOccurrences(of: String(ch), with: "\\" + String(ch))
        }
        return result
    }
}
