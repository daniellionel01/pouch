import AppKit
import SwiftUI

/// The panel's content view: hosts the SwiftUI shelf and is the drop target
/// for the whole window, so you can drop anywhere on the pouch.
final class ShelfContainerView: NSView {
    private let dropHandler: DropHandler
    private let onTargetedChange: (Bool) -> Void
    /// Cursor position (screen coordinates) while something hovers over the shelf.
    var onDragMoved: ((NSPoint) -> Void)?

    init(content: NSView, dropHandler: DropHandler, onTargetedChange: @escaping (Bool) -> Void) {
        self.dropHandler = dropHandler
        self.onTargetedChange = onTargetedChange
        super.init(frame: .zero)
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        registerForDraggedTypes(DropHandler.draggedTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let operation = operation(for: sender)
        onTargetedChange(operation != [])
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
