import AppKit
import PouchCore
import SwiftUI

/// Creates the shelf panel and docks it to a screen edge.
///
/// The shelf lives tucked against the right (or left) edge with a thin strip
/// showing. It slides out when you hover that strip, drag a file onto it, a
/// screenshot arrives, or you use the menu bar icon or hotkey, and tucks
/// itself away again once the cursor leaves. Dragging the shelf moves it
/// along the edge, or across to the other edge.
@MainActor
final class ShelfPanelController {
    /// How often to re-check that files on the shelf still exist while it's
    /// out. Bookmark resolution is cheap, and this keeps the "missing" state
    /// honest without file-system watchers on every item.
    private static let refreshInterval: TimeInterval = 5
    /// Hover this long over the strip before the shelf slides out, so just
    /// passing the screen edge doesn't trigger it.
    private static let hoverIntent: Duration = .milliseconds(140)
    /// The cursor has to be gone this long before the shelf tucks away.
    private static let leaveGrace: TimeInterval = 0.55

    let panel = ShelfPanel()
    let ui = ShelfUIState()
    private let store: ShelfStore
    private let dropHandler: DropHandler
    private let interactions: ShelfInteractions
    private let director: CharacterDirector
    private let container: ShelfContainerView
    private let geometry = DockGeometry(fullWidth: ShelfPanel.width, tuckedWidth: ShelfPanel.tuckedWidth, minHeight: 240)
    private var placement = DockPlacement.load()

    private enum Presence: Equatable {
        case tucked
        /// `pinned`: opened on purpose (menu bar, hotkey). It stays out until
        /// the cursor has been inside and left again.
        case revealed(pinned: Bool)
    }

    private var presence = Presence.tucked
    private var peekUntil = Date.distantPast
    private var lastInside = Date.distantPast
    private var leaveWatcher: Timer?
    private var refreshTimer: Timer?
    private var hoverTask: Task<Void, Never>?
    private var snapTask: Task<Void, Never>?
    private var keyMonitor: Any?
    /// > 0 while we're moving the window ourselves, so those moves aren't
    /// mistaken for the user dragging the shelf.
    private var programmaticMoves = 0
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
        container = ShelfContainerView(content: hostingView, contentWidth: ShelfPanel.width, dropHandler: dropHandler) { [ui] targeted in
            if ui.isDropTargeted != targeted { ui.isDropTargeted = targeted }
        }
        panel.contentView = container

        container.onDragMoved = { [director] point in director.cursorMoved(to: point) }
        container.onMouseEntered = { [weak self] in self?.hoverStarted() }
        container.onDragEntered = { [weak self] in self?.reveal(pinned: false) }
        interactions.onDragMoved = { [director] point in director.cursorMoved(to: point) }
        director.faceCenter = { [weak self] in self?.faceCenterOnScreen() }
        director.panelFrame = { [panel] in panel.frame }

        panel.quickLook = interactions.quickLook
        interactions.onDismiss = { [weak self] in self?.closeFromShelf() }
        installKeyMonitor()
        observeUserMoves()

