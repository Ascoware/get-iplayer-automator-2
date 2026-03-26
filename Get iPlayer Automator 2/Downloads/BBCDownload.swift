//
//  BBCDownload.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/8/23.
//

import Foundation
import SwiftUI
import CocoaLumberjackSwift
import Sweep
import Subprocess
import System

@MainActor
class BBCDownload: Download {

    @Default(\.bbcTVFormats) var tvFormats: [TVFormat]
    @Default(\.radioFormats) var radioFormats: [RadioFormat]

    var failureKeyword: String? = nil
    // Used for storing modes reported by get_iplayer
    var availableModes: String?

    init(programme: Programme) {
        //proxy: HTTPProxy?) {
        super.init(program: programme)
        DDLogInfo("Downloading \(show.name)")
    }

    override func start() async {
        //Initialize Formats
        var formatArg = "--quality="
        let formatStrings: [String]

        if show.radio {
            formatStrings = radioFormats.compactMap { $0.bbcKeyword }
        } else {
            formatStrings = tvFormats.compactMap { $0.bbcKeyword }
        }

        let commaSeparatedFormats = formatStrings.joined(separator: ",")

        formatArg += commaSeparatedFormats

        //Initialize the rest of the arguments
        let noWarningArg = GetiPlayerArguments.shared.noWarningArg
        let atomicParsleyPath = URL(fileURLWithPath: GetiPlayerArguments.shared.extraBinariesPath).appendingPathComponent("AtomicParsley").path
        let atomicParsleyArg = "--atomicparsley=\(atomicParsleyPath)"
        let ffmpegArg = "--ffmpeg=\(URL(fileURLWithPath: GetiPlayerArguments.shared.extraBinariesPath).appendingPathComponent("ffmpeg").path)"
        let downloadPathArg = "--output=\(downloadPath)"
        let subDirArg = "--subdir"
        let progressArg = "--log-progress"
        let getArg = "--pid"
        let searchArg = show.pid
        let whitespaceArg = "--whitespace"

        //AudioDescribed & Signed
        var needVersions = false

        var nonDefaultVersions: [String] = []

        if getADVideo {
            nonDefaultVersions.append("audiodescribed")
            needVersions = true
        }
        if getSignedVideo {
            nonDefaultVersions.append("signed")
            needVersions = true
        }

        //We don't want this to refresh now!
        let cacheExpiryArg = GetiPlayerArguments.shared.cacheExpiryArg
        let profileDirArg = GetiPlayerArguments.shared.profileDirArg

        //Add Arguments that can't be NULL
        var args = [
            GetiPlayerArguments.shared.getiPlayerPath,
            profileDirArg,
            noWarningArg,
            atomicParsleyArg,
            cacheExpiryArg,
            downloadPathArg,
            subDirArg,
            progressArg,
            formatArg,
            getArg,
            searchArg,
            whitespaceArg,
            "--attempts=5",
            "--thumbsize=640",
            ffmpegArg
        ]

        //Set Proxy Arguments
        // TODO: fill this in later
        //        if let proxy {
        //            args.append("-p\(proxy.url)")
        //            if Defaults.shared.alwaysUseProxy {
        //                args.append("--partial-proxy")
        //            }
        //        }

        // Only add a --versions parameter for audio described or signed. Otherwise, let get_iplayer figure it out.
        if needVersions {
            nonDefaultVersions.append("default")
            var versionArg = "--versions="
            versionArg += nonDefaultVersions.joined(separator: ",")
            args.append(versionArg)
        }

        //Verbose?
        if verbose {
            args.append("--verbose")
        }

        if downloadSubtitles {
            args.append("--subtitles")
            if embedSubtitles {
                args.append("--subs-embed")
            }
        }

        //Naming Convention
        if !useKodiNaming {
            args.append("--file-prefix=<name> - <episode> ((<modeshort>))")
        } else {
            args.append("--file-prefix=<nameshort><.senum><.episodeshort>")
            args.append("--subdir-format=<nameshort>")
        }

        // 50 FPS frames?
        if use25FPSStreams {
            args.append("--tv-lower-bitrate")
        }

        //Tagging
        if !tagDownloads {
            args.append("--no-tag")
        }

        for arg in args {
            DDLogVerbose("\(arg)")
        }

        if tagRadio {
            args.append("--tag-podcast-radio")
            show.podcast = true
        }

        show.status = .downloadingProgram
        show.complete = false
        show.progress = "Downloading..."

        var platformOptions = PlatformOptions()
        platformOptions.processGroupID = 0

        do {
            _ = try await run(
                .path(FilePath(GetiPlayerArguments.shared.perlBinaryPath)),
                arguments: Arguments(args),
                environment: .inherit.updating([
                    "HOME": URL.homeDirectory.path(percentEncoded: false),
                    "PERL_UNICODE": "AS",
                    "PERLIO": ":unix",
                    "PATH": GetiPlayerArguments.shared.perlEnvironmentPath
                ]),
                platformOptions: platformOptions,
                error: .combinedWithOutput,
                preferredBufferSize: 128
            ) { execution, standardOutput in
                self.currentExecution = execution
                for try await line in standardOutput.lines() {
                    self.processGetiPlayerOutput(line)
                }
            }
        } catch {
            DDLogError("get_iplayer failed: \(error)")
        }

        currentExecution = nil

        show.downloadPercent = 0.0

        // If we have a path it was successful. Note that and return.
        if show.status == .finishedProgramDownload {
            show.complete = true
            show.progress = "Finished downloading"
            return
        }

        // Handle all other error cases.
        show.complete = true

        if show.status == .cancelled {
            show.progress = "Cancelled by user"
            show.status = .cancelled
            return
        }

        show.status = .failed

        //    INFO: No specified recording quality
        if failureKeyword == "FileExists" {
            show.progress = "Failed: File already exists"
            DDLogError("\(show.name) failed, already exists")
        } else if failureKeyword == "ShowNotFound" {
            show.progress = "Failed: PID not found"
        } else if failureKeyword == "proxy" {
            let proxyOption = UserDefaults.standard.string(forKey: "Proxy")
            if proxyOption == "None" {
                show.progress = "Failed: See Log"
                DDLogError("REASON FOR FAILURE: VPN or System Proxy failed. If you are using a VPN or a proxy configured in System Preferences, contact the VPN or proxy provider for assistance.")
            } else if proxyOption == "Provided" {
                show.progress = "Failed: Bad Proxy"
                DDLogError("REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences.")
            } else if proxyOption == "Custom" {
                show.progress = "Failed: Bad Proxy"
                DDLogError("REASON FOR FAILURE: Proxy failed. If in the UK, please disable the proxy in the preferences.")
                DDLogError("If outside the UK, please use a different proxy.")
            }

            DDLogError("\(show.name) failed")
        } else if failureKeyword == "Specified_Modes" {
            show.progress = "Failed: Requested download quality not available"
            DDLogError("REASON FOR FAILURE: None of your preferred download formats are available for this show.")
            DDLogError("Available formats: \(availableModes ?? "none provided")")
            DDLogError("\(show.name) failed")
        } else if failureKeyword == "InHistory" {
            show.progress = "Failed: In download history"
            DDLogError("InHistory")
        } else if failureKeyword == "AudioDescribedOnly" {
            show.progress = "Program is only available as Audio Described"
        } else if failureKeyword == "External_Disconnected" {
            show.progress = "Failed: HDD not Accessible"
            DDLogError("REASON FOR FAILURE: The specified download directory could not be written to.")
            DDLogError("Most likely this is because your external hard drive is disconnected but it could also be a permission issue")
            DDLogError("\(show.name) failed")
        } else if failureKeyword == "Download_Directory_Permissions" {
            show.progress = "Failed: Download Directory Unwriteable"
            DDLogError("REASON FOR FAILURE: The specified download directory could not be written to.")
            DDLogError("Please check the permissions on your download directory.")
            DDLogError("\(show.name) failed")
        } else {
            // Failed for an unknown reason.
            show.progress = "Download Failed"
            DDLogError("\(show.name) failed")
        }
    }

