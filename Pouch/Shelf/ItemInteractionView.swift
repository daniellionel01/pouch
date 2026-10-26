import AppKit
import SwiftUI

/// A transparent AppKit layer over each card that handles clicks, hover and
/// dragging out.
///
/// SwiftUI's `.onDrag` produces a single `NSItemProvider`, which doesn't give
/// reliable multi-file drags into Finder, Slack or browsers. An AppKit
/// `NSDraggingSession` with one `NSDraggingItem` per file does.
struct ItemInteractionView: NSViewRepresentable {
    let id: UUID
    /// Shown as the tooltip (this layer sits on top, so SwiftUI's `.help`
    /// underneath would never be hovered).
    let name: String
    let interactions: ShelfInteractions

    func makeNSView(context: Context) -> InteractionNSView {
        let view = InteractionNSView(id: id, interactions: interactions)
        interactions.register(view, for: id)
        view.toolTip = name
        return view
    }

    func updateNSView(_ nsView: InteractionNSView, context: Context) {
        nsView.id = id
        nsView.toolTip = name
        interactions.register(nsView, for: id)
    }
}

final class InteractionNSView: NSView, NSDraggingSource {
    var id: UUID
    private let interactions: ShelfInteractions
    private var mouseDownEvent: NSEvent?
    private var draggedIDs: [UUID] = []
    /// How far the mouse must move before a click turns into a drag.
    private static let dragThreshold: CGFloat = 3

    init(id: UUID, interactions: ShelfInteractions) {
        self.id = id
        self.interactions = interactions
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // Act on the very first click even when the shelf isn't the key window,
    // so you can grab a card and drag it out in one motion.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // Cards should be grabbed, not used as a handle to move the window.
    override var mouseDownCanMoveWindow: Bool { false }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        interactions.ui.hoveredID = id
    }

    override func mouseExited(with event: NSEvent) {
        if interactions.ui.hoveredID == id { interactions.ui.hoveredID = nil }
    }

    // MARK: - Clicks

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            mouseDownEvent = nil
            interactions.open([id])
            return
        }
        mouseDownEvent = event
        // Modifier clicks change the selection right away. A plain click on an
        // already-selected card waits for mouseUp, so dragging a multi-selection
        // doesn't collapse it first.
        if !event.modifierFlags.intersection([.command, .shift]).isEmpty || !interactions.ui.selection.contains(id) {
            interactions.click(id, modifiers: event.modifierFlags)
        }
    }

    override func mouseUp(with event: NSEvent) {
        // mouseDownEvent is cleared once a drag starts, so this is a real click.
        guard let down = mouseDownEvent else { return }
        mouseDownEvent = nil
        if down.modifierFlags.intersection([.command, .shift]).isEmpty {
            interactions.click(id, modifiers: [])
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let down = mouseDownEvent else { return }
        let start = convert(down.locationInWindow, from: nil)
        let now = convert(event.locationInWindow, from: nil)
        guard hypot(now.x - start.x, now.y - start.y) >= Self.dragThreshold else { return }
        mouseDownEvent = nil
        beginDrag(with: down)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        interactions.contextMenu(for: id)
    }

    // MARK: - Dragging out

    private func beginDrag(with event: NSEvent) {
        let ids = interactions.idsToDrag(startingAt: id)
        guard !ids.isEmpty else { return }

        let primaryImage = snapshot() ?? interactions.dragImage(for: id)
        var items: [NSDraggingItem] = []
        var stackOffset: CGFloat = 0
        // The card under the cursor leads; the rest fan out behind it.
        for itemID in [id] + ids.filter({ $0 != id }) where ids.contains(itemID) {
            guard let writer = interactions.pasteboardWriter(for: itemID) else { continue }
            let item = NSDraggingItem(pasteboardWriter: writer)
            if itemID == id {
                item.setDraggingFrame(bounds, contents: primaryImage)
            } else {
                stackOffset += 6
                let side = min(bounds.width, bounds.height) * 0.7
                let frame = NSRect(x: bounds.midX - side / 2 + stackOffset, y: bounds.midY - side / 2 - stackOffset, width: side, height: side)
                item.setDraggingFrame(frame, contents: interactions.dragImage(for: itemID))
            }
            items.append(item)
        }
        guard !items.isEmpty else { return }

        draggedIDs = ids
        interactions.dragBegan(ids)
        let session = beginDraggingSession(with: items, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .stack
    }

    /// The card as it looks right now, rendered from the hosting view.
    private func snapshot() -> NSImage? {
        guard let container = window?.contentView else { return nil }
        let rect = convert(bounds, to: container)
        guard let rep = container.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        container.cacheDisplay(in: rect, to: rep)
        let image = NSImage(size: rect.size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Copy only. Allowing .move would let Finder move the original file
        // when it's dropped into a folder on the same disk, and .delete would
        // let the Dock's Trash eat it.
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
        interactions.dragMoved(to: screenPoint)
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        interactions.dragEnded(draggedIDs, operation: operation)
        draggedIDs = []
    }
}
