import AppKit

/// Owns the menu bar icon and its menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let shelf: ShelfPanelController
    private let toggleItem = NSMenuItem(title: "Show Shelf", action: #selector(toggleShelf), keyEquivalent: "")

    init(shelf: ShelfPanelController) {
        self.shelf = shelf
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "Pouch")
        }

        let menu = NSMenu()
        menu.delegate = self
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pouch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    // Refresh titles right before the menu opens instead of tracking state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = shelf.isVisible ? "Hide Shelf" : "Show Shelf"
    }

    @objc private func toggleShelf() {
        shelf.toggle()
    }
}
