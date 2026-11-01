//
//  TableView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import SwiftUI
import OrderedCollections
import UniformTypeIdentifiers

/// Uniform content height for every download-queue row. Rows size to their
/// tallest cell, and some cells (status icon, progress spinner) are taller than
/// a line of text while others are empty, so without a shared floor the rows
/// vary in height. Applied as a `minHeight` to each cell.
private let queueRowContentHeight: CGFloat = 28

struct DownloadQueueTableView: View {
    var downloadQueueViewModel: any DownloadQueueProviding

    @Binding var selection: Set<String>
    @State private var enteredPID: String = ""
    @State private var draggingPIDs: Set<String> = []
    @FocusState private var isTableFocused: Bool

    // Table caches its cell content. Read the binding in each cell's body so
    // ending a drag invalidates the appearance even when queue data is unchanged.
    private struct DragAppearance: ViewModifier {
        let pid: String
        @Binding var draggingPIDs: Set<String>

        func body(content: Content) -> some View {
            content.opacity(draggingPIDs.contains(pid) ? 0.4 : 1.0)
        }
    }

    var body: some View {
        VStack {
            Table(downloadQueueViewModel.downloadQueue, selection: $selection) {
                TableColumn("") { program in
                    DragHandleCell(
                        program: program,
                        selection: $selection,
                        downloadQueue: downloadQueueViewModel,
                        draggingPIDs: $draggingPIDs
                    )
                    .modifier(DragAppearance(pid: program.pid, draggingPIDs: $draggingPIDs))
                }
                .width(24)

                TableColumn("PID") { program in
                    Text(program.pid)
                        .frame(minHeight: queueRowContentHeight, maxHeight: .infinity)
                        .modifier(DragAppearance(pid: program.pid, draggingPIDs: $draggingPIDs))
                }
                .width(min: 60, ideal: 80, max: 120)

                TableColumn("Status") { program in
                    DownloadStatusImage(program: program)
                        .frame(maxWidth: .infinity, minHeight: queueRowContentHeight, maxHeight: .infinity)
                        .modifier(DragAppearance(pid: program.pid, draggingPIDs: $draggingPIDs))
                }
                .width(min: 20, ideal: 30, max: 40)

                TableColumn("Progress") { program in
                    DownloadProgressView(program: program)
                        .frame(minHeight: queueRowContentHeight, maxHeight: .infinity)
                        .modifier(DragAppearance(pid: program.pid, draggingPIDs: $draggingPIDs))
                }
                .width(min: 20, ideal: 30, max: 40)

                TableColumn("Name") { program in
                    Text(program.name)
                        .lineLimit(1)
                        .frame(minHeight: queueRowContentHeight, maxHeight: .infinity)
                        .modifier(DragAppearance(pid: program.pid, draggingPIDs: $draggingPIDs))
                }
                .width(min: 100, ideal: 200)

                TableColumn("Episode") { program in
                    Text(program.episode)
                        .lineLimit(1)
                        .frame(minHeight: queueRowContentHeight, maxHeight: .infinity)
                        .modifier(DragAppearance(pid: program.pid, draggingPIDs: $draggingPIDs))
                }
                .width(min: 80, ideal: 150)

                TableColumn("Available") { program in
                    Text(program.available, format: .dateTime.day().month(.abbreviated).year())
                        .frame(minHeight: queueRowContentHeight, maxHeight: .infinity)
                        .modifier(DragAppearance(pid: program.pid, draggingPIDs: $draggingPIDs))
                }
                .width(min: 80, ideal: 100, max: 120)

                TableColumn("Channel") { program in
                    Text(program.channel)
                        .frame(minHeight: queueRowContentHeight, maxHeight: .infinity)
                        .modifier(DragAppearance(pid: program.pid, draggingPIDs: $draggingPIDs))
                }
                .width(min: 60, ideal: 100, max: 150)

                TableColumn("Message") { program in
                    DownloadMessageView(program: program)
                        .lineLimit(1)
                        .frame(minHeight: queueRowContentHeight, maxHeight: .infinity)
                        .modifier(DragAppearance(pid: program.pid, draggingPIDs: $draggingPIDs))
                }
                .width(min: 80, ideal: 150)
            }
            .alternatingRowBackgrounds(.disabled)
            .focused($isTableFocused)
            // Transfer keyboard focus without replacing the table's row-selection gesture.
            .simultaneousGesture(TapGesture().onEnded {
                isTableFocused = true
            })
            .onDeleteCommand {
                for pid in selection {
                    downloadQueueViewModel.removeFromQueue(pid: pid)
                }
            }

            HStack {
                Form {
                    TextField(text: $enteredPID) {
                        Text("Program ID:")
                    }
                    .onSubmit {
                        downloadQueueViewModel.addToQueue(pid: enteredPID)
                    }
                    .frame(maxWidth: 250)
                }
                .disabled(downloadQueueViewModel.processPIDRunning)

                Button("Fetch Program") {
                    downloadQueueViewModel.addToQueue(pid: enteredPID)
                }
                .disabled(enteredPID.isEmpty || downloadQueueViewModel.processPIDRunning)
                .controlSize(.large)
                .padding(10)

                if downloadQueueViewModel.processPIDRunning {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()

                if downloadQueueViewModel.retryTimerActive, let fireDate = downloadQueueViewModel.retryFireDate {
                    RetryCountdownView(fireDate: fireDate) {
                        downloadQueueViewModel.cancelRetryTimer()
                    }
                }
            }
            .padding(10)
            .border(.bar)
        }
    }
}

struct DragHandleCell: View {
    let program: Programme
    @Binding var selection: Set<String>
    let downloadQueue: any DownloadQueueProviding
    @Binding var draggingPIDs: Set<String>

