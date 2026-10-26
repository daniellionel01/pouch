import AppKit
import QuickLookUI

/// Feeds the system Quick Look panel and makes it zoom out of the card.
///
/// `QLPreviewPanel` is a shared panel that asks the responder chain for a
/// controller; `ShelfPanel` answers and hands it this object.
@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    private var urls: [URL] = []
    private var sourceFrame: (URL) -> NSRect? = { _ in nil }

    var isVisible: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && (QLPreviewPanel.shared()?.isVisible ?? false)
    }

    func toggle(urls: [URL], sourceFrame: @escaping (URL) -> NSRect?) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if isVisible {
            panel.orderOut(nil)
            return
        }
        guard !urls.isEmpty else { return }
        self.urls = urls
        self.sourceFrame = sourceFrame
        // Keep the preview above the floating shelf.
        panel.level = .floating
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    // MARK: - QLPreviewPanelDataSource

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { urls.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        // Return a Sendable URL across the isolation boundary, then bridge.
        let url: URL? = MainActor.assumeIsolated { urls.indices.contains(index) ? urls[index] : nil }
        return url.map { $0 as NSURL }
    }

    // MARK: - QLPreviewPanelDelegate

    /// Where the zoom animation starts and ends: the item's card on screen.
    nonisolated func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: (any QLPreviewItem)!) -> NSRect {
        guard let url = item?.previewItemURL else { return .zero }
        return MainActor.assumeIsolated { sourceFrame(url) ?? .zero }
    }
}