    func processGetiPlayerOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)

        // Parse each line individually.
        for line in lines {
            if line.isEmpty {
                continue
            }

            if line.hasPrefix("DEBUG:") {
                DDLogDebug("\(line)")
            } else if line.hasPrefix("WARNING:") {
                DDLogWarn("\(line)")
            } else {
                DDLogInfo("\(line)")
            }

            line.scan(using: [
                // Subtitle path extraction
                Matcher(identifier: "INFO: Downloading Subtitles to '", terminator: ".srt'") { match, _ in
                    let srtPath = URL(fileURLWithPath: String(match)).appendingPathExtension("srt").path
                    self.show.subtitlePath = srtPath
                },
                // Download path extraction
                Matcher(identifier: "INFO: Wrote file ", terminator: .end) { match, _ in
                    self.show.downloadPath = String(match).trimmingCharacters(in: .whitespacesAndNewlines)
                    self.show.status = .finishedProgramDownload
                },
                // Available qualities (failure case)
                Matcher(identifier: "INFO: Available qualities:", terminator: .end) { match, _ in
                    self.failureKeyword = "Specified_Modes"
                    self.availableModes = String(match).trimmingCharacters(in: .whitespaces)
                },
                // Audio described/signed version detection
                Matcher(identifier: "available versions:", terminator: ")") { match, _ in
                    let availableVersions = String(match)
                    if availableVersions.contains("audiodescribed") || availableVersions.contains("signed") {
                        self.failureKeyword = "AudioDescribedOnly"
                    }
                },
                // ETA parsing
                Matcher(identifier: "ETA:", terminator: " (") { match, _ in
                    let etaStr = String(match).trimmingCharacters(in: .whitespaces)
                    self.show.progress = "\(etaStr) remaining"
                }
            ])

            // Handle cases that don't need value extraction
            if line.hasSuffix("use --force to override") {
                failureKeyword = "InHistory"
            } else if line.contains("Permission denied") {
                if line.contains("/Volumes") {
                    failureKeyword = "External_Disconnected"
                } else {
                    failureKeyword = "Download_Directory_Permissions"
                }
            } else if line.hasPrefix("INFO: Finished downloading") {
                show.downloadPercent = 0.0
                show.status = .finishedProgramDownload
                show.progress = ""
            } else if line.hasPrefix("WARNING: Use --overwrite") {
                failureKeyword = "FileExists"
            } else if line.hasPrefix("ERROR: Failed to get version pid") {
                failureKeyword = "ShowNotFound"
            } else if line.hasPrefix("WARNING: If you use a VPN") || line.hasSuffix("blocked by the BBC") {
                failureKeyword = "proxy"
            } else if line.hasPrefix("INFO: Downloading thumbnail") {
                show.status = .downloadingThumbnail
                show.progress = "Downloading Thumbnail..."
            } else if line.hasPrefix("INFO: Tagging") {
                show.status = .tagging
                show.progress = "Tagging with metadata..."
            } else if line.hasSuffix("[audio+video]") || line.hasSuffix("[audio]") || line.hasSuffix("[video]") {
                // Parse download percentage from progress lines
                // Line format: " 40.9%   999.23 MB / ~2440.24 MB ... ETA: 00:03:56 ... [audio+video]"
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if let percentIndex = trimmedLine.firstIndex(of: "%") {
                    let percentStr = String(trimmedLine[..<percentIndex])
                    if let percentage = Double(percentStr) {
                        show.downloadPercent = percentage
                    }
                }
            } else if line.hasPrefix("INFO: Command exit code 0") {
                if show.status == .tagging {
                    show.status = .finishedProgramDownload
                    show.progress = ""
                }
            }
        }
    }
}
