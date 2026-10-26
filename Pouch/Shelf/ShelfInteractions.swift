import AppKit
import PouchCore
import SwiftUI

/// What happens when you click, select and drag cards on the shelf.
@MainActor
final class ShelfInteractions {
    let store: ShelfStore
    let ui: ShelfUIState
    let sounds: SoundPlayer
    let quickLook = QuickLookController()
    private let settings: AppSettings
    /// Last plainly-clicked item, the fixed end of a Shift-click range.
    private var anchorID: UUID?
    /// Card views by item, held weakly, for Quick Look's zoom animation.
    private let cardViews = NSMapTable<NSUUID, NSView>.strongToWeakObjects()

    /// Escape with nothing selected; the panel controller puts the shelf away.
    var onDismiss: (() -> Void)?
    /// Knows when a context menu is open, so the shelf doesn't tuck away
    /// underneath it.
    let menuTracker = MenuTracker()

    init(store: ShelfStore, ui: ShelfUIState, settings: AppSettings, sounds: SoundPlayer) {
        self.store = store
        self.ui = ui
        self.settings = settings
        self.sounds = sounds
    }

    // MARK: - Selection (Finder-style)

    func click(_ id: UUID, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) {
            if ui.selection.contains(id) {
                ui.selection.remove(id)
            } else {
                ui.selection.insert(id)
            }
            anchorID = id
        } else if modifiers.contains(.shift), let anchorID, let range = indexRange(from: anchorID, to: id) {
            ui.selection = Set(store.items[range].map(\.id))
        } else {
            ui.selection = [id]
            anchorID = id
        }
    }

    /// Makes `id` the selection unless it's already part of it, like Finder
    /// does before a right-click or drag.
    func ensureSelected(_ id: UUID) {
        if !ui.selection.contains(id) {
            ui.selection = [id]
            anchorID = id
        }
    }

    func clearSelection() {
        ui.selection = []
    }

    func selectAll() {
        ui.selection = Set(store.items.map(\.id))
    }

    /// Selection in shelf order, dropping anything that's no longer there.
    var orderedSelection: [UUID] {
        store.items.map(\.id).filter(ui.selection.contains)
    }

    private func indexRange(from a: UUID, to b: UUID) -> ClosedRange<Int>? {
        guard let i = store.items.firstIndex(where: { $0.id == a }),
              let j = store.items.firstIndex(where: { $0.id == b }) else { return nil }
        return min(i, j)...max(i, j)
    }

    // MARK: - Card views

    func register(_ view: NSView, for id: UUID) {
        cardViews.setObject(view, forKey: id as NSUUID)
    }

    /// The card's frame in screen coordinates, if it's on screen.
    func screenFrame(of id: UUID) -> NSRect? {
        guard let view = cardViews.object(forKey: id as NSUUID), let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    // MARK: - Dragging out

    /// The items a drag starting on `id` should carry: the whole selection if
    /// `id` is part of it, otherwise just `id` (which becomes the selection).
    func idsToDrag(startingAt id: UUID) -> [UUID] {
        ensureSelected(id)
        return orderedSelection.filter { pasteboardWriter(for: $0) != nil }
    }

    /// What goes on the dragging pasteboard for one item. Real file URLs are
    /// what Finder, Slack, browsers' upload fields, Figma and Mail all expect.
    /// Missing files can't be dragged.
    func pasteboardWriter(for id: UUID) -> NSPasteboardWriting? {
        guard let item = store.item(withID: id) else { return nil }
        switch item.content {
        case .file:
            return store.fileURL(for: id).map { $0 as NSURL }
        case .url(let url):
            return url as NSURL
        case .text(let text):
            return text as NSString
        }
    }

    /// A small image for items other than the one under the cursor.
    func dragImage(for id: UUID) -> NSImage {
        if let url = store.fileURL(for: id) {
            return ThumbnailLoader.shared.cachedThumbnail(for: url, size: ItemView.thumbnailSize)?.image
                ?? ThumbnailLoader.shared.icon(for: url).image
        }
        let symbol = store.item(withID: id).map { $0.isFile ? "doc" : "link" } ?? "doc"
        return NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage()
    }

    func dragBegan(_ ids: [UUID]) {
        ui.draggingIDs = Set(ids)
    }

    /// Cursor position during a drag out, so the pouch can watch it go.
    var onDragMoved: ((NSPoint) -> Void)?

    func dragMoved(to screenPoint: NSPoint) {
        onDragMoved?(screenPoint)
    }

    func dragEnded(_ ids: [UUID], operation: NSDragOperation) {
        ui.draggingIDs = []
        // An empty operation means the drop was cancelled or refused.
        guard operation != [] else { return }
        ui.dragOutCount += 1
        guard settings.removeAfterDragOut else { return }
        sounds.play(.poof)
        withAnimation(.pouchLand) {
            store.remove(Set(ids))
            ui.selection.subtract(ids)
        }
    }
}

/// Tracks whether a context menu is on screen.
@MainActor
final class MenuTracker: NSObject, NSMenuDelegate {
    private(set) var isOpen = false

    func menuWillOpen(_ menu: NSMenu) { isOpen = true }
    func menuDidClose(_ menu: NSMenu) { isOpen = false }
}
