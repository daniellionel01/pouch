import Foundation

/// Whether a file item's file can currently be found.
public enum FileAvailability: Equatable, Sendable {
    case available(URL)
    case missing
}

/// Creates and resolves bookmark data for files on the shelf.
///
/// Pouch isn't sandboxed, so these are plain bookmarks rather than
/// security-scoped ones (those only matter inside the App Sandbox). A bookmark
/// tracks the file by its file-system identity, so it still resolves after the
/// file is moved or renamed on the same volume.
public enum BookmarkResolver {
    public struct Resolution: Equatable, Sendable {
        public let availability: FileAvailability
        /// A fresh bookmark when the stored one is stale or was missing;
        /// persist it so later resolutions stay fast and accurate.
        public let refreshedBookmark: Data?
    }

    public static func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    public static func resolve(bookmark: Data, lastKnownPath: String, fileManager: FileManager = .default) -> Resolution {
        var isStale = false
        if !bookmark.isEmpty,
           let url = try? URL(
               resolvingBookmarkData: bookmark,
               // Never show "connect to server" UI or mount volumes from here.
               options: [.withoutUI, .withoutMounting],
               relativeTo: nil,
               bookmarkDataIsStale: &isStale
           ) {
            let url = url.normalizedFileURL
            // A bookmark happily follows a file into the Trash. To the user,
            // a trashed file is gone.
            if isInTrash(url) {
                return Resolution(availability: .missing, refreshedBookmark: nil)
            }
            if fileManager.fileExists(atPath: url.path) {
                let refreshed = isStale ? try? makeBookmark(for: url) : nil
                return Resolution(availability: .available(url), refreshedBookmark: refreshed)
            }
        }

        // The bookmark is empty (it couldn't be created) or no longer
        // resolves, but something may still exist at the old path.
        if fileManager.fileExists(atPath: lastKnownPath) {
            let url = URL(fileURLWithPath: lastKnownPath).normalizedFileURL
            return Resolution(availability: .available(url), refreshedBookmark: try? makeBookmark(for: url))
        }
        return Resolution(availability: .missing, refreshedBookmark: nil)
    }

    static func isInTrash(_ url: URL) -> Bool {
        url.pathComponents.contains { $0 == ".Trash" || $0 == ".Trashes" }
    }
}

extension URL {
    /// Standardized with symlinks resolved, so the same file always compares
    /// equal (for example `/var/...` and `/private/var/...`).
    var normalizedFileURL: URL {
        standardizedFileURL.resolvingSymlinksInPath()
    }
}
