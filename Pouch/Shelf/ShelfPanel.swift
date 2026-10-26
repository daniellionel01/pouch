import AppKit
import QuickLookUI

/// The floating shelf window.
///
/// An `NSPanel` with `.nonactivatingPanel` can take clicks (and even become
/// key for Space/Delete) without activating Pouch, so whatever app you're
/// working in stays frontmost. That's what lets you drag something out of the
/// shelf straight into, say, Slack without a focus flicker.
final class ShelfPanel: NSPanel {
    /// Width of the visible pouch.
    static let contentWidth: CGFloat = 220
    /// Transparent breathing room around the pouch so its bounce animation
    /// isn't clipped by the window edge. Clicks on fully transparent pixels
    /// fall through to whatever is underneath.
    static let margin: CGFloat = 6
    static let width = contentWidth + margin * 2
    /// Window size while tucked against a screen edge: just the leather tab
    /// (plus the margin), to hover, click or drop onto.
    static let tuckedWidth: CGFloat = 32
    static let tuckedHeight: CGFloat = 76

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 380),
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        // Visible on every Space and on top of full-screen apps.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        // Panels hide when their app deactivates by default; Pouch is almost
        // never the active app, so that would make the shelf vanish.
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        // Borderless + clear lets the SwiftUI pouch shape define the outline;
        // the window server derives the shadow from the opaque pixels.
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
        minSize = NSSize(width: Self.tuckedWidth, height: Self.tuckedHeight)
        maxSize = NSSize(width: Self.width, height: 1200)
    }

    // Borderless windows refuse key status by default. We want it so the
    // shelf can handle Space (Quick Look) and Delete after you click it.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Quick Look
    // QLPreviewPanel walks the responder chain looking for an object that
    // accepts control; the key window is part of that chain. These methods
    // come from an Objective-C category on NSObject and aren't marked as
    // main-actor, but AppKit only calls them on the main thread. `panel` is
    // always the shared preview panel, so we use that rather than passing
    // the non-Sendable parameter across.

    var quickLook: QuickLookController?

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        MainActor.assumeIsolated { quickLook != nil }
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            let shared = QLPreviewPanel.shared()
            shared?.dataSource = quickLook
            shared?.delegate = quickLook
        }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            let shared = QLPreviewPanel.shared()
            shared?.dataSource = nil
            shared?.delegate = nil
        }
    }
}
