import AppKit
import SwiftUI

/// A transparent area that moves the window when dragged.
///
/// `isMovableByWindowBackground` alone is unreliable over SwiftUI content,
/// because the hosting view decides per point whether a click "belongs" to a
/// control. `performDrag(with:)` hands the drag to the window server
/// explicitly, which works everywhere this view is hit.
struct WindowDragArea: NSViewRepresentable {
    var onClick: (() -> Void)?

    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: DragView, context: Context) {
        nsView.onClick = onClick
    }

    final class DragView: NSView {
        var onClick: (() -> Void)?

        override func mouseDown(with event: NSEvent) {
            onClick?()
            window?.performDrag(with: event)
        }

        override var mouseDownCanMoveWindow: Bool { true }
    }
}
