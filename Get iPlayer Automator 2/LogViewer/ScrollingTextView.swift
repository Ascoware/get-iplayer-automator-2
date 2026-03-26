//
//  ScrollingTextView.swift
//  Get iPlayer Automator 2
//
//  Created by Scott Kovatch on 2/6/25.
//

import SwiftUI

/// NSViewRepresentable wrapper for NSTextView with stick-to-bottom scrolling behavior.
/// Automatically scrolls to bottom when new content is added, but only if already at bottom.
struct ScrollingTextView: NSViewRepresentable {

    let entries: [AttributedString]
    let clearID: Int  // increment to trigger a clear

    /// Shared handle allowing callers to reach the underlying NSTextView.
    final class Handle {
        weak var textView: NSTextView?

        var plainText: String {
            textView?.string ?? ""
        }
    }

    private static let monospacedFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    /// NSTextView subclass that opts out of Edit menu revalidation so that
    /// appending log text does not cause repeated menu item churn.
    private class LogTextView: NSTextView {
        override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
//            let action = item.action
//            // Allow copy and select-all; reject everything else (undo, redo, cut, paste, delete…)
//            if action == #selector(copy(_:)) || action == #selector(selectAll(_:)) {
//                return super.validateUserInterfaceItem(item)
//            }
            return false
        }
    }

    class Coordinator {
        let handle: Handle
        private var lastClearID: Int = 0
        private var processedCount: Int = 0

        init(handle: Handle) {
            self.handle = handle
        }

        func sync(entries: [AttributedString], clearID: Int, font: NSFont) {
            if clearID != lastClearID {
                lastClearID = clearID
                processedCount = 0
                clear()
            }

            guard processedCount < entries.count else { return }
            for entry in entries[processedCount...] {
                append(entry, font: font)
            }
            processedCount = entries.count
        }

        private func append(_ entry: AttributedString, font: NSFont) {
            guard let textView = handle.textView, let textStorage = textView.textStorage else { return }

            let scrollView = textView.enclosingScrollView
            let wasAtBottom: Bool
            if let scrollView {
                wasAtBottom = isScrolledToBottom(scrollView)
            } else {
                wasAtBottom = true
            }

            let nsEntry = NSMutableAttributedString(entry)
            nsEntry.addAttribute(.font, value: font, range: NSRange(location: 0, length: nsEntry.length))

            textStorage.append(nsEntry)

            if wasAtBottom {
                textView.scrollToEndOfDocument(nil)
            }
        }

        private func clear() {
            guard let textView = handle.textView, let textStorage = textView.textStorage else { return }
            textStorage.setAttributedString(NSAttributedString())
        }

        private func isScrolledToBottom(_ scrollView: NSScrollView) -> Bool {
            guard let documentView = scrollView.documentView else { return true }
            let clipView = scrollView.contentView
            let contentHeight = documentView.frame.height
            let clipViewHeight = clipView.bounds.height
            let scrollPosition = clipView.bounds.origin.y
            let bottomPosition = contentHeight - clipViewHeight
            return scrollPosition >= bottomPosition - 20
        }
    }

    let handle: Handle

    func makeCoordinator() -> Coordinator {
        Coordinator(handle: handle)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = LogTextView.scrollableTextView()

        if let textView = scrollView.documentView as? NSTextView {
            textView.isSelectable = true
            textView.isEditable = false
            textView.drawsBackground = true
            textView.backgroundColor = .black
            textView.textContainerInset = NSSize(width: 10, height: 10)
            textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            context.coordinator.handle.textView = textView
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.sync(entries: entries, clearID: clearID, font: Self.monospacedFont)
    }
}
