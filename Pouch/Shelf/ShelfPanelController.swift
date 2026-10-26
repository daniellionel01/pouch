import AppKit
import PouchCore
import SwiftUI

/// Creates the shelf panel and handles showing, hiding and positioning it.
@MainActor
final class ShelfPanelController {
    private static let frameAutosaveName = "PouchShelf"
    /// How often to re-check that files on the shelf still exist while it's
    /// visible. Bookmark resolution is cheap, and this keeps the "missing"
    /// state honest without file-system watchers on every item.
    private static let refreshInterval: TimeInterval = 5

    let panel = ShelfPanel()
    let ui = ShelfUIState()
    private let store: ShelfStore
    private let dropHandler: DropHandler
    private let interactions: ShelfInteractions
    private var refreshTimer: Timer?

    init(store: ShelfStore, settings: AppSettings, inbox: DropInbox?, sounds: SoundPlayer) {
        self.store = store
        dropHandler = DropHandler(store: store, inbox: inbox)
        interactions = ShelfInteractions(store: store, ui: ui, settings: settings, sounds: sounds)

        let hostingView = NSHostingView(rootView: ShelfView(store: store, settings: settings, ui: ui, interactions: interactions))
        // Don't let SwiftUI resize the window; the panel's frame is ours.
        hostingView.sizingOptions = []
        panel.contentView = ShelfContainerView(content: hostingView, dropHandler: dropHandler) { [ui] targeted in
            if ui.isDropTargeted != targeted { ui.isDropTargeted = targeted }
        }

        dropHandler.onItemsAdded = { [ui] _ in
            ui.gulpCount += 1
            sounds.play(.gulp)
        }
        restoreFrame()
    }

    var isVisible: Bool { panel.isVisible }

    /// Shows the shelf without making it key, so the frontmost app keeps
    /// keyboard focus. It becomes key once you click it.
    func show() {
        store.refreshAvailability()
        panel.orderFrontRegardless()
        startRefreshing()
    }

    func hide() {
        panel.orderOut(nil)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    private func startRefreshing() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            // Scheduled on the main run loop, so we're already on the main actor.
            MainActor.assumeIsolated {
                withAnimation(.pouchLand) { self?.store.refreshAvailability() }
            }
        }
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