        dropHandler.onItemsAdded = { [ui] _ in
            ui.gulpCount += 1
            sounds.play(.gulp)
        }
    }

    /// Puts the shelf on screen, tucked at its edge. Call once at launch.
    func dock() {
        ui.dockSide = placement.side
        container.dockSide = placement.side
        setFrame(frame(tucked: true))
        panel.orderFrontRegardless()
        director.start()
    }

    var isRevealed: Bool { presence != .tucked }

    // MARK: - Showing and tucking

    /// Slides the shelf out and keeps it out until you've used it.
    func show() {
        reveal(pinned: true)
    }

    func hide() {
        tuck()
    }

    func toggle() {
        isRevealed ? tuck() : reveal(pinned: true)
    }

    /// Slides the shelf out for a few seconds, e.g. when a screenshot arrives.
    /// If you hover it in the meantime, it stays until you leave.
    func peek(for duration: Duration = .seconds(4)) {
        peekUntil = Date.now.addingTimeInterval(Double(duration.components.seconds))
        if !isRevealed { reveal(pinned: false) }
    }

    private func reveal(pinned: Bool) {
        hoverTask?.cancel()
        if case .revealed(let wasPinned) = presence {
            presence = .revealed(pinned: wasPinned || pinned)
            return
        }
        presence = .revealed(pinned: pinned)
        lastInside = .now
        store.refreshAvailability()
        startRefreshing()
        startWatchingForLeave()
        withAnimation(.pouchCharacter) { ui.isTucked = false }
        slide(to: frame(tucked: false), duration: 0.3, timing: CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1))
    }

    private func tuck() {
        guard isRevealed else { return }
        presence = .tucked
        peekUntil = .distantPast
        stopWatchingForLeave()
        stopRefreshing()
        withAnimation(.pouchCharacter) { ui.isTucked = true }
        slide(to: frame(tucked: true), duration: 0.24, timing: CAMediaTimingFunction(name: .easeIn))
    }

    /// Esc: the pouch shuts its eyes, then tucks itself away.
    private func closeFromShelf() {
        director.closeEyes()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.14))
            self?.tuck()
            self?.director.clearReaction()
        }
    }

    // MARK: - Hover

    private func hoverStarted() {
        guard !isRevealed else { return }
        hoverTask?.cancel()
        hoverTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hoverIntent)
            guard !Task.isCancelled, let self else { return }
            // Still there? Then it's on purpose.
            if self.panel.frame.contains(NSEvent.mouseLocation) { self.reveal(pinned: false) }
        }
    }

    /// While the shelf is out, check every so often whether the cursor has
    /// left. (Polling is sturdier here than tracking areas, which don't fire
    /// reliably right after a drag or while a menu is up.)
    private func startWatchingForLeave() {
        guard leaveWatcher == nil else { return }
        leaveWatcher = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForLeave() }
        }
    }

    private func stopWatchingForLeave() {
        leaveWatcher?.invalidate()
        leaveWatcher = nil
    }

    private func checkForLeave() {
        guard case .revealed(let pinned) = presence else { return }
        let now = Date.now
        if panel.frame.insetBy(dx: -12, dy: -12).contains(NSEvent.mouseLocation) {
            lastInside = now
            // Once you've been in, leaving puts it away, even if it was pinned.
            if pinned { presence = .revealed(pinned: false) }
            return
        }
        let busy = pinned
            || now < peekUntil
            || ui.isDropTargeted
            || interactions.menuTracker.isOpen
            || interactions.quickLook.isVisible
            // A mouse button is down: dragging an item out, moving or resizing.
            || NSEvent.pressedMouseButtons != 0
        if !busy, now.timeIntervalSince(lastInside) > Self.leaveGrace {
            tuck()
        }
    }

    // MARK: - Frames

    private var screen: NSScreen? {
        NSScreen.screens.first { $0.displayID == placement.screenID } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func frame(tucked: Bool) -> NSRect {
        guard let screen else { return panel.frame }
        return geometry.frame(for: placement, in: screen.visibleFrame, tucked: tucked)
    }

    /// The point between the eyes, in screen coordinates, wherever the face
    /// currently is (it slides toward the edge while tucked).
    private func faceCenterOnScreen() -> NSPoint {
        let frame = panel.frame
        let pouchMinX = placement.side == .right
            ? frame.minX + ShelfPanel.margin
            : frame.maxX - ShelfPanel.margin - ShelfPanel.contentWidth
        let peek = ui.isTucked ? (placement.side == .right ? -FlapView.peekDistance : FlapView.peekDistance) : 0
        return NSPoint(x: pouchMinX + ShelfPanel.contentWidth / 2 + peek, y: frame.maxY - ShelfPanel.margin - 27)
    }

    private func setFrame(_ frame: NSRect) {
        programmaticMoves += 1
        panel.setFrame(frame, display: true)
        programmaticMoves -= 1
    }

    private func slide(to frame: NSRect, duration: TimeInterval, timing: CAMediaTimingFunction) {
        animationGeneration += 1
        let generation = animationGeneration
        programmaticMoves += 1
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : duration
            context.timingFunction = timing
            panel.animator().setFrame(frame, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.programmaticMoves -= 1
                guard generation == self.animationGeneration else { return }
                self.panel.invalidateShadow()
            }
        }
    }

    // MARK: - Moving the shelf

    private func observeUserMoves() {
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.userMovedOrResized() }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.setFrame(self.frame(tucked: !self.isRevealed))
            }
        }
    }

    private func userMovedOrResized() {
        guard programmaticMoves == 0 else { return }
        // Wait for the mouse button to come up, then snap to the nearer edge.
        snapTask?.cancel()
        snapTask = Task { [weak self] in
            while NSEvent.pressedMouseButtons != 0 {
                try? await Task.sleep(for: .milliseconds(60))
                if Task.isCancelled { return }
            }
            self?.snapToEdge()
        }
    }

    private func snapToEdge() {
        let frame = panel.frame
        let center = NSPoint(x: frame.midX, y: frame.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? self.screen else { return }
        placement = geometry.placement(afterMovingTo: frame, in: screen.visibleFrame, screenID: screen.displayID)
        placement.save()
        withAnimation(.pouchCharacter) { ui.dockSide = placement.side }
        container.dockSide = placement.side
        if !isRevealed {
            presence = .revealed(pinned: false)
            startWatchingForLeave()
        }
        lastInside = .now
        slide(to: self.frame(tucked: false), duration: 0.25, timing: CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1))
    }

    // MARK: - Misc

    /// Clear the shelf, from the menu bar or the footer.
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
}

private extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
