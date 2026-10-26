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
    private var refreshTimer: Timer?
    private var peekTask: Task<Void, Never>?
    private var keyMonitor: Any?
    /// Whether the shelf is (or is animating to be) on screen.
    private var isShown = false
    /// Where the panel lives while a tuck/untuck animation moves it around.
    /// Restored afterwards so the remembered position never drifts.
    private var homeOrigin: NSPoint?
    /// Increments per animation so a stale completion handler does nothing.
    private var animationGeneration = 0

    /// The menu bar icon's frame in screen coordinates; the shelf tucks into it.
    var tuckTarget: (() -> NSRect?)?

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

        panel.quickLook = interactions.quickLook
        interactions.onDismiss = { [weak self] in self?.hide() }
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

    /// Tucks the shelf back into the menu bar icon.
    func hide() {
        cancelPeek()
        UserDefaults.standard.set(false, forKey: Self.visibleDefaultsKey)
        dismiss()
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

    // MARK: - Tuck animation
    // The shelf slides out of (and back into) the menu bar icon while fading.
    // Only the window's position and alpha animate; resizing it would make
    // SwiftUI re-lay out the content every frame.

    private func present() {
        store.refreshAvailability()
        startRefreshing()
        guard !isShown || homeOrigin != nil else {
            panel.orderFrontRegardless()
            return
        }
        isShown = true
        let home = homeOrigin ?? panel.frame.origin
        guard let tucked = tuckedOrigin(home: home) else {
            finishAnimation(alpha: 1)
            panel.orderFrontRegardless()
            return
        }
        if !panel.isVisible {
            panel.alphaValue = 0
            panel.setFrameOrigin(tucked)
        }
        homeOrigin = home
        panel.orderFrontRegardless()
        animate(to: home, alpha: 1, duration: 0.3, timing: .easeOut) { [weak self] in
            self?.finishAnimation(alpha: 1)
        }
    }

    private func dismiss() {
        stopRefreshing()
        guard isShown else { return }
        isShown = false
        let home = homeOrigin ?? panel.frame.origin
        guard let tucked = tuckedOrigin(home: home) else {
            panel.orderOut(nil)
            return
        }
        homeOrigin = home
        animate(to: tucked, alpha: 0, duration: 0.22, timing: .easeIn) { [weak self] in
            guard let self else { return }
            self.panel.orderOut(nil)
            self.finishAnimation(alpha: 1)
        }
    }

    private func animate(to origin: NSPoint, alpha: CGFloat, duration: TimeInterval, timing: CAMediaTimingFunctionName, completion: @escaping @MainActor () -> Void) {
        animationGeneration += 1
        let generation = animationGeneration
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: timing)
            panel.animator().setFrameOrigin(origin)
            panel.animator().alphaValue = alpha
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                // A newer animation has taken over; let it finish instead.
                guard let self, generation == self.animationGeneration else { return }
                completion()
            }
        }
    }

    /// Puts the panel back at its home position (which also keeps the
    /// autosaved frame correct).
    private func finishAnimation(alpha: CGFloat) {
        if let homeOrigin { panel.setFrameOrigin(homeOrigin) }
        homeOrigin = nil
        panel.alphaValue = alpha
    }

    /// Most of the way from the shelf's top edge to the menu bar icon. Nil
    /// (no animation) with Reduce Motion or when the icon can't be found.
    private func tuckedOrigin(home: NSPoint) -> NSPoint? {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, let target = tuckTarget?() else { return nil }
        let frame = NSRect(origin: home, size: panel.frame.size)
        let progress: CGFloat = 0.75
        return NSPoint(
            x: home.x + (target.midX - frame.midX) * progress,
            y: home.y + (target.minY - frame.maxY) * progress
        )
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
