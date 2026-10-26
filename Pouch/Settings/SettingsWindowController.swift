import AppKit
import PouchCore
import SwiftUI

/// Hosts SettingsView in a plain window. SwiftUI's `Settings` scene is
/// awkward in a menu-bar-only (LSUIElement) app: opening it from AppKit code
/// isn't supported on macOS 14+, and it doesn't come to the front reliably.
@MainActor
final class SettingsWindowController {
    private let settings: AppSettings
    private(set) var window: NSWindow?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // A menu bar app isn't frontmost, so bring it forward or the window
        // would open behind whatever you're using.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
        window.title = "Pouch Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
