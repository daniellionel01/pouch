import AppKit

/// An `NSMenuItem` that runs a closure, so menus can be built inline without
/// a target object and an `@objc` method per item.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, symbol: String? = nil, keyEquivalent: String = "", modifiers: NSEvent.ModifierFlags = [], handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: keyEquivalent)
        target = self
        keyEquivalentModifierMask = modifiers
        if let symbol { image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func run() {
        handler()
    }
}
