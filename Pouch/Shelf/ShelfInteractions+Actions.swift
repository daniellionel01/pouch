import AppKit
import Carbon.HIToolbox
import PouchCore
import SwiftUI
import UniformTypeIdentifiers

/// Item actions: open, reveal, copy, remove, Quick Look, clear all, plus the
/// context menu and keyboard shortcuts that trigger them.
extension ShelfInteractions {
    // MARK: - Actions

    func open(_ ids: [UUID]) {
        for id in ids {
            guard let item = store.item(withID: id) else { continue }
            switch item.content {
            case .file:
                if let url = store.fileURL(for: id) { NSWorkspace.shared.open(url) }
            case .url(let url):
                NSWorkspace.shared.open(url)
            case .text:
                break
            }
        }
    }

    func reveal(_ ids: [UUID]) {
        let urls = ids.compactMap(store.fileURL(for:))
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Copies to the clipboard. Image files also carry their image data, so
    /// pasting into Slack or Figma pastes the picture, not a file path.
    func copy(_ ids: [UUID]) {
        let items: [NSPasteboardWriting] = ids.compactMap { id in
            if let url = store.fileURL(for: id) { return pasteboardItem(forFile: url) }
            return pasteboardWriter(for: id)
        }
        guard !items.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(items)
    }

    func remove(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        sounds.play(.poof)
        withAnimation(.pouchLand) {
            store.remove(Set(ids))
            ui.selection.subtract(ids)
        }
    }

    func removeMissing() {
        remove(store.items.map(\.id).filter(store.isMissing))
    }

    func toggleQuickLook() {
        let ids = orderedSelection.filter { store.fileURL(for: $0) != nil }
        let urls = ids.compactMap(store.fileURL(for:))
        let idsByURL = Dictionary(zip(urls, ids), uniquingKeysWith: { first, _ in first })
        quickLook.toggle(urls: urls) { [weak self] url in
            idsByURL[url].flatMap { self?.screenFrame(of: $0) }
        }
    }

    /// Empties the shelf with a little flourish: the pouch shakes and the
    /// cards tumble out the bottom. Files on disk are never touched (apart
    /// from Pouch's own inbox copies).
    func clearAll() {
        guard !store.isEmpty, !ui.isTumbling else { return }
        sounds.play(.shakeOut)
        ui.selection = []
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            withAnimation(.easeOut(duration: 0.2)) { store.clear() }
            return
        }
        ui.shakeCount += 1
        ui.isTumbling = true
        Task {
            try? await Task.sleep(for: .seconds(0.75))
            // The cards are already out of sight; remove them without a
            // second (removal) animation.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                store.clear()
                ui.isTumbling = false
            }
        }
    }

    // MARK: - Context menu

    func contextMenu(for id: UUID) -> NSMenu {
        ensureSelected(id)
        let ids = orderedSelection
        let fileIDs = ids.filter { store.fileURL(for: $0) != nil }
        let openableIDs = ids.filter { id in
            guard let item = store.item(withID: id) else { return false }
            if case .url = item.content { return true }
            return store.fileURL(for: id) != nil
        }
        let count = ids.count

        let menu = NSMenu()
        // We set isEnabled ourselves; auto-enabling would enable everything
        // because every item has a valid target.
        menu.autoenablesItems = false
        func add(_ item: NSMenuItem, enabled: Bool = true) {
            item.isEnabled = enabled
            menu.addItem(item)
        }

        add(ClosureMenuItem("Open", symbol: "arrow.up.forward.app") { [weak self] in self?.open(openableIDs) }, enabled: !openableIDs.isEmpty)
        add(ClosureMenuItem("Reveal in Finder", symbol: "folder") { [weak self] in self?.reveal(fileIDs) }, enabled: !fileIDs.isEmpty)
        add(ClosureMenuItem("Quick Look", symbol: "eye", keyEquivalent: " ") { [weak self] in self?.toggleQuickLook() }, enabled: !fileIDs.isEmpty)
        add(ClosureMenuItem("Copy", symbol: "doc.on.doc", keyEquivalent: "c", modifiers: .command) { [weak self] in self?.copy(ids) })
        menu.addItem(.separator())
        let removeTitle = count > 1 ? "Remove \(count) Items" : "Remove from Pouch"
        add(ClosureMenuItem(removeTitle, symbol: "minus.circle", keyEquivalent: "\u{8}") { [weak self] in self?.remove(ids) })
        if store.items.contains(where: { store.isMissing($0.id) }) {
            add(ClosureMenuItem("Remove Missing Items", symbol: "figure.walk.motion") { [weak self] in self?.removeMissing() })
        }
        return menu
    }

    // MARK: - Keyboard

    /// Returns true if the key was handled.
    func handleKeyDown(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function, .capsLock])
        switch Int(event.keyCode) {
        case kVK_Space where modifiers.isEmpty:
            toggleQuickLook()
            return true
        case kVK_Delete, kVK_ForwardDelete:
            remove(orderedSelection)
            return true
        case kVK_Escape:
            if ui.selection.isEmpty {
                onDismiss?()
            } else {
                clearSelection()
            }
            return true
        default:
            break
        }
        guard modifiers == .command else { return false }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "a":
            selectAll()
        case "c":
            copy(orderedSelection)
        case "o":
            open(orderedSelection)
        default:
            return false
        }
        return true
    }

    // MARK: - Helpers

    private func pasteboardItem(forFile url: URL) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            if type.conforms(to: .png), let data = try? Data(contentsOf: url) {
                item.setData(data, forType: .png)
            } else if let tiff = NSImage(contentsOf: url)?.tiffRepresentation {
                item.setData(tiff, forType: .tiff)
            }
        }
        return item
    }
}
