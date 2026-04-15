//
//  PVRModel.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 9/23/23.
//

import Foundation
import SwiftUI
import OrderedCollections
import CocoaLumberjackSwift
import Subprocess
import System

@MainActor
class PVRModel: ObservableObject {

    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ"
        return df
    }()

    @Published var series: [Series] = []
    private let downloadQueueViewModel: any DownloadQueueProviding
    @Default(\.deleteOldSeriesLink) var deleteOldSeriesLink: Bool
    @Default(\.deleteOldSeriesLinkDuration) var deleteOldSeriesLinkDuration: Int

    init(downloadQueueViewModel: any DownloadQueueProviding) {
        self.downloadQueueViewModel = downloadQueueViewModel
    }

    public func addSeries(s: Series) {
        series.append(s)
    }

    public func removeSeries(s: Series) {
        series.removeAll { s1 in
            s1.id == s.id
        }
    }

    public func addSeriesLinkToQueue() async {
        
        if series.count == 0 {
            return
        }

        var indicesToRemove: IndexSet = []

        for index in series.indices {
            if series[index].showName.isEmpty {
                indicesToRemove.insert(index)
                continue
            }

            if series[index].tvNetwork.isEmpty {
                series[index].tvNetwork = "*"
            }

            let expiryArg = GetiPlayerArguments.shared.cacheExpiryArg
            let typeArg = GetiPlayerArguments.shared.typeArgument(forCacheUpdate: false)
            let noWarningArg = GetiPlayerArguments.shared.noWarningArg
            let profileDir = GetiPlayerArguments.shared.profileDirArg
            let getiPlayerPath = GetiPlayerArguments.shared.getiPlayerPath

            let autoRecordSearchArgs = [
                getiPlayerPath,
                noWarningArg,
                "--listformat=<pid>|<channel>",
                expiryArg,
                typeArg,
                profileDir,
                "--hide",
                escapeSpecialCharacters(string: series[index].showName)
            ]
            let launchPath = GetiPlayerArguments.shared.perlBinaryPath
            var outputLines: [String] = []

            do {
                let result = try await run(
                    .path(FilePath(launchPath)),
                    arguments: Arguments(autoRecordSearchArgs),
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

            if !processAutoRecordOutput(lines: outputLines, series: &series[index]) {
                indicesToRemove.insert(index)
            }
        }

        series.remove(atOffsets: indicesToRemove)
    }

    func processAutoRecordOutput(lines: [String], series: inout Series) -> Bool {
        var found = false

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
                return false
            }

            let elements = line.components(separatedBy: "|")

            if elements.count != 2 {
                DDLogError("*** Invalid output from search. Expected 2 elements, got \(elements.count)")
                continue
            }

            let pid = elements[0]
            let tvNetwork = elements[1]

            let networkMatch = series.tvNetwork == tvNetwork || series.tvNetwork.trimmingCharacters(in: .whitespaces) == "*" || series.tvNetwork.isEmpty

            if !networkMatch {
                continue
            }

            found = true
            downloadQueueViewModel.addToQueueFromPVR(pid: pid)
        }

        if found {
            series.lastFound = Date()
        } else if deleteOldSeriesLink {
            let daysSinceLastFound = Date().timeIntervalSince(series.lastFound) / 86400
            if daysSinceLastFound >= Double(deleteOldSeriesLinkDuration) {
                DDLogInfo("Removing stale series-link entry: \(series.showName) (no matches in \(Int(daysSinceLastFound)) days)")
                return false
            }
        }

        return true
    }

    private func escapeSpecialCharacters(string: String) -> String {
        let characters = ["+", "-", "&", "!", "(", ")", "{" ,"}",
                          "[", "]", "^", "~", "*", "?", ":", "\""]
        var cleanedString = string
        for character in characters {
            cleanedString = cleanedString.replacingOccurrences(of: character, with: "\\\\\(character)")
        }
        return cleanedString
    }

}
