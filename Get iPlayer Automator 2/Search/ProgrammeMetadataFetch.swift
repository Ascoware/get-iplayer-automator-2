//
//  ProgrammeMetadata.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/6/23.
//

import Foundation
import SwiftUI
import CocoaLumberjackSwift
import Sweep
import Subprocess
import System

@MainActor
class ProgrammeMetadataFetch {

    @Default(\.getADVideo) var getADVideo
    @Default(\.getSignedVideo) var getSignedVideo

    let pid: String

    public init(pid: String) {
        self.pid = pid
    }

    func getProgramme() async -> Programme? {
        //        let getNameTask = Process()
        //        let getNamePipe = Pipe()
        //        // index|type|name|episode|seriesnum|episodenum|pid|channel|available|expires|duration|desc|web|thumbnail|timeadded
        //        let listArgument = "--listformat=<index>|<pid>|<type>|<name>|<episode>|<seriesnum>|<episodenum>|<channel>|<available>|<desc>|<web>|<thumbnail>|<timeadded>"
        //
        //        let fieldsArgument = "--fields=index,pid"
        //        let wantedID = pid
        //        let args = [
        //            GetiPlayerArguments.shared.getiPlayerPath,
        //            GetiPlayerArguments.shared.noWarningArg,
        //            GetiPlayerArguments.shared.cacheExpiryArg,
        //            "--nopurge",
        //            GetiPlayerArguments.shared.typeArgument(forCacheUpdate: false),
        //            listArgument,
        //            GetiPlayerArguments.shared.profileDirArg,
        //            fieldsArgument,
        //            wantedID
        //        ]
        //
        //        getNameTask.arguments = args
        //        getNameTask.launchPath = GetiPlayerArguments.shared.perlBinaryPath
        //        getNameTask.standardOutput = getNamePipe
        //        let getNameFh = getNamePipe.fileHandleForReading
        //
        //        var envVariableDictionary = [String : String]()
        //        envVariableDictionary["HOME"] = URL.homeDirectory.path(percentEncoded: false)
        //        envVariableDictionary["PERL_UNICODE"] = "AS"
        //        envVariableDictionary["PATH"] = GetiPlayerArguments.shared.perlEnvironmentPath
        //        getNameTask.environment = envVariableDictionary
        //        getNameTask.launch()
        //
        //        let data = getNameFh.readDataToEndOfFile()
        //        guard let taskOutput = String(data: data, encoding: .utf8) else {
        //            return nil
        //        }
        //
        //        let taskLines = taskOutput.components(separatedBy: .newlines)
        //        var found = false
        //
        //        let dateFormatter = DateFormatter()
        //        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ"
        //
        //        var index, type, name, episode, seriesnum, episodenum, pid, channel, available, expires, duration, desc, web, thumbnail, timeadded: String
        //        var lastBroadcast: Date?, lastBroadcastString = ""
        //
        //        for line in taskLines {
        //            let elements = line.components(separatedBy: "|")
        //
        //            if elements.count != 13 {
        //                continue
        //            }
        //
        //            index = elements[0]
        //            pid = elements[1]
        //
        //            //<index>|<pid>|<type>|<name>|<episode>|<seriesnum>|<episodenum>|<channel>|<available>|<desc>|<web>|<thumbnail>|<timeadded>
        //            if (wantedID == pid) || (wantedID == index) {
        //                found = true
        //                type = elements[2]
        //                name = elements[3]
        //                episode = elements[4]
        //                seriesnum = elements[5]
        //                episodenum = elements[6]
        //                channel = elements[7]
        //                available = elements[8]
        //                desc = elements[9]
        //                web = elements[10]
        //                thumbnail = elements[11]
        //                timeadded = elements[12]
        //                break
        //            }
        //        }
        //
        //        // Found it in the cache, otherwise we have to do a remote fetch.
        //        if found {
        //            if let date = dateFormatter.date(from: available) {
        //                lastBroadcast = date
        //            }
        //
        //            let indexInt = Int(index) ?? 0
        //            let seriesInt = Int(seriesnum) ?? 0
        //            let episodeInt = Int(episodenum) ?? 0
        //            let programType: ProgrammeType = (type == "radio" ? .radio : .tv)
        //
        //            let programme = Programme(index: indexInt, type: programType, name: name, episode: episode, seriesNum: seriesInt, episodeNum: episodeInt, pid: pid, channel: channel)
        //        }
        var args = [
            GetiPlayerArguments.shared.getiPlayerPath,
            GetiPlayerArguments.shared.noWarningArg,
            GetiPlayerArguments.shared.cacheExpiryArg,
            GetiPlayerArguments.shared.profileDirArg,
            "--info",
            "--pid",
            pid]

        // Only add a --versions parameter for audio described or signed. Otherwise, let get_iplayer figure it out.
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

        if needVersions {
            nonDefaultVersions.append("default")
            var versionArg = "--versions="
            versionArg += nonDefaultVersions.joined(separator: ",")
            args.append(versionArg)
        }

        //        if let httpProxy = proxyDict["proxy"] as? HTTPProxy {
        //            args.append("-p\(httpProxy.url)")
        //
        //            if UserDefaults.standard.bool(forKey: "AlwaysUseProxy") == false {
        //                args.append("--partial-proxy")
        //            }
        //        }

        DDLogVerbose("get metadata args:")
        for arg in args {
            DDLogVerbose("\(arg)")
        }

        var taskLines: [String] = []

        do {
            let result = try await run(
                .path(FilePath(GetiPlayerArguments.shared.perlBinaryPath)),
                arguments: Arguments(args),
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
            taskLines = allOutput.components(separatedBy: .newlines).filter { !$0.isEmpty }
            for line in taskLines {
                DDLogInfo("\(line)")
            }
        } catch {
            DDLogError("Failed to run get_iplayer --info: \(error)")
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZZZZZ"

        var episode, channel, desc: String

        let validOutput = taskLines.filter {
            !$0.hasPrefix("INFO:") && !$0.hasPrefix("WARNING:") && !$0.isEmpty
        }

        // If the PID is valid and the show exists it will have a 'versions:' line.
        // If that's not there no need to go any further.
        var default_version: String? = nil
        let info_versions = scanField("versions", lines: validOutput)

        if info_versions.isEmpty {
            //            status = "Not Available"
            return nil
        }

        channel = scanField("channel", lines: validOutput)
        let radio = scanField("type", lines: validOutput) == "radio"

        let versions = info_versions.components(separatedBy: ",")
        for version in versions {
            if (version == "default") || ((version == "original") && (default_version != "default")) || (default_version == nil && (version != "signed") && (version != "audiodescribed")) {
                default_version = version
            }
        }

        //        status = runDownloads.boolValue ? "Waiting…" : "Available"

        //            let categories = scanField("categories", lines: validOutput)

        desc = scanField("desclong", lines: validOutput)

        if desc.isEmpty {
            desc = scanField("desc", lines: validOutput)
        }

        //        let durationStr = scanField("runtime", lines: validOutput)
        //        duration = Int(durationStr) ?? 0

        let available = scanField("firstbcast", lines: validOutput)
        let firstBcastDate: Date

        if !available.isEmpty {
            firstBcastDate = ISO8601DateFormatter().date(from: available) ?? Date()
        } else {
            firstBcastDate = Date()
        }

        let url = scanField("web", lines: validOutput)
        episode = scanField("episodeshort", lines: validOutput)
        let showName = scanField("longname", lines: validOutput)
        let seriesString = scanField("seriesnum", lines: validOutput)
        let seriesInt = Int(seriesString) ?? 0

        let episodeString = scanField("episodenum", lines: validOutput)
        let episodeInt = Int(episodeString) ?? 0

        // parse mode sizes
        var modeSizes: [[String:String]] = []
        for version in versions {
            var group: String? = nil
            switch version {
            case default_version:
                group = "A"
            case "signed":
                group = "C"
            case "audiodescribed":
                group = "D"
            default:
                group = "B"
            }

            var modePairs: [[String: String]] = []
            var allSizes = scanField("modesizes", lines: validOutput, secondField: version)

            if allSizes.isEmpty {
                allSizes = scanField("qualitysizes", lines: validOutput, secondField: version)
            }

            let sizePairs = allSizes.components(separatedBy: ",")

            if !sizePairs.isEmpty {
                for sizePair in sizePairs {
                    let components = sizePair.components(separatedBy: "=")
                    let mode = components[0]
                    let size = components[1]
                    var info: [String : String] = [:]
                    info["mode"] = mode
                    info["size"] = size
                    info["group"] = group
                    info["version"] = version == default_version ? "default" : version
                    modePairs.append(info)
                }
            }
            modeSizes.append(contentsOf: modePairs)
        }

        let p = Programme()
        p.status = .processedPID
        p.index = 0
        p.type = radio ? .radio : .tv
        p.name = showName
        p.episode = episode
        p.seriesNum = seriesInt
        p.episodeNum = episodeInt
        p.pid = pid
        p.channel = channel
        p.available = firstBcastDate
        p.desc = desc
        p.web = URL(string: url)
        p.radio = radio

        return p
    }

    // Look for 'field:' at the beginning of a line in 'lines'. If found, and 'secondField' is empty, return the rest
    // of the line after the whitespace beyond the 'field:'.
    // If secondField is provided, treat the value portion of the line as a new key/value pair
    // and look for 'secondField:'. Then return the rest of the line.
    func scanField(_ field: String, lines: [String], secondField: String = "") -> String {
        var value: String? = nil

        for (index, line) in lines.enumerated() {
            if line.hasPrefix("\(field):") {
                line.scan(using: [
                    Matcher(identifier: .prefix("\(field):"), terminator: .end) { match, _ in
                        let trimmed = String(match).trimmingCharacters(in: .whitespaces)
                        // If value is empty on this line, check the next line
                        let effectiveTrimmed = trimmed.isEmpty && index + 1 < lines.count
                            ? lines[index + 1].trimmingCharacters(in: .whitespaces)
                            : trimmed
                        if secondField.isEmpty {
                            value = effectiveTrimmed
                        } else if effectiveTrimmed.hasPrefix(secondField) {
                            effectiveTrimmed.scan(using: [
                                Matcher(identifier: .prefix("\(secondField):"), terminator: .end) { innerMatch, _ in
                                    value = String(innerMatch).trimmingCharacters(in: .whitespaces)
                                }
                            ])
                        }
                    }
                ])

                if value != nil && (!secondField.isEmpty || value != nil) {
                    break
                }
            }
        }
        return value ?? ""
    }

}
