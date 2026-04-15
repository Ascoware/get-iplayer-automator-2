//
//  ActivityView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 4/14/26.
//

import SwiftUI

struct ActivityView: View {
    var cacheUpdateService: CacheUpdateService
    var downloadQueueViewModel: any DownloadQueueProviding
    var pvrViewModel: PVRViewModel

    private var currentDownload: Programme? {
        downloadQueueViewModel.downloadQueue.first { programme in
            switch programme.status {
            case .downloadingProgram, .downloadingThumbnail, .tagging:
                return true
            default:
                return false
            }
        }
    }

    private var hasActivity: Bool {
        cacheUpdateService.isUpdating || pvrViewModel.isChecking || currentDownload != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !hasActivity {
                Text("No activity")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if cacheUpdateService.isUpdating {
                ActivityRow(
                    title: "Updating Programme Index",
                    detail: cacheUpdateService.currentProgress
                )
            }

            if pvrViewModel.isChecking {
                ActivityRow(
                    title: "Checking Series-Link",
                    detail: "Searching for new episodes..."
                )
            }

            if let show = currentDownload {
                DownloadActivityRow(programme: show)
            }
        }
        .padding(8)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 500)
    }
}

// MARK: - Activity Row (indeterminate)

private struct ActivityRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            if !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            ProgressView()
                .progressViewStyle(.linear)
        }
    }
}

// MARK: - Download Activity Row (determinate progress)

private struct DownloadActivityRow: View {
    var programme: Programme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(programmeTitle)
                .font(.headline)

            Text(programme.progress)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if programme.downloadPercent > 0 {
                ProgressView(value: programme.downloadPercent, total: 100.0)
                    .progressViewStyle(.linear)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
    }

    private var programmeTitle: String {
        if programme.episode.isEmpty {
            return programme.name
        }
        return "\(programme.name) - \(programme.episode)"
    }
}
