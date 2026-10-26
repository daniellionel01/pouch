import AppKit
import PouchCore
import SwiftUI
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.danielkurz.Pouch", category: "App")
    private let settings = AppSettings()
    private lazy var sounds = SoundPlayer(settings: settings)
    private var store = ShelfStore()
    private let screenshotWatcher = ScreenshotWatcher()
    private var shelf: ShelfPanelController?
    private var statusItemController: StatusItemController?
    private var hotkey: HotkeyController?
    private lazy var settingsWindow = SettingsWindowController(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let inbox = makeStorage()
        store.load()

        let shelf = ShelfPanelController(store: store, settings: settings, inbox: inbox, sounds: sounds)
        self.shelf = shelf
        let statusItemController = StatusItemController(shelf: shelf, store: store)
        statusItemController.onOpenSettings = { [weak self] in self?.settingsWindow.show() }
        self.statusItemController = statusItemController
        hotkey = HotkeyController { [weak shelf] in shelf?.toggle() }
        shelf.dock()

        screenshotWatcher.onScreenshot = { [weak self] url in self?.collectScreenshot(at: url) }
        updateScreenshotWatcher(enabled: settings.collectScreenshots)
        observeChanges({ [settings] in settings.collectScreenshots }) { [weak self] enabled in
            self?.updateScreenshotWatcher(enabled: enabled)
        }

        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["POUCH_APPEARANCE"] == "dark" { NSApp.appearance = NSAppearance(named: .darkAqua) }
        if environment["POUCH_APPEARANCE"] == "light" { NSApp.appearance = NSAppearance(named: .aqua) }
        if environment["POUCH_DEBUG_HOVER"] != nil { shelf.ui.isDropTargeted = true }
        if let reaction = environment["POUCH_DEBUG_REACT"] {
            // Fire a reaction one second in, to snapshot it mid-animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                switch reaction {
                case "gulp": shelf.ui.gulpCount += 1
                case "snap": shelf.ui.snapCount += 1
                case "shake": shelf.ui.shakeCount += 1
                default: break
                }
            }
        }
        if environment["POUCH_SNAPSHOT_WINDOW"] == "settings" {
            settingsWindow.show()
            if let window = settingsWindow.window { DebugSnapshot.scheduleIfRequested(for: window) }
        } else if environment["POUCH_SNAPSHOT"] != nil {
            // Slide it out so there's something to see, unless the tucked
            // strip is what's being checked.
            if environment["POUCH_DEBUG_TUCKED"] == nil { shelf.peek(for: .seconds(30)) }
            DebugSnapshot.scheduleIfRequested(for: shelf.panel)
        }
        #endif
    }

    // MARK: - Screenshots

    private func updateScreenshotWatcher(enabled: Bool) {
        enabled ? screenshotWatcher.start() : screenshotWatcher.stop()
    }

    private func collectScreenshot(at url: URL) {
        guard let shelf else { return }
        let added = withAnimation(.pouchLand) { store.addFiles([url], source: .screenshot) }
        shelf.ui.flash(added.map(\.id))
        shelf.ui.snapCount += 1
        sounds.play(.snap)
        statusItemController?.celebrate()
        if settings.showOnNewScreenshot { shelf.peek() }
    }

    // MARK: - Storage

    /// Sets up `~/Library/Application Support/Pouch`. If that fails the shelf
    /// still works, it just won't survive a relaunch.
    private func makeStorage() -> DropInbox? {
        do {
            var directory = try ShelfPersistence.applicationSupportDirectory()
            #if DEBUG
            // Development aid: point a Debug build at a scratch data folder.
            if let override = ProcessInfo.processInfo.environment["POUCH_DATA_DIR"] {
                directory = URL(fileURLWithPath: override, isDirectory: true)
            }
            #endif
            let inbox = DropInbox(directory: directory.appendingPathComponent("Drops", isDirectory: true))
            store = ShelfStore(
                persistence: ShelfPersistence(fileURL: directory.appendingPathComponent("shelf.json")),
                inbox: inbox
            )
            return inbox
        } catch {
            logger.error("No Application Support folder, the shelf won't be saved: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
