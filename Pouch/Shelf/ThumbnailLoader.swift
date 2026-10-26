import AppKit
import QuickLookThumbnailing

/// Generates and caches Quick Look thumbnails.
@MainActor
final class ThumbnailLoader {
    struct Thumbnail {
        let image: NSImage
        /// True for a real preview (photo, page), false for a generic file icon.
        /// Previews fill their frame; icons are shown at their natural shape.
        let isPreview: Bool
    }

    static let shared = ThumbnailLoader()

    private let cache = NSCache<NSString, CachedThumbnail>()

    private final class CachedThumbnail {
        let thumbnail: Thumbnail
        init(_ thumbnail: Thumbnail) { self.thumbnail = thumbnail }
    }

    /// Instant placeholder while the real thumbnail is generated.
    func icon(for url: URL) -> Thumbnail {
        Thumbnail(image: NSWorkspace.shared.icon(forFile: url.path), isPreview: false)
    }

    func cachedThumbnail(for url: URL, size: CGSize) -> Thumbnail? {
        cache.object(forKey: cacheKey(for: url, size: size))?.thumbnail
    }

    func thumbnail(for url: URL, size: CGSize, scale: CGFloat) async -> Thumbnail {
        let key = cacheKey(for: url, size: size)
        if let cached = cache.object(forKey: key) { return cached.thumbnail }

        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .all)
        let thumbnail: Thumbnail
        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            thumbnail = Thumbnail(image: representation.nsImage, isPreview: representation.type == .thumbnail)
        } catch {
            // Unreadable or permission denied: fall back to the Finder icon.
            thumbnail = icon(for: url)
        }
        cache.setObject(CachedThumbnail(thumbnail), forKey: key)
        return thumbnail
    }

    /// Includes the modification date so edited files get a fresh thumbnail.
    private func cacheKey(for url: URL, size: CGSize) -> NSString {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
        return "\(url.path)|\(modified)|\(Int(size.width))x\(Int(size.height))" as NSString
    }
}
