import AppKit
import PouchCore
import SwiftUI

/// The panel's content view: hosts the SwiftUI shelf and is the drop target
/// for the whole window, so you can drop anywhere on the pouch.
///
/// The window shrinks to a small tab when the shelf is tucked against a
/// screen edge, but the shelf itself keeps its full size: this view pins it
/// to the top and to the edge facing the screen, and the window simply clips
/// it. That way SwiftUI never re-lays out the shelf while it slides in and
/// out; it just unrolls from the tab.
final class ShelfContainerView: NSView {
    private let content: NSView
    private let contentWidth: CGFloat
    private let dropHandler: DropHandler
    private let onTargetedChange: (Bool) -> Void
    /// Cursor position (screen coordinates) while something hovers over the shelf.
    var onDragMoved: ((NSPoint) -> Void)?
    /// The cursor came over the shelf (or the tucked strip of it).
    var onMouseEntered: (() -> Void)?
    /// A drag that Pouch can accept came over the shelf.
    var onDragEntered: (() -> Void)?

    var dockSide: DockSide = .right {
        didSet { needsLayout = true }
    }
    /// The shelf's full height. While the window is smaller (tucked or
    /// sliding), the shelf keeps this height instead of being squashed.
    var contentHeight: CGFloat = 0 {
        didSet { needsLayout = true }
    }

    init(content: NSView, contentWidth: CGFloat, dropHandler: DropHandler, onTargetedChange: @escaping (Bool) -> Void) {
        self.content = content
        self.contentWidth = contentWidth
        self.dropHandler = dropHandler
        self.onTargetedChange = onTargetedChange
        super.init(frame: .zero)
        addSubview(content)
        registerForDraggedTypes(DropHandler.draggedTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layout() {
        super.layout()
        // Docked on the right, the screen-facing edge is the shelf's left
        // side, and vice versa.
        let x = dockSide == .right ? 0 : bounds.width - contentWidth
        let height = max(bounds.height, contentHeight)
        content.frame = NSRect(x: x, y: bounds.height - height, width: contentWidth, height: height)
    }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let operation = operation(for: sender)
        onTargetedChange(operation != [])
        if operation != [] { onDragEntered?() }
        return operation
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let window { onDragMoved?(window.convertPoint(toScreen: sender.draggingLocation)) }
        return operation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetedChange(false)
        return withAnimation(.pouchLand) { dropHandler.accept(sender.draggingPasteboard) }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onTargetedChange(false)
    }

    private func operation(for sender: NSDraggingInfo) -> NSDragOperation {
        // `draggingSource` is only non-nil for drags that started inside
        // Pouch, i.e. one of our own cards. Dropping those back is a no-op.
        guard sender.draggingSource == nil, dropHandler.canAccept(sender.draggingPasteboard) else { return [] }
        return .copy
    }
}
