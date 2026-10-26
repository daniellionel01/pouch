import Foundation

/// One thing parked on the shelf.
///
/// Files are kept by reference (bookmark data) so a moved or renamed file still
/// resolves. URLs and text are small, so they're stored as values.
public struct ShelfItem: Identifiable, Codable, Hashable, Sendable {
    public enum Source: String, Codable, Sendable {
        case drop
        case screenshot
    }

    public enum Content: Codable, Hashable, Sendable {
        /// `lastKnownPath` is a fallback for display and resolution when the
        /// bookmark can't be resolved (for example on a different machine).
        case file(bookmark: Data, lastKnownPath: String)
        case url(URL)
        case text(String)
    }

    public let id: UUID
    public var content: Content
    public let addedAt: Date
    public let source: Source

    public init(id: UUID = UUID(), content: Content, addedAt: Date = .now, source: Source = .drop) {
        self.id = id
        self.content = content
        self.addedAt = addedAt
        self.source = source
    }

    public var isFile: Bool {
        if case .file = content { return true }
        return false
    }

    /// Short label shown under the thumbnail.
    public var displayName: String {
        switch content {
        case .file(_, let path):
            return URL(fileURLWithPath: path).lastPathComponent
        case .url(let url):
            return url.host() ?? url.absoluteString
        case .text(let text):
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            return trimmed.count > 40 ? String(trimmed.prefix(40)) + "…" : trimmed
        }
    }
}
