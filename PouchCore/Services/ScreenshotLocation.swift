import Foundation

/// Where macOS saves screenshots, as set in the Screenshot app (⌘⇧5 →
/// Options) or with `defaults write com.apple.screencapture location`.
public enum ScreenshotLocation {
    public static func current(
        defaults: UserDefaults? = UserDefaults(suiteName: "com.apple.screencapture"),
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        let desktop = home.appendingPathComponent("Desktop", isDirectory: true)
        guard let raw = defaults?.string(forKey: "location"), !raw.isEmpty else { return desktop }

        let path: String
        if raw == "~" {
            path = home.path
        } else if raw.hasPrefix("~/") {
            path = home.appendingPathComponent(String(raw.dropFirst(2))).path
        } else {
            path = raw
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            // A stale setting (e.g. an unplugged drive): macOS falls back to the Desktop too.
            return desktop
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
