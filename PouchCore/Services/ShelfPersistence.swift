import Foundation

/// Reads and writes the shelf as JSON.
public struct ShelfPersistence: Sendable {
    /// Bump when the on-disk format changes incompatibly.
    static let currentVersion = 1

    private struct Snapshot: Codable {
        var version: Int
        var items: [ShelfItem]
    }

    public enum LoadError: Error {
        case unsupportedVersion(Int)
    }

    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `~/Library/Application Support/Pouch`, created if needed.
    public static func applicationSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("Pouch", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Returns an empty shelf if nothing has been saved yet.
    public func load() throws -> [ShelfItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data)
        guard snapshot.version <= Self.currentVersion else {
            throw LoadError.unsupportedVersion(snapshot.version)
        }
        return snapshot.items
    }

    public func save(_ items: [ShelfItem]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Snapshot(version: Self.currentVersion, items: items))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Atomic: write to a temp file and swap, so a crash never leaves half a file.
        try data.write(to: fileURL, options: .atomic)
    }

    /// Moves an unreadable file out of the way so the next save starts fresh
    /// without destroying it.
    public func quarantineCorruptFile() {
        let backup = fileURL.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? FileManager.default.moveItem(at: fileURL, to: backup)
    }
}
