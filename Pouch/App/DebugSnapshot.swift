#if DEBUG
import AppKit

/// Development aid: `POUCH_SNAPSHOT=/path/to/file.png` makes a Debug build
/// render the shelf's content view to a PNG shortly after launch. It's handy
/// for checking layout without Screen Recording permission. Materials and
/// glass don't render this way, so the background looks flat.
enum DebugSnapshot {
    static func scheduleIfRequested(for window: NSWindow) {
        guard let path = ProcessInfo.processInfo.environment["POUCH_SNAPSHOT"] else { return }
        let delay = Double(ProcessInfo.processInfo.environment["POUCH_SNAPSHOT_DELAY"] ?? "") ?? 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard let view = window.contentView,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
    }
}
#endif
