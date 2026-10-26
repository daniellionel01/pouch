import AppKit
import PouchCore
import SwiftUI

/// What happens when you click, select and drag cards on the shelf.
@MainActor
final class ShelfInteractions {
    let store: ShelfStore
    let ui: ShelfUIState
    private let settings: AppSettings
    private let sounds: SoundPlayer
    /// Last plainly-clicked item, the fixed end of a Shift-click range.
    private var anchorID: UUID?

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

    // MARK: - Dragging out

    /// The items a drag starting on `id` should carry: the whole selection if
    /// `id` is part of it, otherwise just `id` (which becomes the selection).
    func idsToDrag(startingAt id: UUID) -> [UUID] {
        if !ui.selection.contains(id) {
            ui.selection = [id]
            anchorID = id
        }
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
            return ThumbnailLoader.shared.cachedThumbnail(for: url, size: ItemCardView.thumbnailSize)?.image
                ?? ThumbnailLoader.shared.icon(for: url).image
        }
        let symbol = store.item(withID: id).map { $0.isFile ? "doc" : "link" } ?? "doc"
        return NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage()
    }

    func dragBegan(_ ids: [UUID]) {
        ui.draggingIDs = Set(ids)
    }

    func dragEnded(_ ids: [UUID], operation: NSDragOperation) {
        ui.draggingIDs = []
        // An empty operation means the drop was cancelled or refused.
        guard operation != [], settings.removeAfterDragOut else { return }
        sounds.play(.poof)
        withAnimation(.pouchLand) {
            store.remove(Set(ids))
            ui.selection.subtract(ids)
        }
    }
}
