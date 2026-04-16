//
//  GetiPlayerArguments.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/3/23.
//

import Foundation
import SwiftUI

class GetiPlayerArguments {

    static let shared = GetiPlayerArguments()

    let appBundlePath = Bundle.main.bundlePath
    let getiPlayerInstallation: String
    let extraBinariesPath: String
    let getiPlayerPath: String
    let perlBinaryPath: String
    let perlEnvironmentPath: String

    private init() {
        getiPlayerInstallation = appBundlePath.appending("/Contents/Resources/get_iplayer")
        getiPlayerPath = getiPlayerInstallation.appending("/perl/bin/get_iplayer")
        extraBinariesPath = getiPlayerInstallation.appending("/utils/bin")
        perlBinaryPath = getiPlayerInstallation.appending("/perl/bin/perl")
        perlEnvironmentPath = getiPlayerInstallation.appending("/perl/lib")
    }

    let cacheExpiryArg = "--expiry=9999999999"

    var profileDirArg: String {
        return "--profile-dir=\(FileManager.default.applicationSupportDirectory)"
    }

    var perlEnvironment: [String : String] {
        var environment = [String : String]()
        environment["HOME"] = URL.homeDirectory.path(percentEncoded: false)
        environment["PERL_UNICODE"] = "AS"
        environment["PATH"] = GetiPlayerArguments.shared.perlEnvironmentPath
        return environment
    }

    var youtubeDLEnvironment: [String : String] {
        var environment = [String : String]()
        let extraBinaryPath = GetiPlayerArguments.shared.extraBinariesPath

        guard let youtubeDLFolder = Bundle.main.path(forResource: "yt-dlp_macos", ofType:nil) else {
            assertionFailure()
            return environment
        }

        guard let cacertFile = Bundle.main.url(forResource: "cacert", withExtension: "pem") else {
            assertionFailure("No cacert file found!!!!")
            return environment
        }

        environment["PATH"] = "\(youtubeDLFolder):\(extraBinaryPath)"
        environment["SSL_CERT_FILE"] = cacertFile.path
        return environment
    }

    let noWarningArg = "--nocopyright"

    func typeArgument(forCacheUpdate: Bool) -> String {
        var cacheTypes = ""

        @Default(\.cacheBBCTV) var cacheBBCTV
        @Default(\.cacheBBCRadio) var cacheBBCRadio
        if cacheBBCTV || !forCacheUpdate {
            cacheTypes += "tv,"
        }
        if cacheBBCRadio || !forCacheUpdate {
            cacheTypes += "radio,"
        }

        if !cacheTypes.isEmpty {
            cacheTypes = String(cacheTypes.dropLast())
            cacheTypes = "--type=\(cacheTypes)"
        }

        return cacheTypes
    }
}
