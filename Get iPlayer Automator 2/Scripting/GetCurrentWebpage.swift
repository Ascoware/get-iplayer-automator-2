//
//  GetCurrentWebpage.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/3/23.
//

import Foundation
import ScriptingBridge
import SwiftyJSON
import Kanna
import CocoaLumberjackSwift
import SwiftUI

@MainActor
class GetCurrentWebpage {

    var programIDs: [String] = []
    var programs: [Programme] = []
    var canRetrieveMetadata = true

    private func extractMetadata(url: String, tabTitle: String, pageSource: String) async {
        if url.hasPrefix("https://www.bbc.co.uk/iplayer/episode/") {
            // PID is always the second-to-last element in the URL.
            var pid = ""
            if let nsUrl = URL(string: url) {
                pid = nsUrl.deletingLastPathComponent().lastPathComponent
            }

            if pid.isEmpty {
                return
            }

            programIDs.append(pid)
        } else if url.hasPrefix("https://www.bbc.co.uk/iplayer/episodes/") {
            // https://www.bbc.co.uk/iplayer/episodes/p00yzlr0/line-of-duty?seriesId=b01k9pm3
            // It looks like a PID, but it's a 'brand ID' The real URL is embedded in an anchor tag.
            var pid = ""
            if let htmlPage = try? HTML(html: pageSource, encoding: .utf8) {
                // There should only be one 'video' element.
                if let anchorElement = htmlPage.at_xpath("//a[@class='play-cta__inner play-cta__inner--do-not-wrap play-cta__inner--link']") {
                    let showURLString = anchorElement.at_xpath("//@href")?.text ?? ""
                    if let pageURL = URL(string: url), let showURL = URL(string: showURLString, relativeTo: pageURL) {
                        pid = showURL.deletingLastPathComponent().lastPathComponent
                    }
                }
            }

            if !pid.isEmpty {
                programIDs.append(pid)
            }

        } else if url.hasPrefix("https://www.bbc.co.uk/radio/play/") || url.hasPrefix("https://www.bbc.co.uk/sounds/play/") {
            // PID is always the last element in the URL.
            if let nsUrl = URL(string: url) {
                let pid = nsUrl.lastPathComponent
                programIDs.append(pid)
            }
        } else if url.hasPrefix("https://www.bbc.co.uk/programmes/") {
            // Search the page to see if it is an episode or a series page. If we don't find the PID inside
            // a bbcProgrammes element, it's a series page and we can't use it (though we might want to try
            // adding it with pid-recursive)
            guard let htmlPage = try? HTML(html: pageSource, encoding: .utf8) else {
                return
            }

            var infoDicts: [JSON] = []
            var foundPID = false
            for showInfo in htmlPage.xpath("//script[@type='application/ld+json']") {
                guard let content = showInfo.content, !content.isEmpty else {
                    continue
                }

                let infoJSON = JSON(parseJSON: content)

                if infoJSON["@type"].exists() {
                    infoDicts.append(infoJSON)
                } else {
                    let graphBlocks = infoJSON["@graph"].arrayValue
                    for block in graphBlocks {
                        if block["@type"].exists() {
                            infoDicts.append(block)
                        }
                    }
                }
            }

            // Search all of the show infos for something we know about.
            for infoDict in infoDicts {
                let contentType = infoDict["@type"]

                if contentType == "BreadcrumbList" {
                    continue
                }

                switch contentType {
                case "TVEpisode", "@TVEpisode", "@RadioEpisode", "RadioEpisode", "Clip":
                    let pid = infoDict["identifier"].stringValue
                    foundPID = true
                    programIDs.append(pid)
                    break

                default:
                    continue
                }
            }

            if !foundPID {
                let programs = searchForPIDs(url: url)
                programIDs += programs
            }
        } else if url.hasPrefix("https://player.stv.tv/episode/") {
            do {
                let show = try STVMetadataExtractor.getShowMetadata(html: pageSource)
                if !show.pid.isEmpty {
                    programs.append(show)
                }
            } catch (let error) {
                canRetrieveMetadata = false
                switch error {
                case STVMetadataError.noMetadataFound:
                    let invalidPage = NSAlert()
                    invalidPage.addButton(withTitle: "OK")
                    invalidPage.messageText = "Programme not available"
                    invalidPage.informativeText = "No programme information was found on this page. This could be because the program is not available in your country."
                    invalidPage.alertStyle = .warning
                    invalidPage.runModal()

                case STVMetadataError.drmProtectedError:
                    let invalidPage = NSAlert()
                    invalidPage.addButton(withTitle: "OK")
                    invalidPage.messageText = "Protected content"
                    invalidPage.informativeText = "The selected programme is DRM protected, so it cannot be retrieved with Get iPlayer Automator."
                    invalidPage.alertStyle = .warning
                    invalidPage.runModal()
                default:
                    DDLogError("Got some other error: \(error)")
                }
            }
        } else if url.hasPrefix("https://player.stv.tv/summary/") {
            do {
                let episodes = try await STVMetadataExtractor.getSeriesEpisodes(html: pageSource)
                programs.append(contentsOf: episodes)
            } catch {
                canRetrieveMetadata = false
                switch error {
                case STVMetadataError.noMetadataFound:
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.messageText = "Series not available"
                    alert.informativeText = "No episode information was found on this page. The series may not be available in your region."
                    alert.alertStyle = .warning
                    alert.runModal()
                case STVMetadataError.drmProtectedError:
                    let alert = NSAlert()
                    alert.addButton(withTitle: "OK")
                    alert.messageText = "Protected content"
                    alert.informativeText = "This series is DRM protected and cannot be retrieved with Get iPlayer Automator."
                    alert.alertStyle = .warning
                    alert.runModal()
                default:
                    DDLogError("STV series extraction error: \(error)")
                }
            }
        } else {
            let invalidPage = NSAlert()
            invalidPage.addButton(withTitle: "OK")
            invalidPage.messageText = "Programme Page Not Found"
            invalidPage.informativeText = "Please ensure the frontmost browser tab is open to an iPlayer or STV episode page."
            invalidPage.alertStyle = .warning
            invalidPage.runModal()
        }

    }

