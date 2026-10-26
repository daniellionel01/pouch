import AppKit
import ImageIO
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
    /// Nil entries remember "not an image" so we don't re-read the file.
    private var aspectRatios: [String: CGFloat?] = [:]

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

    /// Width ÷ height of an image file, read from its header only (cheap),
    /// so items can be laid out at their real shape before the thumbnail
    /// exists. Nil for anything that isn't an image.
    func imageAspectRatio(for url: URL) -> CGFloat? {
        if let known = aspectRatios[url.path] { return known }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat,
              width > 0, height > 0
        else {
            aspectRatios[url.path] = .some(nil)
            return nil
        }
        // EXIF orientations 5–8 are rotated by 90°.
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let ratio = orientation >= 5 ? height / width : width / height
        aspectRatios[url.path] = ratio
        return ratio
    }

    /// Includes the modification date so edited files get a fresh thumbnail.
    private func cacheKey(for url: URL, size: CGSize) -> NSString {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)?.timeIntervalSince1970 ?? 0
        return "\(url.path)|\(modified)|\(Int(size.width))x\(Int(size.height))" as NSString
    }
}
