import Foundation

/// Where Pouch writes things that arrive without a file of their own, such as
/// raw image data dragged from a browser or files delivered by a file promise.
///
/// Everything in here belongs to Pouch, so removing such an item from the
/// shelf also deletes its file. Files outside the inbox are never deleted.
public struct DropInbox: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Writes `data` to a uniquely named file and returns its URL.
    public func write(_ data: Data, baseName: String, fileExtension: String, date: Date = .now) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = uniqueURL(baseName: "\(baseName) \(Self.timestamp(date))", fileExtension: fileExtension)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// A fresh, empty subfolder, for receivers (like `NSFilePromiseReceiver`)
    /// that pick their own file names and shouldn't collide with each other.
    public func makeUniqueSubdirectory() throws -> URL {
        let url = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    public func contains(_ url: URL) -> Bool {
        let inbox = directory.normalizedFileURL.pathComponents
        let candidate = url.normalizedFileURL.pathComponents
        return candidate.count > inbox.count && Array(candidate.prefix(inbox.count)) == inbox
    }

    /// Deletes an inbox file, plus its per-drop subfolder if that's now empty.
    public func deleteOwnedFile(at url: URL) {
        guard contains(url) else { return }
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: url)
        let parent = url.deletingLastPathComponent()
        if parent.normalizedFileURL != directory.normalizedFileURL,
           (try? fileManager.contentsOfDirectory(atPath: parent.path))?.isEmpty == true {
            try? fileManager.removeItem(at: parent)
        }
    }

    private func uniqueURL(baseName: String, fileExtension: String) -> URL {
        var candidate = directory.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName) (\(counter))").appendingPathExtension(fileExtension)
            counter += 1
        }
        return candidate
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return formatter.string(from: date)
    }
}
