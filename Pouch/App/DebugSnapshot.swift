#if DEBUG
import AppKit

/// Development aid: `POUCH_SNAPSHOT=/path/to/file.png` makes a Debug build
/// render the shelf's content view to a PNG shortly after launch. It's handy
/// for checking layout without Screen Recording permission. Set
/// `POUCH_SNAPSHOT_WINDOW=settings` to capture the Settings window instead,
/// `POUCH_APPEARANCE=dark|light` to force an appearance, and
/// `POUCH_DEBUG_HOVER=1` to show the shelf as if something hovers over it,
/// `POUCH_DEBUG_TUCKED=1` to capture it tucked against the edge
/// (`POUCH_SNAPSHOT_FULL=1` renders the whole unclipped shelf view),
/// and `POUCH_DEBUG_REACT=gulp|snap|shake` to fire a reaction after 1 s. Materials and
/// glass don't render this way, so the background looks flat.
enum DebugSnapshot {
    static func scheduleIfRequested(for window: NSWindow) {
        guard let path = ProcessInfo.processInfo.environment["POUCH_SNAPSHOT"] else { return }
        let delay = Double(ProcessInfo.processInfo.environment["POUCH_SNAPSHOT_DELAY"] ?? "") ?? 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // POUCH_SNAPSHOT_FULL renders the full-size shelf view rather than
            // the (possibly tucked, clipped) window contents.
            let root = window.contentView
            let full = ProcessInfo.processInfo.environment["POUCH_SNAPSHOT_FULL"] != nil
            guard let view = full ? root?.subviews.first : root,
                  let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
    }
}
#endif
