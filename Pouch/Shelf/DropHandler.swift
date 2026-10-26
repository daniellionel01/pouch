import AppKit
import PouchCore
import SwiftUI
import os

/// Turns whatever was dropped on the shelf into shelf items.
///
/// We read `NSPasteboard` directly instead of SwiftUI's `onDrop`: it's
/// synchronous, handles multi-file drops in one go, and supports file
/// promises (Mail attachments, the screenshot thumbnail, some browser images).
@MainActor
final class DropHandler {
    static let draggedTypes: [NSPasteboard.PasteboardType] =
        [.fileURL, .URL, .png, .tiff, .string]
            + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }

    private static let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private let store: ShelfStore
    private let inbox: DropInbox?
    private let logger = Logger(subsystem: "com.danielkurz.Pouch", category: "Drop")

    /// Called after items land, for the gulp animation and sound.
    var onItemsAdded: (([ShelfItem]) -> Void)?

    init(store: ShelfStore, inbox: DropInbox?) {
        self.store = store
        self.inbox = inbox
    }

    func canAccept(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self, NSFilePromiseReceiver.self, NSImage.self, NSString.self], options: nil)
    }

    /// Returns false if nothing usable was on the pasteboard.
    func accept(_ pasteboard: NSPasteboard) -> Bool {
        // Most specific first: real files beat a picture of a file, and a
        // picture beats the web URL it came from.
        let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if !fileURLs.isEmpty {
            addFiles(fileURLs)
            return true
        }

        let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
        if !promises.isEmpty, inbox != nil {
            receive(promises)
            return true
        }

        if let imageURL = writeImage(from: pasteboard) {
            addFiles([imageURL])
            return true
        }

        let webURLs = (pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []).filter { !$0.isFileURL }
        if !webURLs.isEmpty {
            added(webURLs.reversed().map { store.addURL($0) })
            return true
        }

        if let text = pasteboard.string(forType: .string) {
            if let url = Self.singleWebURL(in: text) {
                added([store.addURL(url)])
                return true
            }
            if let item = store.addText(text) {
                added([item])
                return true
            }
        }
        return false
    }

    // MARK: - Helpers

    private func addFiles(_ urls: [URL]) {
        added(store.addFiles(urls))
    }

    private func added(_ items: [ShelfItem]) {
        guard !items.isEmpty else { return }
        onItemsAdded?(items)
    }

    /// File promises are fulfilled asynchronously by the source app, into a
    /// folder we choose. Each file is added as it arrives.
    private func receive(_ promises: [NSFilePromiseReceiver]) {
        guard let inbox else { return }
        let destination: URL
        do {
            destination = try inbox.makeUniqueSubdirectory()
        } catch {
            logger.error("Couldn't create a folder for promised files: \(error.localizedDescription, privacy: .public)")
            return
        }
        for promise in promises {
            promise.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: Self.promiseQueue) { [weak self] url, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.logger.error("A promised file never arrived: \(error.localizedDescription, privacy: .public)")
                        return
                    }
                    withAnimation(.pouchLand) { self.addFiles([url]) }
                }
            }
        }
    }

    /// Raw image data (no file behind it) is saved into the inbox as a PNG.
    private func writeImage(from pasteboard: NSPasteboard) -> URL? {
        guard let inbox else { return nil }
        var png = pasteboard.data(forType: .png)
        if png == nil,
           let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff) {
            png = bitmap.representation(using: .png, properties: [:])
        }
        guard let png else { return nil }
        do {
            return try inbox.write(png, baseName: "Dropped image", fileExtension: "png")
        } catch {
            logger.error("Couldn't save a dropped image: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Text that is exactly one http(s) link is treated as a URL item.
    static func singleWebURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host() != nil
        else { return nil }
        return url
    }
}
