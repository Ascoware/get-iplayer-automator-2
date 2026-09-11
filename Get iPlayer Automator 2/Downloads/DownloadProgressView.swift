//
//  DownloadProgressView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 9/17/23.
//

import SwiftUI

struct DownloadProgressView: View {
    var program: Programme

    var body: some View {
        Group {
            if program.downloadPercent > 0.0 {
                ProgressView(value: program.downloadPercent, total: 100)
            } else if program.status == .downloadingProgram
                        || program.status == .downloadingThumbnail
                        || program.status == .tagging {
                ProgressView()
            }
        }
        .progressViewStyle(.circular)
        .controlSize(.small)
    }
}
