//
//  ITVDownload.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 9/20/23.
//

import Foundation
import Kanna
import SwiftyJSON
import CocoaLumberjackSwift
import Sweep
import Subprocess
import System

@MainActor
public class ITVDownload : Download {

    @Default(\.maxITVSTVResolution) var maxResolution: TVFormat

    public init(programme: Programme) {
        super.init(program: programme)
        //        self.proxy = proxy
    }

    override func start() async {
        show.progress = "Initialising..."

        DDLogInfo("Downloading \(show.name)")

        //Create Download Path
        self.createDownloadPath()

        guard let youtubeDLFolder = Bundle.main.path(forResource: "yt-dlp_macos", ofType:nil),
              let url = show.web?.absoluteString else {
            return
        }

        let youtubeDLBinary = youtubeDLFolder + "/yt-dlp_macos"
        var args: [String] = [url,
                              "--user-agent",
                              "Mozilla/5.0",
                              "-o",
                              filepath]

        args.append("-f")
        args.append("best[height<=\(maxResolution.stvKeyword)]")
        
        if let maxResolutionInt = Int(maxResolution.stvKeyword) {
            hdVideo = maxResolutionInt >= 720
        }

        if downloadSubtitles {
            args.append("--write-sub")
            args.append("--sub-format")
            args.append("dfxp/vtt")
            args.append("--convert-subtitles")
            args.append("srt")

            if embedSubtitles {
                args.append("--embed-subs")
            }
        }

        if verbose {
            args.append("--verbose")
        }

        if tagDownloads {
            args.append("--embed-thumbnail")
        }

//        if let proxyHost = self.proxy?.host {
//            var proxyString = ""
//
//            if let user = self.proxy?.user, let password = self.proxy?.password {
//                proxyString += "\(user):\(password)@"
//            }
//
//            proxyString += proxyHost
//
//            if let port = self.proxy?.port {
//                proxyString += ":\(port)"
//            }
//
//            args.append("--proxy")
//            args.append(proxyString)
//        }

        DDLogVerbose("DEBUG: youtube-dl args:\(args)")

        show.status = .downloadingProgram
        show.complete = false

        var terminationStatus: TerminationStatus?

        var platformOptions = PlatformOptions()
        platformOptions.processGroupID = 0
        platformOptions.qualityOfService = .background

        do {
            let result = try await run(
                .path(FilePath(youtubeDLBinary)),
                arguments: Arguments(args),
                environment: .inherit.updating([
                    "PATH": GetiPlayerArguments.shared.youtubeDLEnvironment["PATH"],
                    "SSL_CERT_FILE": GetiPlayerArguments.shared.youtubeDLEnvironment["SSL_CERT_FILE"]
                ]),
                platformOptions: platformOptions,
                error: .combinedWithOutput,
                preferredBufferSize: 128
            ) { execution, standardOutput in
                self.currentExecution = execution
                for try await line in standardOutput.lines() {
                    self.youtubeDLProgress(output: line)
                }
            }
            terminationStatus = result.terminationStatus
        } catch {
            DDLogError("yt-dlp failed: \(error)")
        }

        currentExecution = nil
        show.downloadPercent = 0.0

        if terminationStatus?.isSuccess == true {
            show.complete = true
            show.status = .finishedProgramDownload
            if tagDownloads {
                await tagDownloadWithMetadata()
            }
            show.status = .finishedTagging

        } else {
            show.complete = true
            show.status = .failed
            show.progress = "Failed"

            if show.status == .cancelled {
                show.progress = "Cancelled by user"
                show.status = .cancelled
            }
        }

    }

    func youtubeDLProgress(output: String) {

        DDLogInfo("\(output)")

        output.scan(using: [
            Matcher(identifiers: ["subtitles to:"],
                    terminators: ["\n", .end]) { match, range in
                        self.show.subtitlePath = String(match)
                        DDLogDebug("Subtitle path = \(self.show.subtitlePath)")
                    },
            Matcher(identifiers: ["Destination: "],
                    terminators: ["\n", .end]) { match, range in
                        self.show.downloadPath = String(match)
                        DDLogDebug("Downloading to \(self.show.downloadPath)")
                    },
            Matcher(identifier: "[download] ",
                    terminator: " has already been downloaded") { match, range in
                        self.show.downloadPath = String(match)
                        DDLogDebug("Downloading to \(self.show.downloadPath)")
                    },
            Matcher(identifier: "[download]",
                    terminator: "% of") { match, range in
                        let progress = String(match).trimmingCharacters(in: .whitespaces)
                        if let progressVal = Double(progress) {
                            self.show.downloadPercent = progressVal
                        }
                    },
            Matcher(identifier: "ETA",
                    terminator: "(") { match, range in
                        let remaining = String(match).trimmingCharacters(in: .whitespaces)
                        self.show.progress = "\(remaining) remaining"
                    },
            Matcher(identifier: .prefix("WARNING: Failed to download m3u8 information"), terminator: "\n") { _, _ in
                self.show.progress = "Failed: Proxy"
            }

        ])
    }

