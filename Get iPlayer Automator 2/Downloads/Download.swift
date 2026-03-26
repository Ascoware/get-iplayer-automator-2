//
//  Download.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/1/23.
//

import Foundation
import SwiftUI
import CocoaLumberjackSwift
import Subprocess

@MainActor
public class Download {

//    let proxy: HTTPProxy
    @Default(\.getADVideo) var getADVideo
    @Default(\.getSignedVideo) var getSignedVideo
    @Default(\.verbose) var verbose
    @Default(\.downloadSubtitles) var downloadSubtitles
    @Default(\.embedSubtitles) var embedSubtitles
    @Default(\.useKodiNaming) var useKodiNaming
    @Default(\.use25FPSStreams) var use25FPSStreams
    @Default(\.tagDownloadsWithMetadata) var tagDownloads
    @Default(\.tagRadioAsPodcast) var tagRadio

    let show: Programme

    //Download Information
    @Default(\.downloadPath) var downloadPath

    var filepath: String = ""

    var hdVideo: Bool = false

    var currentExecution: Execution?

    //Proxy Info
    //var proxy: HTTPProxy?
    // If proxy is set, this will be a session configured with the set proxy.
    // Otherwise, it uses the system (shared) session information.
    var currentRequest: URLSessionDataTask?

    public init(program: Programme) {
        show = program
    }

    func start() async {

    }

    func cancel() {
        try? currentExecution?.send(signal: .terminate, toProcessGroup: true)
        show.status = .cancelled
        DDLogInfo("Download Cancelled")
    }
}
