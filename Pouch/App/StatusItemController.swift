import AppKit
import KeyboardShortcuts
import PouchCore

/// Owns the menu bar icon. Clicking it shows or hides the shelf; right-click
/// (or Control-click) opens the menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let shelf: ShelfPanelController
    private let store: ShelfStore
    private lazy var menu = makeMenu()
    private let toggleItem = NSMenuItem(title: "Show Shelf", action: #selector(toggleShelf), keyEquivalent: "")
    private let clearItem = NSMenuItem(title: "Clear Shelf", action: #selector(clearShelf), keyEquivalent: "")
    private let icon = MenuBarIcon.image(.awake)
    private let celebrationIcon = MenuBarIcon.image(.delighted)
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
            // Handle clicks ourselves instead of attaching the menu, so a
            // plain click can toggle the shelf.
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

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

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            // Attach the menu just long enough to open it under the icon.
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
        } else {
            shelf.toggle()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    // Refresh titles right before the menu opens instead of tracking state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        toggleItem.title = shelf.isRevealed ? "Tuck Away" : "Show Shelf"
        clearItem.isEnabled = !store.isEmpty
    }

    private func updateCount() {
        let count = store.items.count
        statusItem.button?.title = count > 0 ? " \(count)" : ""
        statusItem.button?.setAccessibilityLabel(count > 0 ? "Pouch, \(count) items" : "Pouch")
    }

    /// The little pouch squints happily for a moment, e.g. when a screenshot
    /// is collected.
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
        if !shelf.isRevealed { shelf.show() }
        shelf.clearAll()
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }
}
