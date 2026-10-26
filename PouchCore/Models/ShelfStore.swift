import Foundation
import Observation
import os

/// The single source of truth for what's on the shelf.
///
/// Newest items come first. Every mutation is saved right away: the file is
/// tiny, and saving eagerly means a crash or force-quit never loses items.
@MainActor
@Observable
public final class ShelfStore {
    public private(set) var items: [ShelfItem] = []
    /// Runtime-only resolution state for file items. Not persisted.
    public private(set) var availability: [UUID: FileAvailability] = [:]

    @ObservationIgnored private let persistence: ShelfPersistence?
    @ObservationIgnored private let inbox: DropInbox?
    @ObservationIgnored private let logger = Logger(subsystem: "com.danielkurz.Pouch", category: "ShelfStore")

    public init(persistence: ShelfPersistence? = nil, inbox: DropInbox? = nil) {
        self.persistence = persistence
        self.inbox = inbox
    }

    public var isEmpty: Bool { items.isEmpty }

    public func item(withID id: UUID) -> ShelfItem? {
        items.first { $0.id == id }
    }

    /// The file's current location, or nil for non-file or missing items.
    public func fileURL(for id: UUID) -> URL? {
        if case .available(let url) = availability[id] { return url }
        return nil
    }

    public func isMissing(_ id: UUID) -> Bool {
        availability[id] == .missing
    }

    // MARK: - Loading

    public func load() {
        guard let persistence else { return }
        do {
            items = try persistence.load()
        } catch {
            logger.error("Couldn't read the saved shelf, starting empty: \(error.localizedDescription, privacy: .public)")
            persistence.quarantineCorruptFile()
            items = []
        }
        refreshAvailability()
    }

    // MARK: - Adding

    /// Adds files by reference. A file that's already on the shelf moves to
    /// the top instead of appearing twice. Returns the affected items.
    @discardableResult
    public func addFiles(_ urls: [URL], source: ShelfItem.Source = .drop) -> [ShelfItem] {
        var affected: [ShelfItem] = []
        // Insert in reverse so the first dropped file ends up on top.
        for url in urls.reversed() {
            let url = url.normalizedFileURL
            if let index = items.firstIndex(where: { fileURL(for: $0.id) == url }) {
                let existing = items.remove(at: index)
                items.insert(existing, at: 0)
                affected.insert(existing, at: 0)
                continue
            }
            let bookmark: Data
            do {
                bookmark = try BookmarkResolver.makeBookmark(for: url)
            } catch {
                // Still add it; it'll be tracked by path instead.
                logger.error("Couldn't bookmark \(url.path, privacy: .private): \(error.localizedDescription, privacy: .public)")
                bookmark = Data()
            }
            let item = ShelfItem(content: .file(bookmark: bookmark, lastKnownPath: url.path), source: source)
            items.insert(item, at: 0)
            availability[item.id] = FileManager.default.fileExists(atPath: url.path) ? .available(url) : .missing
            affected.insert(item, at: 0)
        }
        if !affected.isEmpty { save() }
        return affected
    }

    @discardableResult
    public func addURL(_ url: URL) -> ShelfItem {
        insertValue(.url(url))
    }

    /// Returns nil for empty or whitespace-only text.
    @discardableResult
    public func addText(_ text: String) -> ShelfItem? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return insertValue(.text(text))
    }

    private func insertValue(_ content: ShelfItem.Content) -> ShelfItem {
        if let index = items.firstIndex(where: { $0.content == content }) {
            let existing = items.remove(at: index)
            items.insert(existing, at: 0)
            save()
            return existing
        }
        let item = ShelfItem(content: content)
        items.insert(item, at: 0)
        save()
        return item
    }

    // MARK: - Removing

    /// Removes items from the shelf. The underlying files are left alone,
    /// except Pouch's own copies in the drop inbox.
    public func remove(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for id in ids {
            if let url = fileURL(for: id) { inbox?.deleteOwnedFile(at: url) }
            availability[id] = nil
        }
        items.removeAll { ids.contains($0.id) }
        save()
    }

    public func removeMissing() {
        remove(Set(items.map(\.id).filter(isMissing)))
    }

    public func clear() {
        remove(Set(items.map(\.id)))
    }

    // MARK: - Resolution

    /// Re-resolves every file bookmark: picks up moves and renames, flags
    /// deleted files as missing, and refreshes stale bookmarks.
    public func refreshAvailability() {
        var newAvailability: [UUID: FileAvailability] = [:]
        var updatedItems = items
        var contentChanged = false

        for index in updatedItems.indices {
            guard case .file(let bookmark, let lastKnownPath) = updatedItems[index].content else { continue }
            let resolution = BookmarkResolver.resolve(bookmark: bookmark, lastKnownPath: lastKnownPath)
            newAvailability[updatedItems[index].id] = resolution.availability

            let newBookmark = resolution.refreshedBookmark ?? bookmark
            var newPath = lastKnownPath
            if case .available(let url) = resolution.availability {
                newPath = url.path
            }
            if newBookmark != bookmark || newPath != lastKnownPath {
                updatedItems[index].content = .file(bookmark: newBookmark, lastKnownPath: newPath)
                contentChanged = true
            }
        }

        // Only assign when something changed: assigning an equal value still
        // notifies observers, which would redraw the shelf for nothing.
        if newAvailability != availability { availability = newAvailability }
        if contentChanged {
            items = updatedItems
            save()
        }
    }

    // MARK: - Saving

    private func save() {
        guard let persistence else { return }
        do {
            try persistence.save(items)
        } catch {
            logger.error("Couldn't save the shelf: \(error.localizedDescription, privacy: .public)")
        }
    }
}
