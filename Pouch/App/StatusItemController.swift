import AppKit
import KeyboardShortcuts
import PouchCore

/// Owns the menu bar icon and its menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let shelf: ShelfPanelController
    private let store: ShelfStore
    private let toggleItem = NSMenuItem(title: "Show Shelf", action: #selector(toggleShelf), keyEquivalent: "")
    private let clearItem = NSMenuItem(title: "Clear Shelf", action: #selector(clearShelf), keyEquivalent: "")
    private let icon = NSImage(systemSymbolName: "tray", accessibilityDescription: "Pouch")
    private let celebrationIcon = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Pouch")
    private var celebrationTask: Task<Void, Never>?

    /// Called for "Settings…".
    var onOpenSettings: (() -> Void)?

    init(shelf: ShelfPanelController, store: ShelfStore) {
        self.shelf = shelf
        self.store = store
        super.init()

        if let button = statusItem.button {
            button.image = icon
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        }
        statusItem.menu = makeMenu()

        // Show how many things are in the pouch, even while it's hidden.
        updateCount()
        observeChanges({ [store] in store.items.count }) { [weak self] _ in self?.updateCount() }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        toggleItem.target = self
        toggleItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        // Displays the (user-configurable) global hotkey next to the item.
        toggleItem.setShortcut(for: .toggleShelf)
        menu.addItem(toggleItem)

        clearItem.target = self
        clearItem.image = NSImage(systemSymbolName: "wind", accessibilityDescription: nil)
        menu.addItem(clearItem)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pouch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    // Refresh titles right before the menu opens instead of tracking state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = shelf.isVisible ? "Hide Shelf" : "Show Shelf"
        clearItem.isEnabled = !store.isEmpty
    }

    private func updateCount() {
        let count = store.items.count
        statusItem.button?.title = count > 0 ? " \(count)" : ""
        statusItem.button?.setAccessibilityLabel(count > 0 ? "Pouch, \(count) items" : "Pouch")
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

    @objc private func clearShelf() {
        // Show the shelf so the tumble animation is visible.
        if !shelf.isVisible { shelf.show() }
        shelf.clearAll()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }
}
