import AppKit
import PouchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private var shelf: ShelfPanelController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let shelf = ShelfPanelController(settings: settings)
        self.shelf = shelf
        statusItemController = StatusItemController(shelf: shelf)
        shelf.show()
        #if DEBUG
        DebugSnapshot.scheduleIfRequested(for: shelf.panel)
        #endif
    }
}
