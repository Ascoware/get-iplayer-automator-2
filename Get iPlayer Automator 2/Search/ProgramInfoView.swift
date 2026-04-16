//
//  ProgramInfoView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 4/15/26.
//

import SwiftUI

private struct ModeSize: Identifiable {
    let id: Int
    let version: String
    let mode: String
    let size: String
}

private struct ModeSizesTable: View {
    let modeSizes: [[String: String]]

    private var rows: [ModeSize] {
        modeSizes
            .sorted {
                let g0 = $0["group"] ?? "Z"
                let g1 = $1["group"] ?? "Z"
                if g0 != g1 { return g0 < g1 }
                let s0 = Int($0["size"] ?? "0") ?? 0
                let s1 = Int($1["size"] ?? "0") ?? 0
                return s0 > s1
            }
            .enumerated()
            .map { i, d in
                ModeSize(id: i, version: d["version"] ?? "", mode: d["mode"] ?? "", size: d["size"] ?? "")
            }
    }

    var body: some View {
        Table(rows) {
            TableColumn("Version", value: \.version)
            TableColumn("Mode", value: \.mode)
            TableColumn("Size") { row in
                let bytes = Int(row.size) ?? 0
                Text(bytes > 0 ? "\(bytes / (1024 * 1024)) MB" : row.size)
            }
        }
    }
}

struct ProgramInfoView: View {
    let programme: CachedProgramme

    enum LoadState {
        case loading
        case loaded(ProgrammeExtendedInfo)
        case unavailable
    }

    @State private var loadState: LoadState = .loading
    @Environment(\.dismiss) private var dismiss

    private var displayDesc: String {
        if case .loaded(let info) = loadState, !info.programme.desc.isEmpty {
            return info.programme.desc
        }
        return programme.desc
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            descriptionSection
            Divider()
            extendedSection
            Divider()
            footerSection
        }
        .frame(width: 700)
        .task {
            let fetcher = ProgrammeMetadataFetch(pid: programme.pid)
            if let info = await fetcher.getExtendedInfo() {
                loadState = .loaded(info)
            } else {
                loadState = .unavailable
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 16) {
            AsyncImage(url: programme.thumbnail) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                default:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.secondary.opacity(0.15))
                }
            }
            .frame(width: 178, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(programme.name)
                    .font(.title3.bold())
                if !programme.episode.isEmpty {
                    Text(programme.episode)
                        .font(.subheadline)
                }
                if programme.seriesNum > 0 || programme.episodeNum > 0 {
                    Text("Series: \(programme.seriesNum)  Episode: \(programme.episodeNum)")
                        .foregroundStyle(.secondary)
                }
                if programme.duration > 0 {
                    Text("Duration: \(programme.duration / 60) minutes")
                        .foregroundStyle(.secondary)
                }
                if case .loaded(let info) = loadState, !info.categories.isEmpty {
                    Text("Categories: \(info.categories)")
                        .foregroundStyle(.secondary)
                }
                Text(programme.channel)
                    .foregroundStyle(.secondary)
                Text(programme.typeDescription)
                    .foregroundStyle(.secondary)
                broadcastDates
            }
            .font(.callout)

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var broadcastDates: some View {
        HStack(spacing: 16) {
            if case .loaded(let info) = loadState {
                let firstBcast = info.programme.available
                if firstBcast > Date(timeIntervalSince1970: 0) {
                    Label(firstBcast.formatted(date: .abbreviated, time: .omitted),
                          systemImage: "calendar.badge.clock")
                    .help("First broadcast")
                }
            }
            Label(programme.available.formatted(date: .abbreviated, time: .omitted),
                  systemImage: "calendar")
            .help("Last broadcast")
        }
        .foregroundStyle(.secondary)
        .font(.callout)
    }

    private var descriptionSection: some View {
        ScrollView {
            Text(displayDesc)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .frame(height: 110)
    }

    @ViewBuilder
    private var extendedSection: some View {
        switch loadState {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Loading programme information…")
                    .foregroundStyle(.secondary)
            }
            .frame(height: 110)

        case .unavailable:
            Label("Extended programme information is not available.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
                .frame(height: 110)

        case .loaded(let info):
            if info.modeSizes.isEmpty {
                Text("No format information available.")
                    .foregroundStyle(.secondary)
                    .frame(height: 110)
            } else {
                ModeSizesTable(modeSizes: info.modeSizes)
                    .frame(height: 130)
            }
        }
    }

    private var footerSection: some View {
        HStack {
            if let web = programme.web {
                Link("Open in Browser", destination: web)
                    .font(.callout)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

#Preview("Programme Info") {
    ProgramInfoView(programme: CachedProgramme(
        pid: "m001nq2z",
        index: 1,
        type: .tv,
        name: "Wimbledon: 2023",
        episode: "Day 6, Part 2",
        seriesNum: 2023,
        episodeNum: 0,
        channel: "BBC One",
        available: Date(),
        expires: nil,
        duration: 5400,
        desc: "Further live action from day six of Wimbledon 2023.",
        web: URL(string: "https://www.bbc.co.uk/programmes/m001nq2z"),
        thumbnail: URL(string: "https://ichef.bbci.co.uk/images/ic/192xn/p0fzss2c.jpg"),
        timeadded: nil,
        radio: false,
        podcast: false,
        realPID: ""
    ))
}
