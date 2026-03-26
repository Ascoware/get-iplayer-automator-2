//
//  LogController.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/7/23.
//

import Foundation
import CocoaLumberjackSwift
import SwiftUI
import Observation

@MainActor
@Observable
class LogController: NSObject, DDLogFormatter {
    var entries: [AttributedString] = []
    var clearID: Int = 0
    @ObservationIgnored @Default(\.verbose) private var verbose

    override init() {
        super.init()
        let fileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24
        fileLogger.logFileManager.maximumNumberOfLogFiles = 1
        fileLogger.logFormatter = self
        DDLog.add(fileLogger)
        DDLog.add(DDOSLogger())
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") {
            DDLogInfo("Get iPlayer Automator \(version) Initialized.")
        }
    }

    func clear() {
        entries = []
        clearID &+= 1
    }

    nonisolated func format(message logMessage: DDLogMessage) -> String? {
        // In normal mode don't dump debug or verbose messages to the console.
        let isVerbose = UserDefaults.standard.bool(forKey: "verbose")
        if !isVerbose && ((logMessage.flag == .debug) || (logMessage.flag == .verbose)) {
            return nil
        }

        let messageWithNewline = logMessage.message + "\n"

        // Use AppKit-scope attributes so they survive NSMutableAttributedString conversion.
        var nsColor: NSColor = .white
        switch logMessage.flag {
        case .warning:
            nsColor = .yellow
        case .error:
            nsColor = .red
        case .debug:
            nsColor = NSColor(white: 0.75, alpha: 1)
        case .verbose:
            nsColor = NSColor(white: 0.55, alpha: 1)
        default:
            break
        }

        var newMessage = AttributedString(messageWithNewline)
        newMessage.appKit.foregroundColor = nsColor

        Task { @MainActor in
            self.entries.append(newMessage)
        }

        return logMessage.message
    }
}
