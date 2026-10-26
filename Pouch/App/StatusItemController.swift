import AppKit

/// Owns the menu bar icon and its menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let shelf: ShelfPanelController
    private let toggleItem = NSMenuItem(title: "Show Shelf", action: #selector(toggleShelf), keyEquivalent: "")
    private let icon = NSImage(systemSymbolName: "tray", accessibilityDescription: "Pouch")
    private let celebrationIcon = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Pouch")
    private var celebrationTask: Task<Void, Never>?

    init(shelf: ShelfPanelController) {
        self.shelf = shelf
        super.init()
        statusItem.button?.image = icon

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

    /// A quick "got it!" in the menu bar, e.g. when a screenshot is collected.
    func celebrate() {
        statusItem.button?.image = celebrationIcon
        celebrationTask?.cancel()
        celebrationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, let self else { return }
            self.statusItem.button?.image = self.icon
        }
    }

    @objc private func toggleShelf() {
        shelf.toggle()
    }
}