    var body: some View {
        QueueDragHandle(pid: program.pid, selection: $selection, draggingPIDs: $draggingPIDs)
            .frame(maxWidth: .infinity, minHeight: queueRowContentHeight, maxHeight: .infinity)
            .onDrop(of: [.text], delegate: DownloadQueueDropDelegate(
                targetPID: program.pid,
                downloadQueue: downloadQueue,
                draggingPIDs: $draggingPIDs
            ))
    }
}

struct DownloadQueueDropDelegate: DropDelegate {
    let targetPID: String
    let downloadQueue: any DownloadQueueProviding
    @Binding var draggingPIDs: Set<String>

    func performDrop(info: DropInfo) -> Bool {
        draggingPIDs = []
        return true
    }

    func dropEntered(info: DropInfo) {
        guard !draggingPIDs.isEmpty,
              !draggingPIDs.contains(targetPID),
              let toIndex = downloadQueue.downloadQueue.firstIndex(where: { $0.pid == targetPID }) else {
            return
        }

        // Resolve offsets against the current queue on each hover, since earlier
        // hover events may already have moved the block.
        let offsets = IndexSet(downloadQueue.downloadQueue.indices.filter {
            draggingPIDs.contains(downloadQueue.downloadQueue[$0].pid)
        })
        guard let firstIndex = offsets.first else { return }

        withAnimation {
            downloadQueue.movePrograms(fromOffsets: offsets, toOffset: toIndex > firstIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        !draggingPIDs.isEmpty && info.hasItemsConforming(to: [.text])
    }
}

struct RetryCountdownView: View {
    let fireDate: Date
    let onCancel: () -> Void

    @State private var remainingSeconds: Int = 0
    @State private var timer: Timer?

    private var countdownText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "Next download attempt: %d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(countdownText)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Cancel retry")
        }
        .onAppear {
            updateRemaining()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    updateRemaining()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private func updateRemaining() {
        remainingSeconds = max(0, Int(fireDate.timeIntervalSinceNow))
    }
}

#Preview {
    @Previewable @State var mockQueue = MockDownloadQueueViewModel()
    @Previewable @State var selection: Set<String> = []
    DownloadQueueTableView(downloadQueueViewModel: mockQueue, selection: $selection)
}

