//
//  DownloadHistoryView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 8/10/23.
//

import SwiftUI
import OrderedCollections

struct DownloadHistoryView: View {
    @State private var viewModel: DownloadHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var window: NSWindow?

    init(historyModel: any DownloadHistoryProviding) {
        viewModel = DownloadHistoryViewModel(historyModel: historyModel)
    }
    
    var body: some View {
        VStack {
            Table(
                viewModel.sortedTableData,
                selection: $viewModel.selection,
                sortOrder: $viewModel.sortOrder) {
                    TableColumn("Program ID", value: \.pid)
                    TableColumn("Show", value: \.show)
                    TableColumn("Episode", value: \.episode)
                }
            HStack {
                Button("Remove") {
                    viewModel.removeSelected()
                }
                .disabled(!viewModel.canRemove)
                Spacer()
                Button("Save") {
                    viewModel.save()
                }
                .disabled(!viewModel.canSave)
            }
            .padding(15)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { newValue in
            if let closingWindow = newValue.object as? NSWindow, closingWindow == window {
                if !viewModel.handleWindowClose() {
                    // Window close was prevented, dialog will show
                } else {
                    dismiss()
                }
            }
        }
        .confirmationDialog("Do you want to save changes to the history before closing?", isPresented: $viewModel.isShowingDiscardChanges) {
            Button("Save") {
                viewModel.saveAndDismiss()
                dismiss()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDiscard()
            }
        }
        .background(WindowAccessor(window: $window))
    }
}

#Preview("Download History") {
    @Previewable @State var mockHistory = MockDownloadHistoryModel()
    DownloadHistoryView(historyModel: mockHistory)
        .frame(width: 600, height: 400)
}

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            self.window = view.window
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

