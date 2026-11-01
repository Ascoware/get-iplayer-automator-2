import AppKit
import SwiftUI

/// Owns the source session so cleanup also runs for cancelled and rejected drops.
struct QueueDragHandle: NSViewRepresentable {
    let pid: String
    @Binding var selection: Set<String>
    @Binding var draggingPIDs: Set<String>

    func makeNSView(context: Context) -> HandleView {
        let view = HandleView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: HandleView, context: Context) {
        view.pid = pid
        view.selection = $selection
        view.draggingPIDs = $draggingPIDs
    }

    final class HandleView: NSView, NSDraggingSource {
        var pid = ""
        var selection: Binding<Set<String>>?
        var draggingPIDs: Binding<Set<String>>?
        private var mouseDownEvent: NSEvent?
        private let imageView = NSImageView()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            imageView.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "Reorder download")
            imageView.contentTintColor = .secondaryLabelColor
            imageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // The decorative NSImageView must never become the hit view: as an
        // NSControl, it can let NSTableView handle the click as row selection.
        override func hitTest(_ point: NSPoint) -> NSView? {
            super.hitTest(point) == nil ? nil : self
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override var mouseDownCanMoveWindow: Bool { false }

        override func mouseDown(with event: NSEvent) {
            mouseDownEvent = event
        }

        override func mouseDragged(with event: NSEvent) {
            guard let startEvent = mouseDownEvent,
                  hypot(event.locationInWindow.x - startEvent.locationInWindow.x,
                        event.locationInWindow.y - startEvent.locationInWindow.y) >= 4,
                  let image = imageView.image else { return }

            mouseDownEvent = nil
            let item = NSDraggingItem(pasteboardWriter: pid as NSString)
            item.setDraggingFrame(imageView.frame, contents: image)
            // Freeze membership for this session; reordering must not change
            // either the table selection or which rows are being moved.
            let selected = selection?.wrappedValue ?? []
            draggingPIDs?.wrappedValue = selected.contains(pid) ? selected : [pid]
            beginDraggingSession(with: [item], event: startEvent, source: self)
        }

        override func mouseUp(with event: NSEvent) {
            mouseDownEvent = nil
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .withinApplication ? .move : []
        }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            draggingPIDs?.wrappedValue = []
            mouseDownEvent = nil
        }
    }
}
