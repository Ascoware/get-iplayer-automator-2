//
//  TableView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 7/30/23.
//

import SwiftUI
import OrderedCollections
import UniformTypeIdentifiers

struct DownloadQueueTableView: View {
    var downloadQueueViewModel: any DownloadQueueProviding

    @State private var selection: Set<String> = []
    @State private var enteredPID: String = ""
    @State private var draggingPID: String?

    var body: some View {
        VStack {
            Table(downloadQueueViewModel.downloadQueue, selection: $selection) {
                TableColumn("") { program in
                    DragHandleCell(
                        program: program,
                        downloadQueue: downloadQueueViewModel,
                        draggingPID: $draggingPID
                    )
                    .opacity(draggingPID == program.pid ? 0.4 : 1.0)
                }
                .width(24)

                TableColumn("PID") { program in
                    Text(program.pid)
                        .frame(maxHeight: .infinity)
                        .opacity(draggingPID == program.pid ? 0.4 : 1.0)
                }
                .width(min: 60, ideal: 80, max: 120)

                TableColumn("Status") { program in
                    DownloadStatusImage(program: program)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(draggingPID == program.pid ? 0.4 : 1.0)
                }
                .width(min: 20, ideal: 30, max: 40)

                TableColumn("Progress") { program in
                    DownloadProgressView(program: program)
                        .frame(maxHeight: .infinity)
                        .opacity(draggingPID == program.pid ? 0.4 : 1.0)
                }
                .width(min: 20, ideal: 30, max: 40)

                TableColumn("Name") { program in
                    Text(program.name)
                        .lineLimit(1)
                        .frame(maxHeight: .infinity)
                        .opacity(draggingPID == program.pid ? 0.4 : 1.0)
                }
                .width(min: 100, ideal: 200)

                TableColumn("Episode") { program in
                    Text(program.episode)
                        .lineLimit(1)
                        .frame(maxHeight: .infinity)
                        .opacity(draggingPID == program.pid ? 0.4 : 1.0)
                }
                .width(min: 80, ideal: 150)

                TableColumn("Available") { program in
                    Text(program.available, format: .dateTime.day().month(.abbreviated).year())
                        .frame(maxHeight: .infinity)
                        .opacity(draggingPID == program.pid ? 0.4 : 1.0)
                }
                .width(min: 80, ideal: 100, max: 120)

                TableColumn("Channel") { program in
                    Text(program.channel)
                        .frame(maxHeight: .infinity)
                        .opacity(draggingPID == program.pid ? 0.4 : 1.0)
                }
                .width(min: 60, ideal: 100, max: 150)

                TableColumn("Message") { program in
                    DownloadMessageView(program: program)
                        .lineLimit(1)
                        .frame(maxHeight: .infinity)
                        .opacity(draggingPID == program.pid ? 0.4 : 1.0)
                }
                .width(min: 80, ideal: 150)
            }
            .alternatingRowBackgrounds(.disabled)
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
            }
            .padding(10)
            .border(.bar)
        }
    }
}

struct DragHandleCell: View {
    let program: Programme
    let downloadQueue: any DownloadQueueProviding
    @Binding var draggingPID: String?

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onDrag {
                draggingPID = program.pid
                return NSItemProvider(object: program.pid as NSString)
            }
            .onDrop(of: [.text], delegate: DownloadQueueDropDelegate(
                targetPID: program.pid,
                downloadQueue: downloadQueue,
                draggingPID: $draggingPID
            ))
    }
}

struct DownloadQueueDropDelegate: DropDelegate {
    let targetPID: String
    let downloadQueue: any DownloadQueueProviding
    @Binding var draggingPID: String?

    func performDrop(info: DropInfo) -> Bool {
        draggingPID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingPID = draggingPID,
              draggingPID != targetPID,
              let fromIndex = downloadQueue.downloadQueue.firstIndex(where: { $0.pid == draggingPID }),
              let toIndex = downloadQueue.downloadQueue.firstIndex(where: { $0.pid == targetPID }) else {
            return
        }

        withAnimation {
            downloadQueue.movePrograms(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropExited(info: DropInfo) {
        // Clear dragging state when drag leaves the table area
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }
}

#Preview {
    @Previewable @State var mockQueue = MockDownloadQueueViewModel()
    DownloadQueueTableView(downloadQueueViewModel: mockQueue)
}

