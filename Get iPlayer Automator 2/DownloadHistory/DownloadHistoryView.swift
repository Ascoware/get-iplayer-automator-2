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
        .confirmationDialog("Do you want to save changes to the history before closing?", isPresented: $viewModel.isShowingDiscardChanges) {
            Button("Save") {
                if viewModel.save() {
                    window?.close()
                }
            }
            Button("Discard Changes", role: .destructive) {
                viewModel.discardChanges()
                window?.close()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDiscard()
            }
        }
        .background(HistoryWindowAccessor(window: $window, shouldClose: viewModel.handleWindowClose))
    }
}

#Preview("Download History") {
    @Previewable @State var mockHistory = MockDownloadHistoryModel()
    DownloadHistoryView(historyModel: mockHistory)
        .frame(width: 600, height: 400)
}

private struct HistoryWindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?
    let shouldClose: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(owner: self)
    }

    func makeNSView(context: Context) -> WindowView {
        let view = WindowView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: WindowView, context: Context) {
        context.coordinator.owner = self
    }

    static func dismantleNSView(_ view: WindowView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class WindowView: NSView {
        weak var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator?.attach(to: window)
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var owner: HistoryWindowAccessor
        private weak var attachedWindow: NSWindow?
        private weak var originalDelegate: (any NSWindowDelegate)?

        init(owner: HistoryWindowAccessor) {
            self.owner = owner
        }

        func attach(to window: NSWindow?) {
            guard attachedWindow !== window else { return }
            detach()
            attachedWindow = window
            originalDelegate = window?.delegate
            window?.delegate = self
            Task { @MainActor [weak self, weak window] in
                guard let self, self.attachedWindow === window else { return }
                self.owner.window = window
            }
        }

        func detach() {
            if attachedWindow?.delegate === self {
                attachedWindow?.delegate = originalDelegate
            }
            attachedWindow = nil
            originalDelegate = nil
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard owner.shouldClose() else { return false }
            return originalDelegate?.windowShouldClose?(sender) ?? true
        }

        // Preserve SwiftUI's window delegate behavior for all other callbacks.
        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || originalDelegate?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            if originalDelegate?.responds(to: selector) == true {
                return originalDelegate
            }
            return super.forwardingTarget(for: selector)
        }
    }
}

