import AppKit
import PouchCore
import SwiftUI

/// Creates the shelf panel and handles showing, hiding and positioning it.
@MainActor
final class ShelfPanelController {
    private static let frameAutosaveName = "PouchShelf"

    let panel = ShelfPanel()
    let ui = ShelfUIState()

    init(settings: AppSettings) {
        let hostingView = NSHostingView(rootView: ShelfView(settings: settings, ui: ui))
        // Don't let SwiftUI resize the window; the panel's frame is ours.
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        restoreFrame()
    }

    var isVisible: Bool { panel.isVisible }

    /// Shows the shelf without making it key, so the frontmost app keeps
    /// keyboard focus. It becomes key once you click it.
    func show() {
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    private func restoreFrame() {
        // `setFrameAutosaveName` both restores a saved frame and keeps saving
        // it whenever the panel moves or resizes.
        let restored = panel.setFrameUsingName(Self.frameAutosaveName)
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
        if !restored || !onScreen {
            placeAtDefaultPosition()
        }
    }

    /// Top-right corner of the main screen, under the menu bar.
    private func placeAtDefaultPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(x: visible.maxX - size.width - 20, y: visible.maxY - size.height - 20)
        panel.setFrameOrigin(origin)
    }
}
