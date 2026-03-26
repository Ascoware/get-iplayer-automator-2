//
//  STVMetadataExtractor.swift
//  Get iPlayer Automator
//
//  Created by Scott Kovatch on 3/14/26.
//

import Foundation
import Kanna
import SwiftyJSON
import CocoaLumberjackSwift

enum STVMetadataError: Error {
    case noMetadataFound
    case drmProtectedError
}

class STVMetadataExtractor {

    @MainActor static func getShowMetadata(html: String) throws -> Programme {
        let longDateFormatter = ISO8601DateFormatter()
        longDateFormatter.timeZone = TimeZone(secondsFromGMT:0)

        let newProgram = Programme()
        newProgram.channel = "STV"

        // Find the "props" JSON dictionary. Then traverse the tree
        if let htmlPage = try? HTML(html: html, encoding: .utf8) {
            guard let propertiesElement = htmlPage.at_xpath("//script[@id='__NEXT_DATA__']") else {
                DDLogError("**** No metadata found")
                throw STVMetadataError.noMetadataFound
            }

            if let propertiesContent = propertiesElement.content {
                let propertiesJSON = JSON(parseJSON: propertiesContent)
                let propsDict = propertiesJSON["props"].dictionaryValue
                if let pageProps = propsDict["pageProps"] {
                    newProgram.pid = pageProps["episodeId"].stringValue
                    let episodesKey = "/episodes/\(newProgram.pid)"
                    if let showData = propsDict["initialReduxState"]?["playerApiCache"][episodesKey]["results"] {
                        if showData.isEmpty {
                            DDLogError("**** No metadata found")
                            throw STVMetadataError.noMetadataFound
                        }

                        let protectedMedia = showData["programme"]["drmEnabled"].boolValue

                        if protectedMedia {
                            DDLogError("**** DRM protected media - bailing out")
                            throw STVMetadataError.drmProtectedError
                        }
                        newProgram.name = showData["title"].stringValue
                        newProgram.episode = showData["programme"]["name"].stringValue
                        let seriesString = showData["playerSeries"]["name"].stringValue

                        let seriesComponents = seriesString.components(separatedBy: .whitespacesAndNewlines)
                        for item in seriesComponents {
                            if let number = Int(item) {
                                newProgram.seriesNum = number
                            }
                        }

                        newProgram.episodeNum = showData["number"].intValue
                        let startTime = showData["schedule"]["startTime"].stringValue
                        newProgram.available = longDateFormatter.date(from: startTime) ?? Date()
                    }
                    newProgram.web = URL(string: pageProps["currentUrl"].stringValue)
                    let rawDesc = pageProps["summary"].string ?? "None available"
                    newProgram.desc = rawDesc.filter { !$0.isNewline }
                    newProgram.thumbnail = URL(string: pageProps["image"].stringValue)
                }
            }
        }

        // The series number should appear in the show name.
        // STV provides us a "Series xx" string, so if that's available use it.
        if newProgram.seriesNum != 0 {
            newProgram.name = "\(newProgram.name): Series \(newProgram.seriesNum)"
        }

        if newProgram.episode.isEmpty {
            if newProgram.episodeNum != 0 {
                newProgram.episode = "Episode \(newProgram.episodeNum)"
            } else {
                newProgram.episode = newProgram.availableString
            }
        }
        
        newProgram.type = .stv
        newProgram.status = .processedPID

        return newProgram
    }

}
