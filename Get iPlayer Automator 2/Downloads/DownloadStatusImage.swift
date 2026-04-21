//
//  DownloadStatusImage.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 9/17/23.
//

import SwiftUI

struct DownloadStatusImage: View {

    var program: Programme

    var body: some View {
        Group {
            switch program.status {
            case .new:
                Image(systemName: "questionmark.circle")
                    .accessibilityLabel("Queued")
            case .processedPID:
                EmptyView()
            case .addedByPVR:
                Image(systemName: "recordingtape.circle")
                    .accessibilityLabel("Added by PVR")
            case .downloadingProgram, .finishedProgramDownload:
                Image(systemName: "arrow.down.circle")
                    .accessibilityLabel("Downloading")
            case .downloadingThumbnail, .finishedThumbnail:
                Image(systemName: "photo.tv")
                    .accessibilityLabel("Downloading thumbnail")
            case .tagging, .finishedTagging:
                Image(systemName: "tag")
                    .accessibilityLabel("Tagging")
            case .successful:
                Image(systemName: "checkmark")
                    .accessibilityLabel("Download complete")
            case .failed:
                Image(systemName: "x.circle")
                    .accessibilityLabel("Download failed")
            case .cancelled:
                Image(systemName: "x.circle")
                    .accessibilityLabel("Download cancelled")
            case .addingToLibrary:
                Image(systemName: "building.columns.fill")
                    .accessibilityLabel("Adding to library")
            }
        }
        .imageScale(.large)
    }
}

#Preview("New") {
    let program = Programme()
    program.status = .new
    return DownloadStatusImage(program: program)
}
#Preview("Processed PID") {
    let program = Programme()
    program.status = .processedPID
    return DownloadStatusImage(program: program)
}

#Preview("Downloading Program") {
    let program = Programme()
    program.status = .downloadingProgram
    return DownloadStatusImage(program: program)
}

#Preview("Finished Program Download") {
    let program = Programme()
    program.status = .finishedProgramDownload
    return DownloadStatusImage(program: program)
}

#Preview("Downloading Thumbnail") {
    let program = Programme()
    program.status = .downloadingThumbnail
    return DownloadStatusImage(program: program)
}

#Preview("Finished Thumbnail") {
    let program = Programme()
    program.status = .finishedThumbnail
    return DownloadStatusImage(program: program)
}

#Preview("Tagging") {
    let program = Programme()
    program.status = .tagging
    return DownloadStatusImage(program: program)
}

#Preview("Successful") {
    let program = Programme()
    program.status = .successful
    return DownloadStatusImage(program: program)
}

#Preview("Failed") {
    let program = Programme()
    program.status = .failed
    return DownloadStatusImage(program: program)
}

#Preview("Cancelled") {
    let program = Programme()
    program.status = .cancelled
    return DownloadStatusImage(program: program)
}