    func createDownloadPath() {
        var fileName = show.episode

        // XBMC naming is always used on ITV shows to ensure unique names.
        if !show.name.isEmpty {
            fileName = show.name;
        }

        if show.seriesNum == 0 {
            show.seriesNum = 1
            if show.episodeNum == 0 {
                show.episodeNum = 1
            }
        }

        let format = !show.episode.isEmpty ? "%@.s%02lde%02ld.%@" : "%@.s%02lde%02ld"
        fileName = String(format: format, fileName, show.seriesNum, show.episodeNum, show.episode)

        //Create Download Path
        var dirName = show.name

        if dirName.isEmpty {
            dirName = show.episode
        }

        filepath = downloadPath
        dirName = dirName.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: " -")
        filepath = filepath.appending("/\(dirName)")

        var filepart = String(format:"%@.%%(ext)s",fileName).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: " -")

        do {
            try FileManager.default.createDirectory(atPath: filepath, withIntermediateDirectories: true)
            let dateRegex = try NSRegularExpression(pattern: "(\\d{2})[-_](\\d{2})[-_](\\d{4})")
            filepart = dateRegex.stringByReplacingMatches(in: filepart, range: NSRange(location: 0, length: filepart.count), withTemplate: "$3-$2-$1")
        } catch {
            DDLogError("Failed to create download directory! ")
        }

        filepath = filepath.appending("/\(filepart)")
    }

    func safeAppend(_ array: inout [String], key: String, value: String) {
        if !key.isEmpty, !value.isEmpty {
            array.append(key)
            // Converts any object into a string representation
            array.append("\(value)")
        } else {
            DDLogWarn("WARNING: AtomicParsley key: \(key), value: \(value)")
        }
    }

    func tagDownloadWithMetadata() async {
        if filepath.isEmpty {
            DDLogWarn("WARNING: Can't tag, no path")
            return
        }

        show.status = .tagging

        var arguments = [String]()
        arguments.append(show.downloadPath)
        arguments.append("--overWrite")
        safeAppend(&arguments, key: "--hdvideo", value: hdVideo ? "true" : "false")
        safeAppend(&arguments, key: "--stik", value: "TV Show")
        safeAppend(&arguments, key: "--TVNetwork", value: show.channel)
        safeAppend(&arguments, key: "--TVShowName", value: show.name)
        safeAppend(&arguments, key: "--TVSeasonNum", value: String(show.seriesNum))
        safeAppend(&arguments, key: "--TVEpisodeNum", value: String(show.episodeNum))
        safeAppend(&arguments, key: "--TVEpisode", value: show.episode)
        safeAppend(&arguments, key: "--title", value: show.episode)
        safeAppend(&arguments, key: "--description", value: show.desc)
        safeAppend(&arguments, key: "--artist", value: show.channel)
        safeAppend(&arguments, key: "--year", value: show.availableString)

        DDLogVerbose("DEBUG: AtomicParsley args:\(arguments)")
        let atomicParsleyPath = GetiPlayerArguments.shared.extraBinariesPath.appending("/AtomicParsley")

        DDLogInfo("INFO: Beginning AtomicParsley Tagging.")

        do {
            let result = try await run(
                .path(FilePath(atomicParsleyPath)),
                arguments: Arguments(arguments),
                output: .discarded,
                error: .discarded
            )

            if result.terminationStatus.isSuccess {
                DDLogInfo("AtomicParsley Tagging finished.")
            } else {
                DDLogInfo("INFO: Tagging failed.")
            }
        } catch {
            DDLogError("AtomicParsley failed: \(error)")
        }

        show.status = .finishedTagging
    }

}