    public func getCurrentWebpage() {
        //Get Default Browser
        @Default(\.defaultBrowser) var browser

        //Prepare Alert in Case the Browser isn't Open
        let browserNotOpen = NSAlert()
        browserNotOpen.addButton(withTitle: "OK")
        browserNotOpen.messageText = "\(browser) is not open."
        browserNotOpen.informativeText = "Please ensure your browser is running and has at least one window open."
        browserNotOpen.alertStyle = .warning

        //Get URL
        switch (browser) {
        case .safari:
            var safariRunning: SafariApplication? = nil
            let safariTechPreview = SBApplication(bundleIdentifier: "com.apple.SafariTechnologyPreview")

            if safariTechPreview?.isRunning ?? false {
                safariRunning = safariTechPreview
            } else {
                let safariDefault = SBApplication(bundleIdentifier: "com.apple.Safari")
                if safariDefault?.isRunning ?? false {
                    safariRunning = safariDefault
                }
            }

            guard let safari = safariRunning, let safariWindows = safari.windows?().compactMap({ $0 as? SafariWindow }) else {
                browserNotOpen.runModal()
                return
            }

            let orderedWindows = safariWindows.sorted { $0.index! < $1.index! }
            if let frontWindow = orderedWindows.first,
               let tab = frontWindow.currentTab,
               let url = tab.URL,
               let name = tab.name,
               let pageURL = URL(string: url) {
                Task {
                    var request = URLRequest(url: pageURL)
                    request.addValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    if let (data, _) = try? await URLSession.shared.data(for: request),
                       let html = String(data: data, encoding: .utf8) {
                        await self.extractMetadata(url: url, tabTitle: name, pageSource: html)
                    }
                }
            }
            break

        case .chrome, .edge, .vivaldi, .brave:
            // All Chromium browsers have the same AppleScript support.
            // We just need to find the right bundle ID.
            let mapping: [SupportedBrowsers : String] = [
                .chrome : "com.google.Chrome",
                .edge : "com.microsoft.edgemac",
                .vivaldi : "com.vivaldi.Vivaldi",
                .brave : "com.brave.Browser"]

            guard let bundleID = mapping[browser], let chrome : ChromeApplication = SBApplication(bundleIdentifier: bundleID), chrome.isRunning, let chromeWindows = chrome.windows?().compactMap({ $0 as? ChromeWindow }) else {
                browserNotOpen.runModal()
                return
            }

            let orderedWindows = chromeWindows.sorted { $0.index! < $1.index! }
            if let frontWindow = orderedWindows.first,
               let tab = frontWindow.activeTab,
               let url = tab.URL,
               let title = tab.title,
               let pageURL = URL(string: url) {
                Task {
                    var request = URLRequest(url: pageURL)
                    request.addValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    if let (data, _) = try? await URLSession.shared.data(for: request),
                       let html = String(data: data, encoding: .utf8) {
                        await self.extractMetadata(url: url, tabTitle: title, pageSource: html)
                    }
                }
            }
        }
    }

    private func searchForPIDs(url: String) -> [String] {
        let task = Process()
        let pipe = Pipe()
        let errorPipe = Pipe();
        
        task.launchPath = GetiPlayerArguments.shared.perlBinaryPath
        let args = [
            GetiPlayerArguments.shared.getiPlayerPath,
            GetiPlayerArguments.shared.noWarningArg,
            GetiPlayerArguments.shared.cacheExpiryArg,
            "--pid-recursive-list",
            url,
            GetiPlayerArguments.shared.profileDirArg
        ]
        
        for arg in args {
            DDLogVerbose("\(arg)");
        }
        
        task.arguments = args
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        var envVariableDictionary = [String : String]()
        envVariableDictionary["HOME"] = NSString("~").expandingTildeInPath
        envVariableDictionary["PERL_UNICODE"] = "AS"
        envVariableDictionary["PERLIO"] = ":unix"
        envVariableDictionary["PATH"] = GetiPlayerArguments.shared.perlEnvironmentPath
        task.environment = envVariableDictionary
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        var foundPrograms = [String]()

        if let stringData = String(data: data, encoding: .utf8) {
            let lines = stringData.components(separatedBy: .newlines)

            for line in lines {
                if line.isEmpty || line.hasPrefix("Episodes:") || line.hasPrefix("INFO:") {
                    continue
                }

                let outputParts = line.components(separatedBy:",")
                let pid = outputParts[2].trimmingCharacters(in: .whitespaces)
                foundPrograms.append(pid)
            }
        }

        return foundPrograms
    }
}
