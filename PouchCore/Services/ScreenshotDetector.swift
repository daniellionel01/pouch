import Foundation

/// Recognizes screenshot files by the metadata macOS attaches to them.
///
/// `screencapture` writes `kMDItemIsScreenCapture` as an extended attribute
/// on the file itself, so this works without Spotlight and without guessing
/// from (localized, user-configurable) file names.
public enum ScreenshotDetector {
    static let attributeName = "com.apple.metadata:kMDItemIsScreenCapture"

    public static func isScreenCapture(_ url: URL) -> Bool {
        guard let data = extendedAttribute(attributeName, of: url) else { return false }
        // The value is a binary plist holding a boolean (or number).
        let value = try? PropertyListSerialization.propertyList(from: data, format: nil)
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? false
    }

    private static func extendedAttribute(_ name: String, of url: URL) -> Data? {
        url.withUnsafeFileSystemRepresentation { path -> Data? in
            guard let path else { return nil }
            let size = getxattr(path, name, nil, 0, 0, 0)
            guard size > 0 else { return nil }
            var data = Data(count: size)
            let read = data.withUnsafeMutableBytes { getxattr(path, name, $0.baseAddress, size, 0, 0) }
            return read == size ? data : nil
        }
    }
}
