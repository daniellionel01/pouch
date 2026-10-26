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
    /// Remembers whether you left the shelf open or tucked away.
    private static let visibleDefaultsKey = "shelfVisible"

    let panel = ShelfPanel()
    let ui = ShelfUIState()
    private let store: ShelfStore
    private let dropHandler: DropHandler
    private let interactions: ShelfInteractions
    private let director: CharacterDirector
    private var refreshTimer: Timer?
    private var peekTask: Task<Void, Never>?
    private var keyMonitor: Any?
    /// Whether the shelf is (or is animating to be) on screen.
    private var isShown = false
    /// Increments per animation so a stale completion handler does nothing.
    private var animationGeneration = 0

    init(store: ShelfStore, settings: AppSettings, inbox: DropInbox?, sounds: SoundPlayer) {
        self.store = store
        dropHandler = DropHandler(store: store, inbox: inbox)
        interactions = ShelfInteractions(store: store, ui: ui, settings: settings, sounds: sounds)
        director = CharacterDirector(store: store, ui: ui)

        let hostingView = NSHostingView(rootView: ShelfView(
            store: store, settings: settings, ui: ui, interactions: interactions, character: director.character
        ))
        // Don't let SwiftUI resize the window; the panel's frame is ours.
        hostingView.sizingOptions = []
        let container = ShelfContainerView(content: hostingView, dropHandler: dropHandler) { [ui] targeted in
            if ui.isDropTargeted != targeted { ui.isDropTargeted = targeted }
        }
        container.onDragMoved = { [director] point in director.cursorMoved(to: point) }
        panel.contentView = container

        director.faceCenter = { [panel] in
            NSPoint(x: panel.frame.midX, y: panel.frame.maxY - ShelfPanel.margin - 27)
        }
        director.panelFrame = { [panel] in panel.frame }
        interactions.onDragMoved = { [director] point in director.cursorMoved(to: point) }

        panel.quickLook = interactions.quickLook
        interactions.onDismiss = { [weak self] in self?.closeFromShelf() }
        installKeyMonitor()

        dropHandler.onItemsAdded = { [ui] _ in
            ui.gulpCount += 1
            sounds.play(.gulp)
        }
        restoreFrame()
    }

    var isVisible: Bool { isShown }

    /// True unless you tucked the shelf away last time Pouch ran.
    var wasVisibleLastTime: Bool {
        UserDefaults.standard.object(forKey: Self.visibleDefaultsKey) as? Bool ?? true
    }

    /// Shows the shelf without making it key, so the frontmost app keeps
    /// keyboard focus. It becomes key once you click it.
    func show() {
        cancelPeek()
        UserDefaults.standard.set(true, forKey: Self.visibleDefaultsKey)
        present()
    }

    /// Puts the shelf away; it comes back from the menu bar icon or ⌥⌘P.
    func hide() {
        cancelPeek()
        UserDefaults.standard.set(false, forKey: Self.visibleDefaultsKey)
        dismiss()
    }

    /// Esc: the pouch shuts its eyes, then puts itself away.
    private func closeFromShelf() {
        director.closeEyes()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.14))
            self?.hide()
        }
    }

    func toggle() {
        isShown && peekTask == nil ? hide() : show()
    }

    /// Shows the shelf for a few seconds (when a screenshot arrives, say) and
    /// tucks it away again, unless you're hovering, dragging or clicked it.
    /// Does nothing if the shelf is already open for real.
    func peek(for duration: Duration = .seconds(4)) {
        guard !isShown || peekTask != nil else { return }
        present()
        peekTask?.cancel()
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            self.peekTask = nil
            let engaged = self.panel.frame.contains(NSEvent.mouseLocation)
                || self.panel.isKeyWindow
                || !self.ui.draggingIDs.isEmpty
            // Peeks don't change the remembered visibility.
            if !engaged { self.dismiss() }
        }
    }

    private func cancelPeek() {
        peekTask?.cancel()
        peekTask = nil
    }

    // MARK: - Show/hide animation
    // The pouch pops up in place and shrinks away in place; the window never
    // moves. (Sliding it toward the menu bar icon looked fine from the
    // default top-right spot but sent it across the screen from anywhere
    // else.) SwiftUI scales the pouch while the window's alpha fades, which
    // also fades the window shadow with it.

    private func present() {
        store.refreshAvailability()
        startRefreshing()
        director.clearReaction()
        director.start()
        guard !isShown else {
            panel.orderFrontRegardless()
            return
        }
        isShown = true
        animationGeneration += 1
        let generation = animationGeneration
        if !panel.isVisible { panel.alphaValue = 0 }
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { ui.isPresented = true }
        Task { [weak self] in
            // The window server's shadow follows the content's shape; refresh
            // it once the pop has settled.
            try? await Task.sleep(for: .seconds(0.45))
            guard let self, generation == self.animationGeneration else { return }
            self.panel.invalidateShadow()
        }
    }

    private func dismiss() {
        stopRefreshing()
        director.stop()
        guard isShown else { return }
        isShown = false
        animationGeneration += 1
        let generation = animationGeneration
        withAnimation(.easeIn(duration: 0.16)) { ui.isPresented = false }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // Shown again before the fade finished: leave it on screen.
                guard let self, generation == self.animationGeneration else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
            }
        }
    }

    /// Clear the shelf, from the menu bar or the header button.
    func clearAll() {
        interactions.clearAll()
    }

    /// Space, Delete, Escape and ⌘A/⌘C/⌘O while the shelf is the key window.
    /// A local monitor sees key events before any view, so SwiftUI focus
    /// doesn't matter.
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated {
                guard let self, event.window === self.panel else { return false }
                return self.interactions.handleKeyDown(event)
            }
            return handled ? nil : event
        }
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
