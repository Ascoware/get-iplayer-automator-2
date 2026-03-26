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

    @Published var series: [Series] = []
    private let downloadQueueViewModel: any DownloadQueueProviding

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

        var invalidSeries: [Series] = []

        for var s in series {
            if s.showName.isEmpty {
                invalidSeries.append(s)
                continue
            }

            if s.tvNetwork.isEmpty {
                s.tvNetwork = "*"
            }

            let expiryArg = GetiPlayerArguments.shared.cacheExpiryArg
            let typeArg = GetiPlayerArguments.shared.typeArgument(forCacheUpdate: false)
            let noWarningArg = GetiPlayerArguments.shared.noWarningArg
            let profileDir = GetiPlayerArguments.shared.profileDirArg
            let getiPlayerPath = GetiPlayerArguments.shared.getiPlayerPath

            let autoRecordSearchArgs = [
                getiPlayerPath,
                noWarningArg,
                "--listformat=<pid>|<type>|<name>|<episode>|<channel>|<timeadded>|<web>|<available>",
                expiryArg,
                typeArg,
                profileDir,
                "--hide",
                escapeSpecialCharacters(string: s.showName)
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

            if !processAutoRecordOutput(lines: outputLines, series: s) {
                invalidSeries.append(s)
            }
        }

        series.removeAll { invalidSeries.contains($0) }

//        if (!runDownloads) {
//            [self.currentIndicator setIndeterminate:NO];
//            [self.currentIndicator stopAnimation:self];
//            [self.startButton setEnabled:YES];
//        }
//
//        //If this is an update initiated by the scheduler, run the downloads.
//        if (self.runScheduled && !self.scheduleTimer) {
//            [self performSelectorOnMainThread:@selector(startDownloads:) withObject:self waitUntilDone:NO];
//        }
//
//        [self performSelectorOnMainThread:@selector(scheduleTimerForFinished:) withObject:nil waitUntilDone:NO];
    }

    func processAutoRecordOutput(lines: [String], series: Series) -> Bool {
        var found = false
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ"

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

            if elements.count != 8 {
                DDLogError("*** Invalid output from search. Expected 8 elements, got \(elements.count)")
                continue
            }

            var temp_pid, temp_tvNetwork, temp_type, url, temp_date, temp_timeAdded, seriesName, episodeName: String

            temp_pid = elements[0]
            temp_type = elements[1]
            seriesName = elements[2]
            episodeName = elements[3]
            temp_tvNetwork = elements[4]
            temp_timeAdded = elements[5]
            url = elements[6]
            temp_date = elements[7]

            let networkMatch = series.tvNetwork == temp_tvNetwork || series.tvNetwork.trimmingCharacters(in: .whitespaces) == "*" || series.tvNetwork.isEmpty

            if !networkMatch {
                continue
            }

//            if let timeadded = Int(temp_timeAdded) {
//                if series.added > timeadded {
//                    series.added = timeadded
//                }
//            }
            
            found = true

            let p = Programme()
            p.pid = temp_pid
            p.name = seriesName;
            p.channel = temp_tvNetwork
            p.realPID = temp_pid
            p.episode = episodeName
            p.web = URL(string: url)
            p.radio = temp_type == "radio"
            p.progress = "Added by Series-Link"
//            p.addedByPVR = true;
            p.available = dateFormatter.date(from: temp_date) ?? Date()

            downloadQueueViewModel.addToQueue(pid: temp_pid)
        }

//        if found {
//            series.lastFound = Date()
//        }
        
        return true

        //        else {
//        if (!([[NSDate date] timeIntervalSinceDate:series2.lastFound] < ([[[NSUserDefaults standardUserDefaults] valueForKey:@"KeepSeriesFor"] intValue]*86400)) && [[[NSUserDefaults standardUserDefaults] valueForKey:@"RemoveOldSeries"] boolValue])
//        {
//            return false
//        }
//            return true
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
