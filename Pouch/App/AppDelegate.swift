import AppKit
import PouchCore
import os

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.danielkurz.Pouch", category: "App")
    private let settings = AppSettings()
    private var store = ShelfStore()
    private var shelf: ShelfPanelController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let inbox = makeStorage()
        store.load()
        let sounds = SoundPlayer(settings: settings)

        let shelf = ShelfPanelController(store: store, settings: settings, inbox: inbox, sounds: sounds)
        self.shelf = shelf
        statusItemController = StatusItemController(shelf: shelf)
        shelf.show()
        #if DEBUG
        DebugSnapshot.scheduleIfRequested(for: shelf.panel)
        #endif
    }

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
